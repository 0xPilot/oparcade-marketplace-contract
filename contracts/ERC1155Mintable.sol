// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract ERC1155Mintable is ERC1155Supply {
  /// @dev Collection name
  string public name;

  /// @dev Collection synbol
  string public symbol;

  /// @dev Collection creator
  address public creator;

  constructor(
    address _creator,
    string memory _name,
    string memory _symbol,
    string memory _uri,
    address _to,
    uint256[] memory _ids,
    uint256[] memory _amounts,
    bytes memory _data
  ) ERC1155(_uri) {
    name = _name;
    symbol = _symbol;
    creator = _creator;

    _mintBatch(_to, _ids, _amounts, _data);
  }

  /**
   * @notice Mint ERC1155 NFTs
   * @dev Only collection creator
   * @param _to NFT receiver
   * @param _ids Token Id array to mint
   * @param _amounts Token amount array to mint
   * @param _data Data
   */
  function mint(
    address _to,
    uint256[] memory _ids,
    uint256[] memory _amounts,
    bytes memory _data
  ) external {
    require(msg.sender == creator, "only creator");

    _mintBatch(_to, _ids, _amounts, _data);
  }
}
