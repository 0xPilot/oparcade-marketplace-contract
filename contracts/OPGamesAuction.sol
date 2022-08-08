// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interfaces/IAddressRegistry.sol";
import "./interfaces/ITokenRegistry.sol";

// TODO: Add Pausable
contract OPGamesAuction is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  event AuctionCreated(address indexed nftAddress, uint256 indexed tokenId, address payToken);
  event BidPlaced(address indexed nftAddress, uint256 indexed tokenId, address indexed bidder, uint256 bid);
  event BidWithdrawn(address indexed nftAddress, uint256 indexed tokenId, address indexed bidder, uint256 bid);
  event BidRefunded(address indexed nftAddress, uint256 indexed tokenId, address indexed bidder, uint256 bid);
  event AuctionResulted(
    address oldOwner,
    address indexed nftAddress,
    uint256 indexed tokenId,
    address indexed winner,
    address payToken,
    uint256 winningBid
  );
  event AuctionCancelled(address indexed nftAddress, uint256 indexed tokenId);

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
    address bidder;
    uint256 bid;
    uint256 lastBidTime;
  }

  /// @notice ERC721 Address -> Token ID -> Auction Parameters
  mapping(address => mapping(uint256 => Auction)) public auctions;

  /// @notice ERC721 Address -> Token ID -> highest bidder info (if a bid has been received)
  mapping(address => mapping(uint256 => HighestBid)) public highestBids;

  /// @notice globally and across all auctions, the amount by which a bid has to increase
  uint256 public minBidIncrement = 1;

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

    require(_addressRegistry != address(0), "unexpected address registry");
    require(_feeRecipient != address(0), "unexpected fee recipient");
    require(_platformFee < 100_0, "platform fee exceeded");

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

  function placeBid(
    address _nftAddress,
    uint256 _tokenId,
    uint256 _bidAmount
  ) external payable nonReentrant whenNotPaused {
    require(msg.sender == tx.origin, "no contracts permitted");

    // Check the auction to see if this is a valid bid
    Auction memory auction = auctions[_nftAddress][_tokenId];

    // Ensure auction is in flight
    require(_getNow() >= auction.startTime && _getNow() <= auction.endTime, "bidding outside of the auction window");
    // require(auction.payToken != address(0), "ERC20 method used for auction");

    _placeBid(_nftAddress, _tokenId, _bidAmount);
  }

  function _placeBid(
    address _nftAddress,
    uint256 _tokenId,
    uint256 _bidAmount
  ) internal whenNotPaused {
    Auction storage auction = auctions[_nftAddress][_tokenId];

    if (auction.minBid == auction.reservePrice) {
      require(_bidAmount >= auction.reservePrice, "bid cannot be lower than reserve price");
    }

    // Ensure bid adheres to outbid increment and threshold
    HighestBid storage highestBid = highestBids[_nftAddress][_tokenId];
    uint256 minBidRequired = highestBid.bid + minBidIncrement;

    // if (auction.payToken != address(0)) {
    require(_bidAmount >= minBidRequired, "failed to outbid highest bidder");

    IERC20Upgradeable payToken = IERC20Upgradeable(auction.payToken);
    payToken.safeTransferFrom(msg.sender, address(this), _bidAmount);
    // }
    //  else {
    //   require(msg.value >= minBidRequired, "failed to outbid highest bidder");
    // }

    // Refund existing top bidder if found
    if (highestBid.bidder != address(0)) {
      _refundHighestBidder(_nftAddress, _tokenId, highestBid.bidder, highestBid.bid);
    }

    // assign top bidder and bid time
    highestBid.bidder = msg.sender;
    highestBid.bid = _bidAmount;
    highestBid.lastBidTime = _getNow();

    emit BidPlaced(_nftAddress, _tokenId, msg.sender, _bidAmount);
  }

  function withdrawBid(address _nftAddress, uint256 _tokenId) external nonReentrant whenNotPaused {
    HighestBid storage highestBid = highestBids[_nftAddress][_tokenId];

    // Ensure highest bidder is the caller
    require(highestBid.bidder == msg.sender, "you are not the highest bidder");

    uint256 _endTime = auctions[_nftAddress][_tokenId].endTime;

    require(
      _getNow() > _endTime && (_getNow() - _endTime >= 43200),
      "can withdraw only after 12 hours (after auction ended)"
    );

    uint256 previousBid = highestBid.bid;

    // Clean up the existing top bid
    delete highestBids[_nftAddress][_tokenId];

    // Refund the top bidder
    _refundHighestBidder(_nftAddress, _tokenId, msg.sender, previousBid);

    emit BidWithdrawn(_nftAddress, _tokenId, msg.sender, previousBid);
  }

  function resultAuction(address _nftAddress, uint256 _tokenId) external nonReentrant {
    // Check the auction to see if it can be resulted
    Auction storage auction = auctions[_nftAddress][_tokenId];

    require(
      IERC721Upgradeable(_nftAddress).ownerOf(_tokenId) == msg.sender && msg.sender == auction.owner,
      "sender must be item owner"
    );

    // Check the auction real
    require(auction.endTime > 0, "no auction exists");

    // Check the auction has ended
    require(_getNow() > auction.endTime, "auction not ended");

    // Ensure auction not already resulted
    require(!auction.resulted, "auction already resulted");

    // Get info on who the highest bidder is
    HighestBid storage highestBid = highestBids[_nftAddress][_tokenId];
    address winner = highestBid.bidder;
    uint256 winningBid = highestBid.bid;

    // Ensure there is a winner
    require(winner != address(0), "no open bids");
    require(winningBid >= auction.reservePrice, "highest bid is below reservePrice");

    // Ensure this contract is approved to move the token
    require(IERC721Upgradeable(_nftAddress).isApprovedForAll(msg.sender, address(this)), "auction not approved");

    // Result the auction
    auction.resulted = true;

    // Clean up the highest bid
    delete highestBids[_nftAddress][_tokenId];

    uint256 feeAmount = (winningBid * platformFee) / 100_0;

    IERC20Upgradeable payToken = IERC20Upgradeable(auction.payToken);
    payToken.safeTransfer(feeRecipient, feeAmount);
    payToken.safeTransfer(auction.owner, winningBid - feeAmount);

    // Transfer the token to the winner
    IERC721Upgradeable(_nftAddress).safeTransferFrom(
      IERC721Upgradeable(_nftAddress).ownerOf(_tokenId),
      winner,
      _tokenId
    );

    // Remove auction
    delete auctions[_nftAddress][_tokenId];

    emit AuctionResulted(msg.sender, _nftAddress, _tokenId, winner, auction.payToken, winningBid);
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

  function cancelAuction(address _nftAddress, uint256 _tokenId) external nonReentrant {
    // Check valid and not resulted
    Auction memory auction = auctions[_nftAddress][_tokenId];

    require(
      IERC721Upgradeable(_nftAddress).ownerOf(_tokenId) == msg.sender && msg.sender == auction.owner,
      "sender must be owner"
    );
    // Check auction is real
    require(auction.endTime > 0, "no auction exists");
    // Check auction not already resulted
    require(!auction.resulted, "auction already resulted");

    _cancelAuction(_nftAddress, _tokenId);
  }

  function _cancelAuction(address _nftAddress, uint256 _tokenId) private {
    // refund existing top bidder if found
    HighestBid storage highestBid = highestBids[_nftAddress][_tokenId];
    if (highestBid.bidder != address(0)) {
      _refundHighestBidder(_nftAddress, _tokenId, highestBid.bidder, highestBid.bid);

      // Clear up highest bid
      delete highestBids[_nftAddress][_tokenId];
    }

    // Remove auction and top bidder
    delete auctions[_nftAddress][_tokenId];

    emit AuctionCancelled(_nftAddress, _tokenId);
  }

  function _refundHighestBidder(
    address _nftAddress,
    uint256 _tokenId,
    address _currentHighestBidder,
    uint256 _currentHighestBid
  ) private {
    Auction memory auction = auctions[_nftAddress][_tokenId];
    // if (auction.payToken == address(0)) {
    //   // refund previous best (if bid exists)
    //   (bool successRefund, ) = _currentHighestBidder.call{value: _currentHighestBid}("");
    //   require(successRefund, "failed to refund previous bidder");
    // } else {
    IERC20Upgradeable payToken = IERC20Upgradeable(auction.payToken);
    payToken.safeTransfer(_currentHighestBidder, _currentHighestBid);
    // }

    emit BidRefunded(_nftAddress, _tokenId, _currentHighestBidder, _currentHighestBid);
  }

  function _getNow() internal view virtual returns (uint256) {
    return block.timestamp;
  }

  /**
   * @notice Pause Oparcade
   * @dev Only owner
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @notice Resume Oparcade
   * @dev Only owner
   */
  function unpause() external onlyOwner {
    _unpause();
  }
}
