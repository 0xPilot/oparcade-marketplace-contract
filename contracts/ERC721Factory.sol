// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./ERC721Mintable.sol";
import "./interfaces/IERC721Mintable.sol";

contract ERC721Factory {
  constructor() {}

  function createERC721(
    string memory _name,
    string memory _symbol,
    string memory _baseTokenURI,
    address _to,
    uint256 _tokenCount
  ) external returns (address) {
    address collection = address(new ERC721Mintable(msg.sender, _name, _symbol, _baseTokenURI, _to, _tokenCount));

    return collection;
  }
}
