// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "src/OmniNFT.sol";

/**
@title OmniNFTMinter
@dev Contract that is responsible to mint OmniNFTs.
 */
contract OmniNFTMinter is Ownable, ReentrancyGuard {
    using MerkleProof for bytes32[];

    /// @notice Enum to store every possible state of the Sales
    enum SaleState { UNSTARTED, ONGOING, FINISHED }

    /**
    @dev Event to be emitted whenever a new Sale is added
    @param saleId ID of the Sale
    @param merkleRoot Merkle root of the Sale
    @param initialDate Initial date of the Sale
    @param nftTypeLimits Maximum number of NFTs per type that can be minted on this Sale
    */
    event LogSaleAdded(uint32 saleId, bytes32 merkleRoot, uint64 initialDate, uint32[] nftTypeLimits);

    /**
    @dev Event to be emitted whenever a new Sale is edited
    @param saleId ID of the Sale
    @param merkleRoot Merkle root of the Sale
    @param initialDate Initial date of the Sale
    @param nftTypeLimits Maximum number of NFTs per type that can be minted on this Sale
    */
    event LogSaleEdited(uint32 saleId, bytes32 merkleRoot, uint64 initialDate, uint32[] nftTypeLimits);

    /**
    @dev Event to be emitted whenever a new Sale is removed
    @param saleId ID of the Sale
    */
    event LogSaleRemoved(uint32 saleId);

    /// @notice Struct to manage the information regarding the NFT types 
    struct NftType {
        uint32 quantity;    // Amount of NFTs available to mint of this type
        uint32 price;       // Price of a NFT of this type
        uint32 nextNftId;   // ID for the next minted NFT of this type
    }

    /// @notice Struct to manage the information regarding the Sales
    struct Sale {
        bytes32 merkleRoot;         // Merkle root of the Sale (Management of whitelisted addresses)
        uint64 initialDate;         // Initial date of the Sale
        uint32[] nftTypeLimits;     // Array that stores the maximum number of NFTs per type that can be minted on this Sale
        uint32 prevId;              // ID of the previous Sale
        uint32 nextId;              // ID of the next Sale 
    }

    /// @notice Struct to manage a linked list of Sales
    struct SalesData {
        uint32 first;                   // ID of the first Sale                
        uint32 last;                    // ID of the last Sale
        uint32 size;                    // Size of the linked list
        mapping(uint32 => Sale) sales;  // Mapping with all the Sales
    }

    /// @notice ONFT instance
    OmniNFT internal _nft;

    /// @notice Array to store the nftTypes
    NftType[] internal _nftTypes;

    /// @notice Variable to store the ongoing saleId
    uint32 internal _ongoingSaleId = 1;

    /// @notice Mapping to store the NFTs minted per type and per user in every Sale
    // mapping(saleId -> mapping(to -> nftsMinted[]))
    mapping(uint32 => mapping(address => uint32[])) internal _mintedBySale;

    /// @notice Linked List to keep the Sales ordered by initialDate
    SalesData internal _salesData;

    // *** Modifiers ***

    modifier saleExists(uint32 saleId) {
        require(_salesData.sales[saleId].nftTypeLimits.length != 0, "The Sale does not exist."); 
        _;
    }

    modifier saleModifiable(uint32 saleId) {
        require(checkSaleStatus(saleId) == SaleState.UNSTARTED, "The Sale is ongoing or has already finished.");
        _;
    }

    /**
     * @dev The initial dates should be in order.
     */
    constructor(
        uint32[] memory nftTypeQuantities, 
        uint32[] memory nftTypePrices, 
        bytes32[] memory saleMerkleRoots, 
        uint64[] memory saleInitialDates, 
        uint32[][] memory saleNftTypeLimits,
        address lzEndpoint) 
    {
        // Check if the length of the parameters it's the same, depending if it's for the NfyTypes or the Sales
        uint32 numberOfNftTypes = uint32(nftTypeQuantities.length);
        require(numberOfNftTypes != 0, "");
        require(numberOfNftTypes == nftTypePrices.length, 
            "The NFT quantities and prices must have the same number of elements.");
        
        uint32 numberOfSales = uint32(saleMerkleRoots.length);
        require(numberOfSales != 0, "");
        require(numberOfSales == saleInitialDates.length && numberOfSales == saleNftTypeLimits.length, 
            "The Sales merkle roots, intial dates and NFT type limits must have the same number of elements.");

        // Initialize the NftTypes and the Sales
        initializeNftTypes(nftTypeQuantities, nftTypePrices);
        initializeSales(saleMerkleRoots, saleInitialDates, saleNftTypeLimits);

        _nft = new OmniNFT(lzEndpoint);
    }

    // *** Functions ***

    // *** Initialization ***

    /**
    @dev Initializes the _nftTypes with the given parameters.
    @param quantities Quantities of the NFT types.
    @param prices Prices of the NFT types.
     */
    function initializeNftTypes(uint32[] memory quantities, uint32[] memory prices) internal {
        uint32 idCounter = 1;
        for (uint32 i = 0; i < quantities.length; i++) {
            _nftTypes.push(
                NftType(
                    quantities[i],      
                    prices[i],         
                    idCounter   // nextNftId
                )
            );
            idCounter += quantities[i];
        }
    }

    /**
    @dev Initializes the sales with the given parameters.
    @param merkleRoots Durations of the sales.
    @param initialDates Initial dates of the sales.
    @param nftTypeLimits NFT Type limits of the sales.
     */
    function initializeSales(bytes32[] memory merkleRoots, uint64[] memory initialDates, uint32[][] memory nftTypeLimits) internal {
        uint32 numberOfSales = uint32(merkleRoots.length);
        _salesData.size = numberOfSales;
        _salesData.first = 1;
        _salesData.last = numberOfSales;
        
        // We are asumming that the initial dates are inserted in order
        for (uint32 i = 1; i <= numberOfSales; i++) {
            _salesData.sales[i] = 
                Sale(
                    merkleRoots[i-1],         
                    initialDates[i-1],        
                    nftTypeLimits[i-1],       
                    i == 1 ? 0 : i - 1,              // prevId: Edge case -> First element
                    i == numberOfSales ? 0 : i + 1   // nextId: Edge case -> Last element
                );
        }
    }

    // *** Sales Management ***

    /**
    @dev Adds a new Sale.
    @param saleId ID for the new Sale
    @param merkleRoot Merkle Root of the sale.
    @param initialDate Initial date of the sale.
    @param nftTypeLimits NFT Type limits of the sale.
     */
    function addSale(
        uint32 saleId, 
        bytes32 merkleRoot, 
        uint64 initialDate, 
        uint32[] calldata nftTypeLimits,
        uint32 _prevId,
        uint32 _nextId
    ) external onlyOwner {
        // Update the ongoing Sale if needed. Also needed in order to check if the initialDate parameter is valid.
        checkSales();

        // Check if the parameters are correct
        require(saleId != 0, "The Sale ID cannot be 0.");
        require(_salesData.sales[saleId].nftTypeLimits.length == 0, "The Sale ID cannot be the same as an existing Sale.");
        require(merkleRoot != bytes32(0), "The merkle root cannot be empty.");
        require(initialDate > block.timestamp, "The initial date cannot be in the past.");
        require(checkInitialDates(0, initialDate), "The initial date cannot be the same as an existing Sale.");
        require(nftTypeLimits.length == _nftTypes.length, "The NFT type limits number should be the same as the stored ones.");

        _insert(saleId, merkleRoot, initialDate, nftTypeLimits, _prevId, _nextId);

        emit LogSaleAdded(saleId, merkleRoot, initialDate, nftTypeLimits);
    }

    /**
    @dev Edits an existing Sale.
    @param saleId ID of the sale.
    @param merkleRoot Merkle root of the sale.
    @param initialDate Initial date of the sale.
    @param nftTypeLimits NFT Type limits of the sale.
     */
    function editSale(
        uint32 saleId, 
        bytes32 merkleRoot, 
        uint64 initialDate, 
        uint32[] calldata nftTypeLimits
    ) external onlyOwner saleExists(saleId) saleModifiable(saleId) {
        // Update the ongoing Sale if needed. Also needed in order to check if the initialDate parameter is valid.
        checkSales();

        // Check if the parameters are correct
        require(merkleRoot != bytes32(0), "The merkle root can not be empty.");
        require(initialDate > block.timestamp, "The initial date cannot be in the past.");
        require(checkInitialDates(saleId, initialDate), "The initial date cannot be the same as an existing Sale.");
        require(nftTypeLimits.length == _nftTypes.length, "The NFT type limits number should be the same as the stored ones.");

        _remove(saleId);
        _insert(saleId, merkleRoot, initialDate, nftTypeLimits, saleId, saleId);

        emit LogSaleEdited(saleId, merkleRoot, initialDate, nftTypeLimits);
    }

    /**
    @dev Removes an existing Sale.
    @param saleId ID of the Sale.
     */
    function removeSale(uint32 saleId) external onlyOwner saleExists(saleId) saleModifiable(saleId) {
        _remove(saleId);

        emit LogSaleRemoved(saleId);
    }

    function _insert(
        uint32 saleId,        
        bytes32 merkleRoot, 
        uint64 initialDate, 
        uint32[] calldata nftTypeLimits,
        uint32 _prevId,
        uint32 _nextId
    ) internal {

        uint32 prevId = _prevId;
        uint32 nextId = _nextId;

        if (!_validInsertPosition(initialDate, prevId, nextId)) {
            // Sender's hint was not a valid insert position
            // Use sender's hint to find a valid insert position
            (prevId, nextId) = _findInsertPosition(initialDate, prevId, nextId);
        }

        if (prevId == 0 && nextId == 0) {
            // Insert as first and last
            _salesData.first = saleId;
            _salesData.last = saleId;
        } else if (prevId == 0) {
            // Insert before `prevId` as the first
            _salesData.sales[saleId].nextId = _salesData.first;
            _salesData.sales[_salesData.first].prevId = saleId;
            _salesData.first = saleId;
        } else if (nextId == 0) {
            // Insert after `nextId` as the last
            _salesData.sales[saleId].prevId = _salesData.last;
            _salesData.sales[_salesData.last].nextId = saleId;
            _salesData.last = saleId;
        } else {
            // Insert at insert position between `prevId` and `nextId`
            _salesData.sales[saleId].nextId = nextId;
            _salesData.sales[saleId].prevId = prevId;
            _salesData.sales[prevId].nextId = saleId;
            _salesData.sales[nextId].prevId = saleId;
        }

        _salesData.size = _salesData.size + 1;
        
        _salesData.sales[saleId].merkleRoot = merkleRoot;
        _salesData.sales[saleId].initialDate = initialDate;
        _salesData.sales[saleId].nftTypeLimits = nftTypeLimits;
    }

    function _remove(uint32 saleId) internal {
        if (_salesData.size > 1) {
            // List contains more than a Sale
            if (saleId == _salesData.first) {
                // The removed Sale is the first
                // Set first to next Sale
                _salesData.first = _salesData.sales[saleId].nextId;
                // Set prev pointer of new first to 0
                _salesData.sales[_salesData.first].prevId = 0;
            } else if (saleId == _salesData.last) {
                // The removed Sale is the last
                // Set last to previous Sale
                _salesData.last = _salesData.sales[saleId].prevId;
                // Set next pointer of new last to 0
                _salesData.sales[_salesData.last].nextId = 0;
            } else {
                // The removed Sale is neither the first or the last
                // Set next pointer of previous Sale to the next Sale
                _salesData.sales[_salesData.sales[saleId].prevId].nextId = _salesData.sales[saleId].nextId;
                // Set prev pointer of next Sale to the previous Sale
                _salesData.sales[_salesData.sales[saleId].nextId].prevId = _salesData.sales[saleId].prevId;
            }
        } else {
            // List contains a single Sale
            // Set the first and last to 0
            _salesData.first = 0;
            _salesData.last = 0;
        }

        delete _salesData.sales[saleId];
        _salesData.size = _salesData.size - 1;
    }

    /** 
    @dev Descend the list (bigger initialDates to smaller initialDates) to find a valid insert position
    @param initialDate Sale's initial Date
    @param startId Id of Sale to start descending the list from
     */
    function _descendList(uint64 initialDate, uint32 startId) internal view returns (uint32, uint32) {
        // If 'startId' is the first, check if the insert position is before the first
        if (_salesData.first == startId && initialDate <= _salesData.sales[startId].initialDate) {
            return (0, startId);
        }

        uint32 prevId = startId;
        uint32 nextId = _salesData.sales[prevId].nextId;

        // Descend the list until we reach the end or until we find a valid insert position
        while (prevId != 0 && !_validInsertPosition(initialDate, prevId, nextId)) {
            prevId = _salesData.sales[prevId].nextId;
            nextId = _salesData.sales[prevId].nextId;
        }

        return (prevId, nextId);
    }

    /**
    @dev Ascend the list (smaller initialDates to bigger initialDates) to find a valid insert position
    @param initialDate Sale's initial Date
    @param startId Id of Sale to start ascending the list from
     */
    function _ascendList(uint64 initialDate, uint32 startId) internal view returns (uint32, uint32) {
        // If 'startId' is the last, check if the insert position is after the last
        if (_salesData.last == startId && initialDate >= _salesData.sales[startId].initialDate) {
            return (startId, 0);
        }

        uint32 nextId = startId;
        uint32 prevId = _salesData.sales[nextId].prevId;

        // Ascend the list until we reach the end or until we find a valid insertion point
        while (nextId !=  0 && !_validInsertPosition(initialDate, prevId, nextId)) {
            nextId = _salesData.sales[nextId].prevId;
            prevId = _salesData.sales[nextId].prevId;
        }

        return (prevId, nextId);
    }

    /**
    @dev Check if a pair of Sales is a valid insertion point for a new Sale with the given initialDate
    @param initialDate Sale's initial Date
    @param prevId Id of previous Sale for the insert position
    @param nextId Id of next node for the insert position
     */
    function _validInsertPosition(uint64 initialDate, uint32 prevId, uint32 nextId) internal view returns (bool) {
        if (prevId == 0 && nextId == 0) {
            // '(null, null)' is a valid insert position if the list is empty
            return _salesData.size == 0;
        } else if (prevId == 0) {
            // '(null, nextId)' is a valid insert position if 'nextId' is the first of the list
            return _salesData.first == nextId && initialDate <= _salesData.sales[nextId].initialDate;
        } else if (nextId == 0) {
            // '(prevId, null)' is a valid insert position if 'prevId' is the last of the list
            return _salesData.last == prevId && initialDate >= _salesData.sales[prevId].initialDate;
        } else {
            // '(prevId, nextId)' is a valid insert position if they are adjacent Sales and 'initialDate' falls between the two Sales' initialDates
            return _salesData.sales[prevId].nextId == nextId &&
                   _salesData.sales[prevId].initialDate <= initialDate &&
                   initialDate <= _salesData.sales[nextId].initialDate;
        }
    }

    /**
    @dev Find the insert position for a new Sale with the given initialDate
    @param initialDate Sale's initial Date
    @param _prevId Id of previous Sale for the insert position
    @param _nextId Id of next Sale for the insert position
     */
    function _findInsertPosition(uint64 initialDate, uint32 _prevId, uint32 _nextId) internal view returns (uint32, uint32) {
        uint32 prevId = _prevId;
        uint32 nextId = _nextId;

        if (prevId != 0) {
            if (!contains(prevId) || initialDate < _salesData.sales[prevId].initialDate) {
                // 'prevId' does not exist anymore or has a smaller initialDate than the given initialDate
                prevId = 0;
            }
        }

        if (nextId != 0) {
            if (!contains(nextId) || initialDate > _salesData.sales[nextId].initialDate) {
                // 'nextId' does not exist anymore or has a larger initialDate than the given initialDate
                nextId = 0;
            }
        }

        if (prevId == 0 && nextId == 0) {
            // No hint - descend list starting from first
            return _descendList(initialDate, _salesData.first);
        } else if (prevId == 0) {
            // No 'prevId' for hint - ascend list starting from 'nextId'
            return _ascendList(initialDate, nextId);
        } else if (nextId == 0) {
            // No 'nextId' for hint - descend list starting from 'prevId'
            return _descendList(initialDate, prevId);
        } else {
            // Descend list starting from 'prevId'
            return _descendList(initialDate, prevId);
        }
    }

    /**
    @dev Checks if the list contains a Sale
    @param saleId ID of the Sale
     */
    function contains(uint32 saleId) public view  returns (bool) {
        return _salesData.sales[saleId].nftTypeLimits.length != 0;
    }

    /**
    @dev Checks the sale status according to its initial date, duration and current timestamp and updates it if needed.
    @param saleId ID of the Sale
     */
    function checkSaleStatus(uint32 saleId) internal returns (SaleState) {        
        if (block.timestamp > _salesData.sales[saleId].initialDate && (saleId + 1 == _salesData.size || block.timestamp < _salesData.sales[saleId + 1].initialDate)) { // Sale Ongoing
            _ongoingSaleId = saleId;
            return SaleState.ONGOING;
        }
        else if (block.timestamp < _salesData.sales[saleId].initialDate) { // Sale Unstarted 
            return SaleState.UNSTARTED;
        }
        else { // Sale Finished 
            return SaleState.FINISHED;
        }
    }

    /**
    @dev Checks if the current Sale is still ongoing. If it's not, checks the status of the next and repits until we find one that hasn’t ended.
     */
    function checkSales() internal {
        if (checkSaleStatus(_ongoingSaleId) != SaleState.ONGOING) {
            for (uint32 i = _ongoingSaleId + 1; i < _salesData.size; i++) {
                if (checkSaleStatus(i) == SaleState.ONGOING) {
                    break;
                }
            }
        }
    }

    /**
    @dev Loops through all the unstarted Sales checking if there is anyone with the same initial Date as the parameter.
    If it's an edition, the validation should only fail if it's not the edited Sale.
    @param saleId Sale ID of the edited Sale (If this function is called from the addSale function will receive 0)
    @param initialDate Initial date on a added/edited Sale.
     */
    function checkInitialDates(uint32 saleId, uint64 initialDate) internal view returns (bool) {
        for (uint32 i = _ongoingSaleId; i <= _salesData.size; i++) {
            if (initialDate == _salesData.sales[i].initialDate && i != saleId) {
                return false;
            }
        }
        return true;
    }

    // *** Minting ***

    /**
     * @dev Mints a determined quantity of OmniNFTs of a type to an address.
     * @param to Address where the NFTs will be sent.
     * @param quantity Amount of NFTs to be minted.
     * @param nftType Type of the NFT.
     * @param merkleProof Merkle proof of the receiver.
     */
    function mint(address to, uint32 quantity, uint32 nftType, bytes32[] memory merkleProof)
        external
        payable nonReentrant
    {
        // We update, if needed, the ongoingSaleId
        checkSales();

        // Check if the sender is allowed to mint, if it's not a Public Sale
        if (_salesData.sales[_ongoingSaleId].merkleRoot != bytes32(0)) {
            // Merkle Tree Validation
            bytes32 leaf = keccak256(abi.encodePacked(to));
            bool isWhitelisted = merkleProof.verify(_salesData.sales[_ongoingSaleId].merkleRoot, leaf);
            require(isWhitelisted, "MINT: You are not allowed to mint during this Sale.");
        }

        // Check if the specified NFT type exists
        require(nftType < _nftTypes.length, "MINT: The NFT type specified does not exist.");

        // Check if there are NFTs of the specified type available
        require(_nftTypes[nftType].quantity >= quantity, "MINT: There are no more NFTs of this type available.");

        // Check if the sender has already reach the limit per address
        uint32 balanceOfReceiver = _mintedBySale[_ongoingSaleId][to].length == 0 ? 0 : _mintedBySale[_ongoingSaleId][to][nftType];
        require(
            balanceOfReceiver + quantity <= _salesData.sales[_ongoingSaleId].nftTypeLimits[nftType],
            "MINT: You have reach the maximum amount of minted NFTs of this type."
        );

        // Check if the sender has sent enough ETH to pay the NFT
        uint32 totalPrice = _nftTypes[nftType].price * quantity;
        require(msg.value >= totalPrice, "MINT: Not enough ETH.");

        // Update the balance mapping and mint the NFT
        if (_mintedBySale[_ongoingSaleId][to].length == 0) {
            _mintedBySale[_ongoingSaleId][to] = new uint32[](_nftTypes.length);
        }
        _mintedBySale[_ongoingSaleId][to][nftType] = balanceOfReceiver + quantity;
        
        _nftTypes[nftType].quantity = _nftTypes[nftType].quantity - quantity;
        for (uint256 i = 0; i < quantity; i++) {
            _nftTypes[nftType].nextNftId++;
            _nft.safeMint(to, _nftTypes[nftType].nextNftId);
        }

        // Refund excess of ETH
        if (msg.value > totalPrice) {
            (bool success,) = payable(msg.sender).call{value: msg.value - totalPrice}("");
            require(success, "Refund failed.");
        }
    }

    /**
     * @dev Witdraws the contract's balance to a specified address.
     * @param to Address that gets the funds.
     */
    function withdraw(address to) external onlyOwner {
        (bool success,) = payable(to).call{value: address(this).balance}("");
        require(success, "Withdraw failed.");
    }

}