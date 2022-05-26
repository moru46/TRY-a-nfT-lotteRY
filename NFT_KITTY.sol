// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract kittyNft is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    address public owner;
    mapping (uint => uint) public rank;
    mapping (uint => string) public description;


    constructor() ERC721("kittyNft", "ITM") {

    }



    function mint(uint class) public returns (uint256)
    {
        uint256 newItemId = _tokenIds.current();
        //_setTokenURI(newItemId, tokenURI);
        _tokenIds.increment();
        rank[class] = newItemId;
        string memory prefix = "NFT class: ";
        return newItemId;
    }

    function getTokenOfClass(uint class) public view returns (uint){
        return rank[class];
    }

    function awardItem(address player, uint256 tokendId) public {
        _mint(player, tokendId);
    }
}
