// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

import "./interfaces/IAddressRegistry.sol";
import "./interfaces/ITokenRegistry.sol";

// TODO: Add Pausable
contract OPGamesAuction is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
  event AuctionCreated(address indexed nftAddress, uint256 indexed tokenId, address payToken);

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

  /// @notice Information about the sender that placed a bit on an auction
  struct HighestBid {
    address payable bidder;
    uint256 bid;
    uint256 lastBidTime;
  }

  /// @notice ERC721 Address -> Token ID -> Auction Parameters
  mapping(address => mapping(uint256 => Auction)) public auctions;

  /// @notice ERC721 Address -> Token ID -> highest bidder info (if a bid has been received)
  mapping(address => mapping(uint256 => HighestBid)) public highestBids;

  /// @notice Platform fee recipient
  address payable public feeRecipient;

  /// @notice Platform fee
  uint256 public platformFee;

  /// @notice AddressRegistry
  IAddressRegistry public addressRegistry;

  function initialize(
    address _addressRegistry,
    address payable _feeRecipient,
    uint256 _platformFee
  ) external initializer {
    __Ownable_init();
    __ReentrancyGuard_init();
    __Pausable_init();

    addressRegistry = IAddressRegistry(_addressRegistry);
    feeRecipient = _feeRecipient;
    platformFee = _platformFee;
  }

  function createAuction(
    address _nftAddress,
    uint256 _tokenId,
    address _payToken,
    uint256 _reservePrice,
    uint256 _startTimestamp,
    bool minBidReserve,
    uint256 _endTimestamp
  ) external whenNotPaused {
    // Ensure this contract is approved to move the token
    require(
      IERC721Upgradeable(_nftAddress).ownerOf(_tokenId) == msg.sender &&
        IERC721Upgradeable(_nftAddress).isApprovedForAll(msg.sender, address(this)),
      "not owner and or contract not approved"
    );

    require(
      _payToken == address(0) ||
        (addressRegistry.tokenRegistry() != address(0) &&
          ITokenRegistry(addressRegistry.tokenRegistry()).enabledPayToken(_payToken)),
      "invalid pay token"
    );

    _createAuction(_nftAddress, _tokenId, _payToken, _reservePrice, _startTimestamp, minBidReserve, _endTimestamp);
  }

  function _getNow() internal view virtual returns (uint256) {
    return block.timestamp;
  }

  function _createAuction(
    address _nftAddress,
    uint256 _tokenId,
    address _payToken,
    uint256 _reservePrice,
    uint256 _startTimestamp,
    bool minBidReserve,
    uint256 _endTimestamp
  ) private {
    // Ensure a token cannot be re-listed if previously successfully sold
    require(auctions[_nftAddress][_tokenId].endTime == 0, "auction already started");

    // Check end time not before start time and that end is in the future
    require(_endTimestamp >= _startTimestamp + 300, "end time must be greater than start (by 5 minutes)");

    require(_startTimestamp > _getNow(), "invalid start time");

    uint256 minimumBid = 0;

    if (minBidReserve) {
      minimumBid = _reservePrice;
    }

    // Setup the auction
    auctions[_nftAddress][_tokenId] = Auction({
      owner: msg.sender,
      payToken: _payToken,
      minBid: minimumBid,
      reservePrice: _reservePrice,
      startTime: _startTimestamp,
      endTime: _endTimestamp,
      resulted: false
    });

    emit AuctionCreated(_nftAddress, _tokenId, _payToken);
  }
}
