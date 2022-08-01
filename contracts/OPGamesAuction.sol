// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IAddressRegistry.sol";

// TODO: Add Pausable
contract OPGamesAuction is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
  /// @notice Parameters of an auction
  struct Auction {
    address owner;
    address payToken;
    uint256 minBid;
    uint256 reservePrice;
    uint256 startTime;
    uint256 endTime;
    bool resulted;
  }

  /// @notice ERC721 Address -> Token ID -> Auction Parameters
  mapping(address => mapping(uint256 => Auction)) public auctions;

  /// @notice AddressRegistry
  IAddressRegistry public addressRegistry;

  function initialize(address _addressRegistry) external initializer {
    __Ownable_init();
    __ReentrancyGuard_init();

    addressRegistry = IAddressRegistry(_addressRegistry);
  }
}
