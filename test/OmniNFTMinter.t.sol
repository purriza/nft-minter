// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "src/OmniNFT.sol";
import "src/OmniNFTMinter.sol";

import "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

contract OmniNFTMinterStub is OmniNFTMinter {

    constructor(
        uint32[] memory nftTypeQuantities, 
        uint32[] memory nftTypePrices, 
        bytes32[] memory saleMerkleRoots, 
        uint64[] memory saleInitialDates, 
        uint32[][] memory saleNftTypeLimits,
        address lzEndpoint
    ) OmniNFTMinter(nftTypeQuantities, nftTypePrices, saleMerkleRoots, saleInitialDates, saleNftTypeLimits, lzEndpoint) {}

    function getNft() public view returns(OmniNFT) {
        return _nft;
    }

    function getNftTypes() public view returns(NftType[] memory) {
        return _nftTypes;
    }

    function getOngoingSaleId() public view returns(uint32) {
        return _ongoingSaleId;
    }

    function getMintedBySale(uint32 saleId, address to, uint32 nftType) internal view returns(uint32) {
        return _mintedBySale[saleId][to][nftType];
    }

    function getSalesDataFirst() public view returns(uint32) {
        return _salesData.first;
    }

    function getSalesDataLast() public view returns(uint32) {
        return _salesData.last;
    }

    function getSalesDataSize() public view returns(uint32) {
        return _salesData.size;
    }

    function getSalesDataSale(uint32 saleId) public view returns(Sale memory) {
        return _salesData.sales[saleId];
    }

    function setNftTypes(uint32[] memory quantities, uint32[] memory prices) public {
        initializeNftTypes(quantities, prices);
    }

    function setSales(bytes32[] memory merkleRoots, uint64[] memory initialDates, uint32[][] memory nftTypeLimits) public {
        initializeSales(merkleRoots, initialDates, nftTypeLimits);
    }
}

contract OmniNFTMinterTest is Test {

    OmniNFTMinterStub public minter;
    OmniNFT public onft;

    address public deployer = vm.addr(1500);

    address public user1 = vm.addr(1501);
    address public user2 = vm.addr(1502);
    address public user3 = vm.addr(1503);
    address public user4 = vm.addr(1504);
    address public user5 = vm.addr(1505);

    address public lzEndpoint;

    function setUp() public {
        // Label addresses
        vm.label(deployer, "Deployer");
        vm.label(user1, "User 1");
        vm.label(user2, "User 2");
        vm.label(user3, "User 3");
        vm.label(user4, "User 4");
        vm.label(user5, "User 5");

        // Deal addresses
        vm.deal(deployer, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
        vm.deal(user4, 100 ether);
        vm.deal(user5, 100 ether);

        // Set the initial Data
        // NftTypes parameters
        uint32[] memory nftTypeQuantities = new uint32[](3);
        nftTypeQuantities[0] = uint32(1000);
        nftTypeQuantities[1] = uint32(1000);
        nftTypeQuantities[2] = uint32(500);
        uint32[] memory nftTypePrices = new uint32[](3);
        nftTypePrices[0] = uint32(uint(0.01 ether));
        nftTypePrices[1] = uint32(uint(0.05 ether));
        nftTypePrices[2] = uint32(uint(0.25 ether));

        // Sales parameters
        bytes32[] memory saleMerkleRoots = new bytes32[](3);
        saleMerkleRoots[0] = 0x2b2c65b485461ad2aea87adf3abc0c2c7730f33674b7b5a206014fe04d52bc25;
        saleMerkleRoots[1] = 0x8f6d1754c5c36f66e51cb7a90c79ba713c9edea5bc33ead9a08c6c2ed10bafb1;
        saleMerkleRoots[2] = bytes32(0);
        uint64[] memory saleInitialDates = new uint64[](3);
        saleInitialDates[0] = uint64(block.timestamp);
        saleInitialDates[1] = uint64(block.timestamp + 2 days);
        saleInitialDates[2] = uint64(block.timestamp + 5 days);
        uint32[] memory saleNftTypeLimits1 = new uint32[](3);
        saleNftTypeLimits1[0] = uint32(200);
        saleNftTypeLimits1[1] = uint32(200);
        saleNftTypeLimits1[2] = uint32(0);
        uint32[] memory saleNftTypeLimits2 = new uint32[](3);
        saleNftTypeLimits2[0] = uint32(2);
        saleNftTypeLimits2[1] = uint32(2);
        saleNftTypeLimits2[2] = uint32(1);
        uint32[] memory saleNftTypeLimits3 = new uint32[](3);
        saleNftTypeLimits3[0] = uint32(1);
        saleNftTypeLimits3[1] = uint32(1);
        saleNftTypeLimits3[2] = uint32(1);
        uint32[][] memory saleNftTypeLimits = new uint32[][](3);
        saleNftTypeLimits[0] = saleNftTypeLimits1;
        saleNftTypeLimits[1] = saleNftTypeLimits2;
        saleNftTypeLimits[2] = saleNftTypeLimits3;

        vm.startPrank(deployer);

        // Deploy the OmniNFTMinter
        minter = new OmniNFTMinterStub(nftTypeQuantities, nftTypePrices, saleMerkleRoots, saleInitialDates, saleNftTypeLimits, lzEndpoint);

        // Initialize the onft
        onft = minter.getNft();

        // Sanity checks
        // NftTypes
        assertEq(minter.getNftTypes()[0].quantity, nftTypeQuantities[0]);
        assertEq(minter.getNftTypes()[0].price, nftTypePrices[0]);
        assertEq(minter.getNftTypes()[0].nextNftId, 1);
        assertEq(minter.getNftTypes()[1].quantity, nftTypeQuantities[1]);
        assertEq(minter.getNftTypes()[1].price, nftTypePrices[1]);
        assertEq(minter.getNftTypes()[1].nextNftId, 1001);
        assertEq(minter.getNftTypes()[2].quantity, nftTypeQuantities[2]);
        assertEq(minter.getNftTypes()[2].price, nftTypePrices[2]);
        assertEq(minter.getNftTypes()[2].nextNftId, 2001);

        // Sales
        assertEq(minter.getSalesDataFirst(), 1);
        assertEq(minter.getSalesDataLast(), 3);
        assertEq(minter.getSalesDataSize(), 3);
        assertEq(minter.getSalesDataSale(1).merkleRoot, saleMerkleRoots[0]);
        assertEq(minter.getSalesDataSale(1).initialDate, saleInitialDates[0]);
        assertEq(minter.getSalesDataSale(1).nftTypeLimits[0], saleNftTypeLimits[0][0]);
        assertEq(minter.getSalesDataSale(1).nftTypeLimits[1], saleNftTypeLimits[0][1]);
        assertEq(minter.getSalesDataSale(1).nftTypeLimits[2], saleNftTypeLimits[0][2]);
        assertEq(minter.getSalesDataSale(1).prevId, 0);
        assertEq(minter.getSalesDataSale(1).nextId, 2);
        assertEq(minter.getSalesDataSale(2).merkleRoot, saleMerkleRoots[1]);
        assertEq(minter.getSalesDataSale(2).initialDate, saleInitialDates[1]);
        assertEq(minter.getSalesDataSale(2).nftTypeLimits[0], saleNftTypeLimits[1][0]);
        assertEq(minter.getSalesDataSale(2).nftTypeLimits[1], saleNftTypeLimits[1][1]);
        assertEq(minter.getSalesDataSale(2).nftTypeLimits[2], saleNftTypeLimits[1][2]);
        assertEq(minter.getSalesDataSale(2).prevId, 1);
        assertEq(minter.getSalesDataSale(2).nextId, 3);
        assertEq(minter.getSalesDataSale(3).merkleRoot, saleMerkleRoots[2]);
        assertEq(minter.getSalesDataSale(3).initialDate, saleInitialDates[2]);
        assertEq(minter.getSalesDataSale(3).nftTypeLimits[0], saleNftTypeLimits[2][0]);
        assertEq(minter.getSalesDataSale(3).nftTypeLimits[1], saleNftTypeLimits[2][1]);
        assertEq(minter.getSalesDataSale(3).nftTypeLimits[2], saleNftTypeLimits[2][2]);
        assertEq(minter.getSalesDataSale(3).prevId, 2);
        assertEq(minter.getSalesDataSale(3).nextId, 0);

        vm.stopPrank();
    }

    function test_initializeNftTypes() public {
        vm.startPrank(deployer);

        uint32[] memory nftTypeQuantities = new uint32[](3);
        nftTypeQuantities[0] = uint32(1000);
        nftTypeQuantities[1] = uint32(1000);
        nftTypeQuantities[2] = uint32(500);
        uint32[] memory nftTypePrices = new uint32[](3);
        nftTypePrices[0] = uint32(uint(10000000000000000 wei));
        nftTypePrices[1] = uint32(uint(50000000000000000 wei));
        nftTypePrices[2] = uint32(uint(250000000000000000 wei));

        minter.setNftTypes(nftTypeQuantities, nftTypePrices);

        assertEq(minter.getNftTypes()[3].quantity, nftTypeQuantities[0]);
        assertEq(minter.getNftTypes()[3].price, nftTypePrices[0]);
        assertEq(minter.getNftTypes()[3].nextNftId, 1);
        assertEq(minter.getNftTypes()[4].quantity, nftTypeQuantities[1]);
        assertEq(minter.getNftTypes()[4].price, nftTypePrices[1]);
        assertEq(minter.getNftTypes()[4].nextNftId, 1001);
        assertEq(minter.getNftTypes()[5].quantity, nftTypeQuantities[2]);
        assertEq(minter.getNftTypes()[5].price, nftTypePrices[2]);
        assertEq(minter.getNftTypes()[5].nextNftId, 2001);

        vm.stopPrank();        
    }

    function test_initializeSales() public {
        vm.startPrank(deployer); 
        
        bytes32[] memory saleMerkleRoots = new bytes32[](3);
        saleMerkleRoots[0] = bytes32(abi.encodePacked(uint(1)));
        saleMerkleRoots[1] = bytes32(abi.encodePacked(uint(2)));
        saleMerkleRoots[2] = bytes32(abi.encodePacked(uint(3)));
        uint64[] memory saleInitialDates = new uint64[](3);
        saleInitialDates[0] = uint64(block.timestamp);
        saleInitialDates[1] = uint64(block.timestamp + 2 days);
        saleInitialDates[2] = uint64(block.timestamp + 5 days);
        uint32[] memory saleNftTypeLimits1 = new uint32[](3);
        saleNftTypeLimits1[0] = uint32(200);
        saleNftTypeLimits1[1] = uint32(200);
        saleNftTypeLimits1[2] = uint32(0);
        uint32[] memory saleNftTypeLimits2 = new uint32[](3);
        saleNftTypeLimits2[0] = uint32(2);
        saleNftTypeLimits2[1] = uint32(2);
        saleNftTypeLimits2[2] = uint32(1);
        uint32[] memory saleNftTypeLimits3 = new uint32[](3);
        saleNftTypeLimits3[0] = uint32(1);
        saleNftTypeLimits3[1] = uint32(1);
        saleNftTypeLimits3[2] = uint32(1);
        uint32[][] memory saleNftTypeLimits = new uint32[][](3);
        saleNftTypeLimits[0] = saleNftTypeLimits1;
        saleNftTypeLimits[1] = saleNftTypeLimits2;
        saleNftTypeLimits[2] = saleNftTypeLimits3;

        minter.setSales(saleMerkleRoots, saleInitialDates, saleNftTypeLimits);

        assertEq(minter.getSalesDataFirst(), 1);
        assertEq(minter.getSalesDataLast(), 6);
        assertEq(minter.getSalesDataSize(), 6);
        assertEq(minter.getSalesDataSale(4).merkleRoot, saleMerkleRoots[0]);
        assertEq(minter.getSalesDataSale(4).initialDate, saleInitialDates[0]);
        assertEq(minter.getSalesDataSale(4).nftTypeLimits[0], saleNftTypeLimits[0][0]);
        assertEq(minter.getSalesDataSale(4).nftTypeLimits[1], saleNftTypeLimits[0][1]);
        assertEq(minter.getSalesDataSale(4).nftTypeLimits[2], saleNftTypeLimits[0][2]);
        assertEq(minter.getSalesDataSale(4).prevId, 0);
        assertEq(minter.getSalesDataSale(4).nextId, 2);
        assertEq(minter.getSalesDataSale(5).merkleRoot, saleMerkleRoots[1]);
        assertEq(minter.getSalesDataSale(5).initialDate, saleInitialDates[1]);
        assertEq(minter.getSalesDataSale(5).nftTypeLimits[0], saleNftTypeLimits[1][0]);
        assertEq(minter.getSalesDataSale(5).nftTypeLimits[1], saleNftTypeLimits[1][1]);
        assertEq(minter.getSalesDataSale(5).nftTypeLimits[2], saleNftTypeLimits[1][2]);
        assertEq(minter.getSalesDataSale(5).prevId, 1);
        assertEq(minter.getSalesDataSale(5).nextId, 3);
        assertEq(minter.getSalesDataSale(6).merkleRoot, saleMerkleRoots[2]);
        assertEq(minter.getSalesDataSale(6).initialDate, saleInitialDates[2]);
        assertEq(minter.getSalesDataSale(6).nftTypeLimits[0], saleNftTypeLimits[2][0]);
        assertEq(minter.getSalesDataSale(6).nftTypeLimits[1], saleNftTypeLimits[2][1]);
        assertEq(minter.getSalesDataSale(6).nftTypeLimits[2], saleNftTypeLimits[2][2]);
        assertEq(minter.getSalesDataSale(6).prevId, 2);
        assertEq(minter.getSalesDataSale(6).nextId, 0);

        vm.stopPrank();        
    }

    function test_addSale() public {
        // Parameters set up
        bytes32 merkleRoot;
        uint64 initialDate = uint64(block.timestamp);
        uint32[] memory nftTypeLimitsRevert = new uint32[](2);
        uint32[] memory nftTypeLimits = new uint32[](3);
        uint32 _prevId = 3;
        uint32 _nextId = 0;

        // Unhappy path Nº1 - Trying to add a Sale without being the Owner
        vm.startPrank(user1);

        vm.expectRevert("Ownable: caller is not the owner");
        minter.addSale(4, merkleRoot, initialDate, nftTypeLimits, _prevId, _nextId);

        vm.stopPrank();

        vm.startPrank(deployer);
        // Unhappy path Nº2 - Parameter saleId cannot be 0
        vm.expectRevert("The Sale ID cannot be 0.");
        minter.addSale(0, merkleRoot, initialDate, nftTypeLimits, _prevId, _nextId);

        // Unhappy path Nº3 - Parameter saleId cannot already exist
        vm.expectRevert("The Sale ID cannot be the same as an existing Sale.");
        minter.addSale(1, merkleRoot, initialDate, nftTypeLimits, _prevId, _nextId);

        // Unhappy path Nº4 - Parameter merkleRoot cannot be empty
        vm.expectRevert("The merkle root cannot be empty.");
        minter.addSale(4, merkleRoot, initialDate, nftTypeLimits, _prevId, _nextId);
        merkleRoot = bytes32(abi.encodePacked(uint(1)));

        // Unhappy path Nº5 - Parameter initialDate cannot be in the past
        vm.expectRevert("The initial date cannot be in the past.");
        minter.addSale(4, merkleRoot, initialDate, nftTypeLimits, _prevId, _nextId);
        initialDate = uint64(block.timestamp + 2 days);

        // Unhappy path Nº6 - Parameter initialDate cannot be the same as an existing Sale
        vm.expectRevert("The initial date cannot be the same as an existing Sale.");
        minter.addSale(4, merkleRoot, initialDate, nftTypeLimits, _prevId, _nextId);
        initialDate = uint64(block.timestamp + 7 days);

        // Unhappy path Nº7 - Parameter nftTypeLimits should be more than 0 
        vm.expectRevert("The NFT type limits number should be the same as the stored ones.");
        minter.addSale(4, merkleRoot, initialDate, nftTypeLimitsRevert, _prevId, _nextId);
        nftTypeLimits[0] = uint32(1);
        nftTypeLimits[1] = uint32(2);
        nftTypeLimits[2] = uint32(1);

        // Happy path - Being the Owner and passing the correct parameters
        minter.addSale(4, merkleRoot, initialDate, nftTypeLimits, _prevId, _nextId);

        assertEq(minter.getSalesDataFirst(), 1);
        assertEq(minter.getSalesDataLast(), 4);
        assertEq(minter.getSalesDataSize(), 4);
        assertEq(minter.getSalesDataSale(4).merkleRoot, merkleRoot);
        assertEq(minter.getSalesDataSale(4).initialDate, initialDate);
        assertEq(minter.getSalesDataSale(4).nftTypeLimits[0], nftTypeLimits[0]);
        assertEq(minter.getSalesDataSale(4).nftTypeLimits[1], nftTypeLimits[1]);
        assertEq(minter.getSalesDataSale(4).nftTypeLimits[2], nftTypeLimits[2]);
        assertEq(minter.getSalesDataSale(4).prevId, 3);
        assertEq(minter.getSalesDataSale(4).nextId, 0);

        vm.stopPrank();
    }

    function test_editSale() public {
        // Parameters set up
        bytes32 merkleRoot;
        uint64 initialDate = uint64(block.timestamp);
        uint32[] memory nftTypeLimitsRevert = new uint32[](2);
        uint32[] memory nftTypeLimits = new uint32[](3);

        // Unhappy path Nº1 - Trying to edit a Sale without being the Owner
        vm.startPrank(user1);

        vm.expectRevert("Ownable: caller is not the owner");
        minter.editSale(1, merkleRoot, initialDate, nftTypeLimits);

        vm.stopPrank();

        vm.startPrank(deployer);
        // Unhappy path Nº2 - Sale does not exist
        vm.expectRevert("The Sale does not exist.");
        minter.editSale(6, merkleRoot, initialDate, nftTypeLimits);

        // Unhappy path Nº3 - Sale is not modifiable
        vm.expectRevert("The Sale is ongoing or has already finished.");
        minter.editSale(1, merkleRoot, initialDate, nftTypeLimits);

        // Unhappy path Nº4 - Parameter merkleRoot cannot be empty
        vm.expectRevert("The merkle root can not be empty.");
        minter.editSale(2, merkleRoot, initialDate, nftTypeLimits);
        merkleRoot = bytes32(abi.encodePacked(uint(1)));

        // Unhappy path Nº5 - Parameter initialDate cannot be in the past
        vm.expectRevert("The initial date cannot be in the past.");
        minter.editSale(2, merkleRoot, initialDate, nftTypeLimits);
        initialDate = uint64(block.timestamp + 5 days);

        // Unhappy path Nº6 - Parameter initialDate cannot be the same as an existing Sale unless it's the same Sale
        vm.expectRevert("The initial date cannot be the same as an existing Sale.");
        minter.editSale(2, merkleRoot, initialDate, nftTypeLimits);
        initialDate = uint64(block.timestamp + 3 days);

        // Unhappy path Nº7 - Parameter nftTypeLimits should be more than 0        
        vm.expectRevert("The NFT type limits number should be the same as the stored ones.");
        minter.editSale(2, merkleRoot, initialDate, nftTypeLimitsRevert);
        nftTypeLimits[0] = uint32(1);
        nftTypeLimits[1] = uint32(2);
        nftTypeLimits[2] = uint32(1);

        // Happy path - Being the Owner, Sale is editable and passing the correct parameters        
        minter.editSale(2, merkleRoot, initialDate, nftTypeLimits);

        assertEq(minter.getSalesDataFirst(), 1);
        assertEq(minter.getSalesDataLast(), 3);
        assertEq(minter.getSalesDataSize(), 3);
        assertEq(minter.getSalesDataSale(2).merkleRoot, merkleRoot);
        assertEq(minter.getSalesDataSale(2).initialDate, initialDate);
        assertEq(minter.getSalesDataSale(2).nftTypeLimits[0], nftTypeLimits[0]);
        assertEq(minter.getSalesDataSale(2).nftTypeLimits[1], nftTypeLimits[1]);
        assertEq(minter.getSalesDataSale(2).nftTypeLimits[2], nftTypeLimits[2]);
        assertEq(minter.getSalesDataSale(2).prevId, 1);
        assertEq(minter.getSalesDataSale(2).nextId, 3);

        // Case 1 - Update the initialDate causing a change in the Sales order
        initialDate = uint64(block.timestamp + 10 days); 

        minter.editSale(2, merkleRoot, initialDate, nftTypeLimits);

        assertEq(minter.getSalesDataFirst(), 1);
        assertEq(minter.getSalesDataLast(), 2);
        assertEq(minter.getSalesDataSize(), 3);
        assertEq(minter.getSalesDataSale(2).merkleRoot, merkleRoot);
        assertEq(minter.getSalesDataSale(2).initialDate, initialDate);
        assertEq(minter.getSalesDataSale(2).nftTypeLimits[0], nftTypeLimits[0]);
        assertEq(minter.getSalesDataSale(2).nftTypeLimits[1], nftTypeLimits[1]);
        assertEq(minter.getSalesDataSale(2).nftTypeLimits[2], nftTypeLimits[2]);
        assertEq(minter.getSalesDataSale(2).prevId, 3);
        assertEq(minter.getSalesDataSale(2).nextId, 0);

        vm.stopPrank();
    }

    function test_removeSale() public {
        // Unhappy path Nº1 - Trying to remove a Sale without being the Owner
        vm.startPrank(user1);

        vm.expectRevert("Ownable: caller is not the owner");
        minter.removeSale(3);

        vm.stopPrank();

        vm.startPrank(deployer);
        // Unhappy path Nº2 - Sale does not exist
        vm.expectRevert("The Sale does not exist.");
        minter.removeSale(6);

        // Unhappy path Nº3 - Sale is not modifiable
        vm.expectRevert("The Sale is ongoing or has already finished.");
        minter.removeSale(1);

        // Happy path - Being the Owner and the Sale is removable
        minter.removeSale(3);

        assertEq(minter.getSalesDataFirst(), 1);
        assertEq(minter.getSalesDataLast(), 2);
        assertEq(minter.getSalesDataSize(), 2);
        assertEq(minter.getSalesDataSale(3).merkleRoot, bytes32(0));
        assertEq(minter.getSalesDataSale(3).initialDate, 0);
        assertEq(minter.getSalesDataSale(3).nftTypeLimits.length, 0);
        assertEq(minter.getSalesDataSale(2).prevId, 1);
        assertEq(minter.getSalesDataSale(2).nextId, 0);

        vm.stopPrank();
    }

    function test_mint() public {
        // Parameters set up
        address to = user5;
        uint32 quantity = 3000;
        uint32 nftType = 5;
        bytes32[] memory merkleProof = new bytes32[](1);
        merkleProof[0] = 0x733eeebb3b6515ff5df1782e9e500450863352249a3665f0b616c6650578049a;

        vm.startPrank(user1);

        console.log(user2);
        console.logBytes(abi.encodePacked(user2));
        console.logBytes32(keccak256(abi.encodePacked(user2)));

        console.log(user1);
        console.logBytes(abi.encodePacked(user1));
        console.logBytes32(keccak256(abi.encodePacked(user1)));

        // Unhappy path Nº1 - Sale is not Public and the receiver is not whitelisted
        vm.expectRevert("MINT: You are not allowed to mint during this Sale.");
        minter.mint(to, quantity, nftType, merkleProof);
        to = user2;

        // Unhappy path Nº2 - The NftType specified does not exist
        vm.expectRevert("MINT: The NFT type specified does not exist.");
        minter.mint(to, quantity, nftType, merkleProof);
        nftType = 1;

        // Unhappy path Nº3 - There are no more NFTs of this type available.
        vm.expectRevert("MINT: There are no more NFTs of this type available.");
        minter.mint(to, quantity, nftType, merkleProof);
        quantity = 300;

        // Unhappy path Nº4 - The receiver has reached the maximum amount of minted NFTs of the specified type in this Sale
        vm.expectRevert("MINT: You have reach the maximum amount of minted NFTs of this type.");
        minter.mint(to, quantity, nftType, merkleProof);
        quantity = 1;

        // Unhappy path Nº5 - Not enough ETH to pay the NFT
        vm.expectRevert("MINT: Not enough ETH.");
        minter.mint(to, quantity, nftType, merkleProof);

        // Happy path
        minter.mint{value: 0.5 ether}(to, quantity, nftType, merkleProof);

        assertEq(onft.balanceOf(user2), 1);
        assertEq(onft.balanceOf(user1), 0);
        assertLt(address(user1).balance, 100 ether);
        console.log(address(minter).balance);
        assertGt(address(minter).balance, 0);

        vm.stopPrank();
    }

    function test_mint_bigWhitelist() public {
        // Parameters set up
        address to = user2;
        uint32 quantity = 2;
        uint32 nftType = 1;
        bytes32[] memory merkleProof = new bytes32[](2);
        merkleProof[0] = 0x733eeebb3b6515ff5df1782e9e500450863352249a3665f0b616c6650578049a;
        merkleProof[1] = 0xf9800753e7999025e32cfea9e064788479fd4a157589bf49c572a4d0433bdbf9;

        vm.startPrank(user1);

        // Pass time to end the first Sale
        vm.warp(3 days);

        minter.mint{value: 0.5 ether}(to, quantity, nftType, merkleProof);

        assertEq(onft.balanceOf(user2), 2);
        assertEq(onft.balanceOf(user1), 0);
        assertLt(address(user1).balance, 100 ether);
        console.log(address(minter).balance);
        assertGt(address(minter).balance, 0);

        vm.stopPrank();
    }

    // *** OmniNFT ***

    function test_safeMint() public {
        // Unhappy path Nº1 - Trying to mint the NFT without being the Owner of the NFT contract
        vm.startPrank(user1);

        vm.expectRevert("Ownable: caller is not the owner");
        onft.safeMint(user1, 1);

        vm.stopPrank();

        // Happy path - Being the Owner
        vm.startPrank(address(minter));

        onft.safeMint(deployer, 1);
        assertEq(onft.balanceOf(deployer), 1);

        vm.stopPrank();
    }

    function test_burn() public {
        // Set the initial state
        vm.startPrank(address(minter));

        onft.safeMint(deployer, 1);

        vm.stopPrank();

        // Unhappy path Nº1 - Trying to burn a NFT without being the Owner of it
        vm.startPrank(user1);

        vm.expectRevert("Only the owner of the NFT can burn it.");
        onft.burn(1);

        vm.stopPrank();

        // Happy path - Being the Owner of the NFT
        vm.startPrank(deployer);

        onft.burn(1);
        assertEq(onft.balanceOf(deployer), 0);

        vm.stopPrank();
    }

}