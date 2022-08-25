// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract ERC721Mintable is ERC721Enumerable {
  /// @dev Collection creator
  address public creator;

  /// @dev Current Token Index
  uint256 public currentTokenId;

  /// @dev Base token URI
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

  /**
   * @dev Returns the base token URI
   */
  function _baseURI() internal view virtual override returns (string memory) {
    return baseTokenURI;
  }

  /**
   * @notice Mint ERC721 NFTs
   * @dev Only collection creator
   * @param _to NFT receiver
   * @param _tokenCount NFT count to mint
   */
  function mint(address _to, uint256 _tokenCount) external {
    require(msg.sender == creator, "only creator");

    _mintTokens(_to, _tokenCount);
  }

  /**
   * @dev Mint initial ERC721 NFTs
   * @dev Only called by the ERC721Factory contract when creating a new collection
   * @param _to Collection receiver
   * @param _tokenCount NFT count to mint
   */
  function _mintTokens(address _to, uint256 _tokenCount) private {
    for (uint256 i; i < _tokenCount; i++) {
      currentTokenId++;
      _mint(_to, currentTokenId);
    }
  }
}
