// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/IERC165Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/IERC1155Upgradeable.sol";
import "./interfaces/IAddressRegistry.sol";
import "./interfaces/ITokenRegistry.sol";

contract OPGamesMarketplace is Initializable, OwnableUpgradeable, ReentrancyGuardUpgradeable, ERC721HolderUpgradeable {
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

  bytes4 private constant INTERFACE_ID_ERC721 = 0x80ac58cd;
  bytes4 private constant INTERFACE_ID_ERC1155 = 0xd9b67a26;

  /// @notice NFTAddress -> Token ID -> Owner -> Listing
  mapping(address => mapping(uint256 => mapping(address => Listing))) public listings;

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

  function initialize(
    address _addressRegistry,
    address payable _feeRecipient,
    uint256 _platformFee
  ) external initializer {
    __Ownable_init();
    __ReentrancyGuard_init();

    addressRegistry = IAddressRegistry(_addressRegistry);
    feeRecipient = _feeRecipient;
    platformFee = _platformFee;
  }

  // TODO: Lock NFT
  function listItem(
    address _nftAddress,
    uint256 _tokenId,
    uint256 _quantity,
    address _payToken,
    uint256 _pricePerItem,
    uint256 _startAt
  ) external {
    if (IERC165Upgradeable(_nftAddress).supportsInterface(INTERFACE_ID_ERC721)) {
      IERC721Upgradeable nft = IERC721Upgradeable(_nftAddress);
      require(nft.ownerOf(_tokenId) == msg.sender, "not owning item");
      require(nft.isApprovedForAll(msg.sender, address(this)), "itme not approved");
    } else if (IERC165Upgradeable(_nftAddress).supportsInterface(INTERFACE_ID_ERC1155)) {
      // TODO: ERC1155
    } else {
      revert("invalid nft address");
    }
  }

  function cancelListing(address _nftAddress, uint256 _tokenId)
    external
    nonReentrant
    isListed(_nftAddress, _tokenId, msg.sender)
  {}

  function updateListing() external {}

  // TODO: Withdraw NFT

  function buyItem(
    address _nftAddress,
    uint256 _tokenId,
    address _payToken,
    address _owner
  ) external nonReentrant isListed(_nftAddress, _tokenId, _owner) validListing(_nftAddress, _tokenId, _owner) {
    Listing memory listedItem = listings[_nftAddress][_tokenId][_owner];
    require(listedItem.payToken == _payToken, "invalid pay token");

    _buyItem(_nftAddress, _tokenId, _payToken, _owner);
  }

  function _buyItem(
    address nftAddress,
    uint256 _tokenId,
    address _payToken,
    address _owner
  ) private {}

  function createOffer(
    address _nftAddress,
    uint256 _tokenId,
    address _payToken,
    uint256 _quantity,
    uint256 _pricePerItem,
    uint256 _deadline
  ) external {}

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
    emit PlatformFeeUpdated(msg.sender, platformFee, _platformFee);

    platformFee = _platformFee;
  }

  /**
   @notice Update platform fee address
   @dev Only owner
   @param _feeRecipient new platform fee recipient
   */
  function updatePlatformFeeRecipient(address payable _feeRecipient) external onlyOwner {
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
}
