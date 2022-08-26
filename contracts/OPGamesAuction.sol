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

  receive() external payable {}

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

  /**
   * @notice Creates a new auction for a given item
   * @dev Only the owner of item can create an auction and must have approved the contract
   * @dev In addition to owning the item, the sender also has to have the MINTER role.
   * @dev End time for the auction must be in the future.
   * @param _nftAddress ERC 721 Address
   * @param _tokenId Token ID of the item being auctioned
   * @param _payToken Paying token
   * @param _reservePrice Item cannot be sold for less than this or minBidIncrement, whichever is higher
   * @param _startTimestamp Unix epoch in seconds for the auction start time
   * @param _minBidReserve Whether the reserve price should be applied or not
   * @param _endTimestamp Unix epoch in seconds for the auction end time.
   */
  function createAuction(
    address _nftAddress,
    uint256 _tokenId,
    address _payToken,
    uint256 _reservePrice,
    uint256 _startTimestamp,
    bool _minBidReserve,
    uint256 _endTimestamp
  ) external whenNotPaused {
    // Ensure this contract is approved to move the token
    require(
      IERC721Upgradeable(_nftAddress).ownerOf(_tokenId) == msg.sender &&
        IERC721Upgradeable(_nftAddress).isApprovedForAll(msg.sender, address(this)),
      "not owner and or contract not approved"
    );

    _validCollection(_nftAddress);
    _validPayToken(_payToken);

    _createAuction(_nftAddress, _tokenId, _payToken, _reservePrice, _startTimestamp, _minBidReserve, _endTimestamp);
  }

  /**
   * @notice Places a new bid, out bidding the existing bidder if found and criteria is reached
   * @dev Only callable when the auction is open
   * @dev Bids from smart contracts are prohibited to prevent griefing with always reverting receiver
   * @param _nftAddress ERC 721 Address
   * @param _tokenId Token ID of the item being auctioned
   * @param _bidAmount Bid amount
   */
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

    require(_bidAmount >= minBidRequired, "failed to outbid highest bidder");
    _tokenTransferFrom(msg.sender, address(this), auction.payToken, _bidAmount);

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

  /**
   * @notice Allows the hightest bidder to withdraw the bid (after 12 hours post auction's end) 
   * @dev Only callable by the existing top bidder
   * @param _nftAddress ERC 721 Address
   * @param _tokenId Token ID of the item being auctioned
   */
  function withdrawBid(address _nftAddress, uint256 _tokenId) external nonReentrant {
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

  /**
   * @notice Closes a finished auction and rewards the highest bidder
   * @dev Only admin or smart contract
   * @dev Auction can only be resulted if there has been a bidder and reserve met.
   * @dev If there have been no bids, the auction needs to be cancelled instead using `cancelAuction()`
   * @param _nftAddress ERC 721 Address
   * @param _tokenId Token ID of the item being auctioned
   */
  function resultAuction(address _nftAddress, uint256 _tokenId) external nonReentrant whenNotPaused {
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

  /**
   * @notice Private method doing the heavy lifting of creating an auction
   * @param _nftAddress ERC 721 Address
   * @param _tokenId Token ID of the NFT being auctioned
   * @param _payToken Paying token
   * @param _reservePrice Item cannot be sold for less than this or minBidIncrement, whichever is higher
   * @param _startTimestamp Unix epoch in seconds for the auction start time
   * @param _endTimestamp Unix epoch in seconds for the auction end time.
   */
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

  /**
   * @notice Cancels and inflight and un-resulted auctions, returning the funds to the top bidder if found
   * @dev Only item owner
   * @param _nftAddress ERC 721 Address
   * @param _tokenId Token ID of the NFT being auctioned
   */
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

  /**
   * @notice Used for sending back escrowed funds from a previous bid
   * @param _currentHighestBidder Address of the last highest bidder
   * @param _currentHighestBid Ether or Mona amount in WEI that the bidder sent when placing their bid
   */
  function _refundHighestBidder(
    address _nftAddress,
    uint256 _tokenId,
    address _currentHighestBidder,
    uint256 _currentHighestBid
  ) private {
    Auction memory auction = auctions[_nftAddress][_tokenId];

    _tokenTransferFrom(address(this), _currentHighestBidder, auction.payToken, _currentHighestBid);

    emit BidRefunded(_nftAddress, _tokenId, _currentHighestBidder, _currentHighestBid);
  }

  /**
   * @notice Validate the payment token
   * @dev Zero address means the native token
   * @param _payToken Payment token address
   */
  function _validPayToken(address _payToken) internal view {
    require(
      _payToken == address(0) ||
        (addressRegistry.tokenRegistry() != address(0) &&
          ITokenRegistry(addressRegistry.tokenRegistry()).enabledPayToken(_payToken)),
      "invalid pay token"
    );
  }

  /**
   * @notice Validate the collection
   * @param _nftAddress Collection address
   */
  function _validCollection(address _nftAddress) internal view {
    require(
      (addressRegistry.tokenRegistry() != address(0) &&
        ITokenRegistry(addressRegistry.tokenRegistry()).enabledCollection(_nftAddress)),
      "invalid collection"
    );
  }

  /**
   * @notice Transfer tokens
   * @dev If the _payToken address is zero, it means the native token
   * @param _from Sender address
   * @param _to Receiver address
   * @param _payToken Payment token address
   * @param _amount Payment token amount
   */
  function _tokenTransferFrom(
    address _from,
    address _to,
    address _payToken,
    uint256 _amount
  ) private {
    if (_payToken == address(0)) {
      require(_from == address(this), "invalid Ether sender");

      (bool sent, ) = payable(_to).call{value: _amount}("");
      require(sent, "failed to send Ether");
    } else {
      IERC20Upgradeable(_payToken).safeTransferFrom(_from, _to, _amount);
    }
  }

  function _getNow() internal view virtual returns (uint256) {
    return block.timestamp;
  }

  /**
   * @notice Pause Auction
   * @dev Only owner
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @notice Resume Auction
   * @dev Only owner
   */
  function unpause() external onlyOwner {
    _unpause();
  }
}
