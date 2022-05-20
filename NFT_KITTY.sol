// contracts/GameItem.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract kittyNft is ERC721URIStorage {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;

    constructor() ERC721("kittyNft", "ITM") {}

    function mint(string memory tokenURI) public returns (uint256)
    {
        uint256 newItemId = _tokenIds.current();
        _setTokenURI(newItemId, tokenURI);
        _tokenIds.increment();
        return newItemId;
    }

    function awardItem(address player, uint256 tokendId) public {
        _mint(player, tokendId);
    }
}
