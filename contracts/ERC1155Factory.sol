// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./ERC1155Mintable.sol";
import "./interfaces/IERC1155Mintable.sol";

contract ERC1155Factory {
  event ERC1155CollectionMinted(address indexed by, string name, string symbol, address to);

  constructor() {}

  /**
   * @notice Mint ERC1155 collection
   * @param _name Collection name
   * @param _symbol Collection symbol
   * @param _to Collection receiver
   * @param _ids Token Id array to mint
   * @param _amounts Token amount array to mint
   * @param _data Data
   */
  function mintERC1155Collection(
    string memory _name,
    string memory _symbol,
    string memory _baseTokenURI,
    address _to,
    uint256[] memory _ids,
    uint256[] memory _amounts,
    bytes memory _data
  ) external returns (address) {
    address collection = address(
      new ERC1155Mintable(msg.sender, _name, _symbol, _baseTokenURI, _to, _ids, _amounts, _data)
    );

    emit ERC1155CollectionMinted(msg.sender, _name, _symbol, _to);

    return collection;
  }
}
