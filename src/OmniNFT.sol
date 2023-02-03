// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@layer-zero/token/onft/ONFT721.sol";

/**
@title OmniNFT
@dev Contract that implements a Layer-Zero Omnichain NFT.
 */
contract OmniNFT is Ownable, ONFT721 {

    constructor(address _lzEndpoint) ONFT721("OmniNFT", "ONFT", _lzEndpoint) {}

    function safeMint(address to, uint256 tokenId) external onlyOwner {
        // Mints the NFT
        _safeMint(to, tokenId);
    }

    function burn(uint256 tokenId) external {
	    require(msg.sender == ownerOf(tokenId), "Only the owner of the NFT can burn it.");
        
        // Burns the NFT
        _burn(tokenId);
    }
}