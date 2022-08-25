// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "./ERC721Mintable.sol";
import "./interfaces/IERC721Mintable.sol";

contract ERC721Factory {
  event ERC721CollectionMinted(address indexed by, string name, string symbol, address to);

  constructor() {}

  /**
   * @notice Mint ERC721 collection
   * @param _name Collection name
   * @param _symbol Collection symbol
   * @param _baseTokenURI Colleciton base token URI
   * @param _to Collection receiver
   * @param _tokenCount NFT count to mint
   */
  function mintERC721Collection(
    string memory _name,
    string memory _symbol,
    string memory _baseTokenURI,
    address _to,
    uint256 _tokenCount
  ) external returns (address) {
    address collection = address(new ERC721Mintable(msg.sender, _name, _symbol, _baseTokenURI, _to, _tokenCount));

    emit ERC721CollectionMinted(msg.sender, _name, _symbol, _to);

    return collection;
  }
}
