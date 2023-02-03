THE PROJECT 

This solution implements a NFT Minter using the Foundry Framework.


## The NFT

The NFTs will implement an ERC-721 that implements the [Layer Zero Omnichain](https://medium.com/layerzero-official/layerzero-an-omnichain-interoperability-protocol-b43d2ae975b6) functionality. 
This functionality allows the token to be transferred from and to other chains, as long as the smart contracts are deployed in both chains (We can do this for **n** chains). 

## The NFT Minter

The NFT Minter is responsible to mint NFTs from the previously mentioned collection, since it is the only actor that can mint NFTs and all the Sales logic is implemented here. 

### NFT Types

NFTs can have different types (or have just 1 type). For each type there will be an associated ETH price that has to be sent to the contract when minting an asset. 
These types are suppose to be ordered by IDs. Below is an example showcasing the different types. There shouldn’t be any gaps between NFTs.

			Quantity	Price		IDs
Type I		1000		0.01 ETH	1-1000
Type II		1000		0.05 ETH	1001-2000
Type III	500			0.25 ETH	2001-2500

### Sales

The minting of the NFTs will be done throughout several different Sale. Sales can be added/edited/removed by the Owner of the NFT Minter. 
Whenever a Sale ends, another Sale starts right after. If all NFTs are not minted during a Sale, they should be available to be minted in the next available public Sale. 
If there isn’t a public Sale after that, they will be lost, since it won’t be possibly to mint them. 

A Sale has the following attributes

- Duration of the Sale. The last Sale can end only when all NFTs have been minted instead.
- Type of Sale
    - Team Mint (Specific address gets all NFTs from this Sale)
    - Whitelist Mint (Only whitelisted addresses can mint NFTs during this Sale).
    - Public Mint (Anyone can mint NFTs during this Sale)
- Limit of NFTs that each address can mint per NFT type. Here is an example

			Sale I (Team Mint)	Sale II (Whitelist)	Sale III (Public Sale)
Type I		200					2					1
Type II		200					2					1
Type III	0					1					1
Type IV		0					1					1

Since it is usual that a Whitelist Sale has +1000 whitelisted addresses, which is not a reasonable amount of addresses to store on-chain. 
The solution for this issue will be the usage of an off-chain Merkle Tree that has the whitelisted addresses as leafs. 
This way it is possible to only store the Merkle Root on-chain and then check if a given address is whitelisted utilizing a Merkle Proof. 
Using OpenZeppelin Merkle Proof library to perform the cryptographic verifications of the Merkle Proof on-chain and coding the off-chain Merkle Tree generator along with the Merkle Proof generator for a given address of that Merkle Tree.