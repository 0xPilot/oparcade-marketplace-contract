// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";

contract TokenRegistry is Initializable, OwnableUpgradeable {
  event CollectionAdded(address indexed by, address indexed collection);
  event CollectionRemoved(address indexed by, address indexed collection);
  event PayTokenAdded(address indexed by, address indexed token);
  event PayTokenRemoved(address indexed by, address indexed token);

  bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
  bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

  /// @notice NFTAddress -> Bool
  mapping(address => bool) public enabledCollection;

  /// @notice Token -> Bool
  mapping(address => bool) public enabledPayToken;

  function initialize() external initializer {
    __Ownable_init();
  }

  /**
   @notice Add NFT collection
   @dev Only owner
   @param _nftAddress NFT address
   */
  function addCollection(address _nftAddress) external onlyOwner {
    require(!enabledCollection[_nftAddress], "collection already added");
    require(
      IERC165Upgradeable(_nftAddress).supportsInterface(INTERFACE_ID_ERC721) ||
        IERC165Upgradeable(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155),
      "unexpected collection"
    );

    enabledCollection[_nftAddress] = true;

    emit CollectionAdded(msg.sender, _nftAddress);
  }

  /**
   @notice Remove NFT collection
   @dev Only owner
   @param _nftAddress NFT address
   */
  function removeCollection(address _nftAddress) external onlyOwner {
    require(enabledCollection[_nftAddress], "collection not exist");

    enabledCollection[_nftAddress] = false;

    emit CollectionRemoved(msg.sender, _nftAddress);
  }

  /**
   @notice Add payment token
   @dev Only owner
   @param _token ERC20 token address
   */
  function addPayToken(address _token) external onlyOwner {
    require(!enabledPayToken[_token], "token already added");
    require(_token != address(0), "zero token address");

    enabledPayToken[_token] = true;

    emit PayTokenAdded(msg.sender, _token);
  }

  /**
   @notice Remove payment token
   @dev Only owner
   @param _token ERC20 token address
   */
  function removePayToken(address _token) external onlyOwner {
    require(enabledPayToken[_token], "token not exist");

    enabledPayToken[_token] = false;

    emit PayTokenRemoved(msg.sender, _token);
  }
}
