// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./ERC1155Mintable.sol";
import "./interfaces/IERC1155Mintable.sol";

contract ERC1155Factory {
  constructor() {}

  function createERC1155(
    string memory _name,
    string memory _symbol,
    string memory _baseTokenURI,
    address _to,
    uint256[] memory _amounts,
    bytes memory _data
  ) external returns (address) {
    address collection = address(new ERC1155Mintable(msg.sender, _name, _symbol, _baseTokenURI, _to, _amounts, _data));

    return collection;
  }
}
