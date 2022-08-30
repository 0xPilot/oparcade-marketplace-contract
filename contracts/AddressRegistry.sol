// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract AddressRegistry is Initializable, OwnableUpgradeable {
  event TokenRegistryUpdated(address indexed by, address indexed oldTokenRegistry, address indexed newTokenRegistry);
  event MarketplaceUpdated(address indexed by, address indexed oldMarketplace, address indexed newMarketplace);
  event AuctionUpdated(address indexed by, address indexed oldAuction, address indexed newAuction);

  /// @notice TokenRegistry contract
  address public tokenRegistry;

  /// @notice Marketplace contract
  address public marketplace;

  /// @notice Auction contract
  address public auction;

  function initialize() external initializer {
    __Ownable_init();
  }

  /**
   @notice Update TokenRegistry contract
   @dev Only owner
   @param _tokenRegistry new TokenRegistry contract address
   */
  function updateTokenRegistry(address _tokenRegistry) external onlyOwner {
    require(_tokenRegistry != address(0), "!TokenRegistry");

    emit TokenRegistryUpdated(msg.sender, tokenRegistry, _tokenRegistry);

    tokenRegistry = _tokenRegistry;
  }

  /**
   @notice Update Marketplace contract
   @dev Only owner
   @param _marketplace new Marketplace contract address
   */
  function updateMarketplace(address _marketplace) external onlyOwner {
    require(_marketplace != address(0), "!Marketplace");

    emit MarketplaceUpdated(msg.sender, marketplace, _marketplace);

    marketplace = _marketplace;
  }

  /**
   @notice Update Auction contract
   @dev Only owner
   @param _auction new Auction contract address
   */
  function updateAuction(address _auction) external onlyOwner {
    require(_auction != address(0), "!Auction");

    emit AuctionUpdated(msg.sender, auction, _auction);

    auction = _auction;
  }
}
