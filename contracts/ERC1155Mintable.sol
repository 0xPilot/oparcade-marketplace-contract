// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract ERC1155Mintable is ERC1155Supply {
  string public name;
  string public symbol;
  address public creator;
  uint256 public currentTokenId;
  string private baseTokenURI;

  constructor(
    address _creator,
    string memory _name,
    string memory _symbol,
    string memory _uri,
    address _to,
    uint256[] memory _amounts,
    bytes memory _data
  ) ERC1155(_uri) {
    name = _name;
    symbol = _symbol;
    creator = _creator;

    _mintBatchTokens(_to, _amounts, _data);
  }

  function mint(
    address _to,
    uint256 _amount,
    bytes memory _data
  ) public virtual {
    require(msg.sender == creator, "only creator");
    _mintSingleToken(_to, _amount, _data);
  }

  function mintBatch(
    address _to,
    uint256[] memory _amounts,
    bytes memory _data
  ) public virtual {
    require(msg.sender == creator, "only creator");
    _mintBatchTokens(_to, _amounts, _data);
  }

  function _mintSingleToken(
    address _to,
    uint256 _amount,
    bytes memory _data
  ) private {
    currentTokenId++;
    _mint(_to, currentTokenId, _amount, _data);
  }

  function _mintBatchTokens(
    address _to,
    uint256[] memory _amounts,
    bytes memory _data
  ) private {
    uint256 tokenCount = _amounts.length;
    uint256[] memory ids = new uint256[](tokenCount);
    for (uint256 i; i < tokenCount; i++) {
      currentTokenId++;
      ids[i] = currentTokenId;
    }

    _mintBatch(_to, ids, _amounts, _data);
  }
}
