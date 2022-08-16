// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interfaces/IOPGamesAuction.sol";
import "./interfaces/IAddressRegistry.sol";
import "./interfaces/ITokenRegistry.sol";

contract OPGamesMarketplace is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, PausableUpgradeable {
  using SafeERC20Upgradeable for IERC20Upgradeable;

  /// @notice Events for the contract
  event ItemListed(
    address indexed owner,
    address indexed nft,
    uint256 tokenId,
    uint256 quantity,
    address payToken,
    uint256 pricePerItem,
    uint256 startingTime
  );
  event ItemSold(
    address indexed seller,
    address indexed buyer,
    address indexed nft,
    uint256 tokenId,
    uint256 quantity,
    address payToken,
    uint256 pricePerItem
  );
  event ItemUpdated(address indexed owner, address indexed nft, uint256 tokenId, address payToken, uint256 newPrice);
  event ItemCanceled(address indexed owner, address indexed nft, uint256 tokenId);
  event OfferCreated(
    address indexed creator,
    address indexed nft,
    uint256 tokenId,
    uint256 quantity,
    address payToken,
    uint256 pricePerItem,
    uint256 deadline
  );
  event PlatformFeeUpdated(address indexed by, uint256 oldPlatformFee, uint256 newPlatformFee);
  event PlatformFeeRecipientUpdated(
    address indexed by,
    address indexed oldFeeRecipient,
    address indexed newFeeRecipient
  );

  /// @notice Structure for listed items
  struct Listing {
    uint256 quantity;
    address payToken;
    uint256 pricePerItem;
    uint256 startAt;
  }

  /// @notice Structure for offer
  struct Offer {
    IERC20Upgradeable payToken;
    uint256 quantity;
    uint256 pricePerItem;
    uint256 deadline;
  }

  bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
  bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

  /// @notice NFT Address -> Token ID -> Owner -> Listing
  mapping(address => mapping(uint256 => mapping(address => Listing))) public listings;

  // /// @notice NFT Address -> Token ID -> Offerer -> Offer
  // mapping(address => mapping(uint256 => mapping(address => Offer))) public offers;

  /// @notice Platform fee recipient
  address payable public feeRecipient;

  /// @notice Platform fee
  uint256 public platformFee;

  /// @notice AddressRegistry
  IAddressRegistry public addressRegistry;

  modifier isListed(
    address _nftAddress,
    uint256 _tokenId,
    address _owner
  ) {
    Listing memory listing = listings[_nftAddress][_tokenId][_owner];
    require(listing.quantity > 0, "not listed item");
    _;
  }

  modifier notListed(
    address _nftAddress,
    uint256 _tokenId,
    address _owner
  ) {
    Listing memory listing = listings[_nftAddress][_tokenId][_owner];
    require(listing.quantity == 0, "already listed");
    _;
  }

  modifier validListing(
    address _nftAddress,
    uint256 _tokenId,
    address _owner
  ) {
    Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];

    _validOwner(_nftAddress, _tokenId, _owner, listedItem.quantity);

    require(_getNow() >= listedItem.startAt, "item not buyable");
    _;
  }

  // modifier offerExists(
  //   address _nftAddress,
  //   uint256 _tokenId,
  //   address _creator
  // ) {
  //   Offer memory offer = offers[_nftAddress][_tokenId][_creator];
  //   require(offer.quantity > 0 && offer.deadline > _getNow(), "offer not exists or expired");
  //   _;
  // }

  // modifier offerNotExists(
  //   address _nftAddress,
  //   uint256 _tokenId,
  //   address _creator
  // ) {
  //   Offer memory offer = offers[_nftAddress][_tokenId][_creator];
  //   require(offer.quantity == 0 || offer.deadline <= _getNow(), "offer already created");
  //   _;
  // }

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

  function listItem(
    address _nftAddress,
    uint256 _tokenId,
    uint256 _quantity,
    address _payToken,
    uint256 _pricePerItem,
    uint256 _startAt
  ) external notListed(_nftAddress, _tokenId, msg.sender) {
    if (IERC165Upgradeable(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
      IERC721Upgradeable nft = IERC721Upgradeable(_nftAddress);
      require(nft.ownerOf(_tokenId) == msg.sender, "not owning item");
      require(nft.isApprovedForAll(msg.sender, address(this)), "item not approved");
    } else if (IERC165Upgradeable(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)) {
      IERC1155Upgradeable nft = IERC1155Upgradeable(_nftAddress);
      require(nft.balanceOf(msg.sender, _tokenId) >= _quantity, "must hold enough nfts");
      require(nft.isApprovedForAll(msg.sender, address(this)), "item not approved");
    } else {
      revert("invalid nft address");
    }

    _validCollection(_nftAddress);
    _validPayToken(_payToken);

    listings[_nftAddress][_tokenId][msg.sender] = Listing(_quantity, _payToken, _pricePerItem, _startAt);

    emit ItemListed(msg.sender, _nftAddress, _tokenId, _quantity, _payToken, _pricePerItem, _startAt);
  }

  function cancelListing(address _nftAddress, uint256 _tokenId)
    external
    nonReentrant
    isListed(_nftAddress, _tokenId, msg.sender)
  {
    _cancelListing(_nftAddress, _tokenId, msg.sender);
  }

  function updateListing(
    address _nftAddress,
    uint256 _tokenId,
    address _payToken,
    uint256 _newPrice
  ) external nonReentrant isListed(_nftAddress, _tokenId, msg.sender) {
    Listing storage listedItem = listings[_nftAddress][_tokenId][msg.sender];

    _validOwner(_nftAddress, _tokenId, msg.sender, listedItem.quantity);

    _validPayToken(_payToken);

    listedItem.payToken = _payToken;
    listedItem.pricePerItem = _newPrice;

    emit ItemUpdated(msg.sender, _nftAddress, _tokenId, _payToken, _newPrice);
  }

  function buyItem(
    address _nftAddress,
    uint256 _tokenId,
    address _payToken,
    address payable _owner
  )
    external
    payable
    nonReentrant
    whenNotPaused
    isListed(_nftAddress, _tokenId, _owner)
    validListing(_nftAddress, _tokenId, _owner)
  {
    Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];
    require(listedItem.payToken == _payToken, "invalid pay token");

    _buyItem(_nftAddress, _tokenId, _payToken, _owner);
  }

  function _buyItem(
    address _nftAddress,
    uint256 _tokenId,
    address _payToken,
    address payable _owner
  ) private {
    Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];

    uint256 price = listedItem.pricePerItem * listedItem.quantity;
    uint256 feeAmount = (price * platformFee) / 100_0;

    // Transfer token to owner
    if (_payToken == address(0)) {
      require(msg.value == price, "insufficient Ether to buy");
    }
    _tokenTransferFrom(msg.sender, feeRecipient, _payToken, feeAmount);
    _tokenTransferFrom(msg.sender, _owner, _payToken, price - feeAmount);

    // Transfer NFT to buyer
    if (IERC165Upgradeable(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
      IERC721Upgradeable(_nftAddress).safeTransferFrom(_owner, msg.sender, _tokenId);
    } else {
      IERC1155Upgradeable(_nftAddress).safeTransferFrom(_owner, msg.sender, _tokenId, listedItem.quantity, bytes(""));
    }

    delete (listings[_nftAddress][_tokenId][_owner]);

    emit ItemSold(_owner, msg.sender, _nftAddress, _tokenId, listedItem.quantity, _payToken, listedItem.pricePerItem);
  }

  // function createOffer(
  //   address _nftAddress,
  //   uint256 _tokenId,
  //   IERC20Upgradeable _payToken,
  //   uint256 _quantity,
  //   uint256 _pricePerItem,
  //   uint256 _deadline
  // ) external offerNotExists(_nftAddress, _tokenId, msg.sender) {
  //   require(
  //     IERC165Upgradeable(_nftAddress).supportsInterface(INTERFACE_ID_ERC721) ||
  //       IERC165Upgradeable(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155),
  //     "invalid nft address"
  //   );

  //   IOPGamesAuction auction = IOPGamesAuction(addressRegistry.auction());

  //   (, , , uint256 startTime, , bool resulted) = auction.auctions(_nftAddress, _tokenId);

  //   require(startTime == 0 || resulted == true, "cannot place an offer if auction is going on");

  //   require(_deadline > _getNow(), "invalid expiration");

  //   _validPayToken(address(_payToken));

  //   offers[_nftAddress][_tokenId][msg.sender] = Offer(_payToken, _quantity, _pricePerItem, _deadline);

  //   emit OfferCreated(msg.sender, _nftAddress, _tokenId, _quantity, address(_payToken), _pricePerItem, _deadline);
  // }

  function cancelOffer(address _nftAddress, uint256 _tokenId) external {}

  function acceptOffer(
    address _nftAddress,
    uint256 _tokenId,
    address _creator
  ) external nonReentrant {}

  /**
   @notice Update platform fee
   @dev Only owner
   @param _platformFee new platform fee
   */
  function updatePlatformFee(uint256 _platformFee) external onlyOwner {
    require(_platformFee < 100_0, "platform fee exceeded");

    emit PlatformFeeUpdated(msg.sender, platformFee, _platformFee);

    platformFee = _platformFee;
  }

  /**
   @notice Update platform fee address
   @dev Only owner
   @param _feeRecipient new platform fee recipient
   */
  function updatePlatformFeeRecipient(address payable _feeRecipient) external onlyOwner {
    require(_feeRecipient != address(0), "unexpected fee recipient");

    emit PlatformFeeRecipientUpdated(msg.sender, feeRecipient, _feeRecipient);

    feeRecipient = _feeRecipient;
  }

  function _getNow() internal view virtual returns (uint256) {
    return block.timestamp;
  }

  function _validCollection(address _nftAddress) internal view {
    require(
      (addressRegistry.tokenRegistry() != address(0) &&
        ITokenRegistry(addressRegistry.tokenRegistry()).enabledCollection(_nftAddress)),
      "invalid collection"
    );
  }

  function _validPayToken(address _payToken) internal view {
    require(
      _payToken == address(0) ||
        (addressRegistry.tokenRegistry() != address(0) &&
          ITokenRegistry(addressRegistry.tokenRegistry()).enabledPayToken(_payToken)),
      "invalid pay token"
    );
  }

  function _validOwner(
    address _nftAddress,
    uint256 _tokenId,
    address _owner,
    uint256 quantity
  ) internal view {
    if (IERC165Upgradeable(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
      IERC721Upgradeable nft = IERC721Upgradeable(_nftAddress);
      require(nft.ownerOf(_tokenId) == _owner, "not owning item");
    } else if (IERC165Upgradeable(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)) {
      IERC1155Upgradeable nft = IERC1155Upgradeable(_nftAddress);
      require(nft.balanceOf(_owner, _tokenId) >= quantity, "not owning item");
    } else {
      revert("invalid nft address");
    }
  }

  function _cancelListing(
    address _nftAddress,
    uint256 _tokenId,
    address _owner
  ) private {
    Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];

    _validOwner(_nftAddress, _tokenId, _owner, listedItem.quantity);

    delete (listings[_nftAddress][_tokenId][_owner]);

    emit ItemCanceled(_owner, _nftAddress, _tokenId);
  }

  function _tokenTransferFrom(
    address _from,
    address payable _to,
    address _payToken,
    uint256 _amount
  ) private {
    if (_payToken == address(0)) {
      require(_from == address(this), "invalid Ether sender");

      (bool sent, ) = _to.call{value: _amount}("");
      require(sent, "failed to send Ether");
    } else {
      IERC20Upgradeable(_payToken).safeTransferFrom(_from, _to, _amount);
    }
  }

  /**
   * @notice Pause Marketplace
   * @dev Only owner
   */
  function pause() external onlyOwner {
    _pause();
  }

  /**
   * @notice Resume Marketplace
   * @dev Only owner
   */
  function unpause() external onlyOwner {
    _unpause();
  }
}
