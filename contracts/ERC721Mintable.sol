// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract ERC721Mintable is ERC721Enumerable {
  address public creator;
  uint256 public currentTokenId;
  string private baseTokenURI;

  constructor(
    address _creator,
    string memory _name,
    string memory _symbol,
    string memory _baseTokenURI,
    address _to,
    uint256 _tokenCount
  ) ERC721(_name, _symbol) {
    creator = _creator;
    baseTokenURI = _baseTokenURI;

    _mintTokens(_to, _tokenCount);
  }

  function _baseURI() internal view virtual override returns (string memory) {
    return baseTokenURI;
  }

  function mint(address _to, uint256 _tokenCount) public virtual {
    require(msg.sender == creator, "only creator");

    _mintTokens(_to, _tokenCount);
  }

  function _mintTokens(address _to, uint256 _tokenCount) private {
    for (uint256 i; i < _tokenCount; i++) {
      currentTokenId++;
      _mint(_to, currentTokenId);
    }
  }
}
