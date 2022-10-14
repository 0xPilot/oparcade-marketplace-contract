const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

const increaseTime = async (sec) => {
  await hre.network.provider.send("evm_increaseTime", [sec]);
  await hre.network.provider.send("evm_mine");
};

const getCurrentBlockTimestamp = async () => {
  const blockNumber = await ethers.provider.getBlockNumber();
  const block = await ethers.provider.getBlock(blockNumber);
  return block.timestamp;
};

describe("Auction", () => {
  let addressRegistry, tokenRegistry, auction;

  const ZERO_ADDRESS = ethers.constants.AddressZero;
  const pricePerItem = ethers.utils.parseEther("1");
  const newPrice = ethers.utils.parseEther("2");

  const firstTokenId = 1;
  const secondTokenId = 2;
  const platformFee = 10_0;
  const minBidPeriod = 300;

  beforeEach(async () => {
    [owner, minter, buyer, feeRecipient] = await ethers.getSigners();

    // Initialize AddressRegistry contract
    const AddressRegistry = await ethers.getContractFactory("AddressRegistry");
    addressRegistry = await upgrades.deployProxy(AddressRegistry);

    // Initialize TokenRegistry contract
    const TokenRegistry = await ethers.getContractFactory("TokenRegistry");
    tokenRegistry = await upgrades.deployProxy(TokenRegistry);

    // Initialize Auction contract
    const Auction = await ethers.getContractFactory("OPGamesAuction");
    auction = await upgrades.deployProxy(Auction, [addressRegistry.address, feeRecipient.address, platformFee]);

    // deploy mock ERC20 token
    const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    mockERC20 = await ERC20Mock.deploy("mockToken", "mockToken");

    // deploy mock ERC721 token
    const MockERC721 = await ethers.getContractFactory("MockERC721");
    mockERC721 = await MockERC721.deploy();

    // deploy mockERC1155 token
    const MockERC1155 = await ethers.getContractFactory("MockERC1155");
    mockERC1155 = await MockERC1155.deploy();

    // Register the contract addresses
    await addressRegistry.updateTokenRegistry(tokenRegistry.address);
    await addressRegistry.updateAuction(auction.address);

    // Mint NFTs
    await mockERC721.mint(minter.address, 1);
    await mockERC721.mint(owner.address, 2);

    await mockERC1155.mint(minter.address, [1, 2, 3], [10, 10, 10]);
    await mockERC1155.mint(owner.address, [4, 5, 6], [10, 10, 10]);

    // Transfer ERC20 tokens
    await mockERC20.transfer(buyer.address, pricePerItem.mul(10000));
  });

  describe("initialize", () => {
    it("Should revert if addressRegistry is address(0)", async () => {
      const Auction = await ethers.getContractFactory("OPGamesAuction");
      await expect(upgrades.deployProxy(Auction, [ZERO_ADDRESS, feeRecipient.address, platformFee])).to.be.revertedWith(
        "unexpected address registry",
      );
    });

    it("Should revert if fee recipient address is address(0)", async () => {
      const Auction = await ethers.getContractFactory("OPGamesAuction");
      await expect(
        upgrades.deployProxy(Auction, [addressRegistry.address, ZERO_ADDRESS, platformFee]),
      ).to.be.revertedWith("unexpected fee recipient");
    });

    it("Should revert if platform fee is equal to / greater than 1000", async () => {
      const Auction = await ethers.getContractFactory("OPGamesAuction");
      await expect(
        upgrades.deployProxy(Auction, [addressRegistry.address, feeRecipient.address, 1000]),
      ).to.be.revertedWith("platform fee exceeded");
    });
  });

  describe("createAuction", () => {
    it("Should revert if endTime is in the past", async () => {
      await tokenRegistry.addCollection(mockERC721.address);

      const currentTime = await getCurrentBlockTimestamp();
      await expect(
        auction
          .connect(minter)
          .createAuction(
            mockERC721.address,
            firstTokenId,
            ZERO_ADDRESS,
            pricePerItem,
            currentTime - 100,
            true,
            currentTime + minBidPeriod,
          ),
      ).to.be.revertedWith("not owner and or contract not approved");
    });

    it("Should revert if the collection was not registered", async () => {
      await mockERC721.connect(minter).setApprovalForAll(auction.address, true);

      const currentTime = await getCurrentBlockTimestamp();
      await expect(
        auction
          .connect(minter)
          .createAuction(
            mockERC721.address,
            firstTokenId,
            ZERO_ADDRESS,
            pricePerItem,
            currentTime - 100,
            true,
            currentTime + minBidPeriod,
          ),
      ).to.be.revertedWith("invalid collection");
    });

    it("Should revert if endTime is in the past", async () => {
      await tokenRegistry.addCollection(mockERC721.address);
      await mockERC721.connect(minter).setApprovalForAll(auction.address, true);

      const currentTime = await getCurrentBlockTimestamp();
      await expect(
        auction
          .connect(minter)
          .createAuction(
            mockERC721.address,
            firstTokenId,
            ZERO_ADDRESS,
            pricePerItem,
            currentTime - 100,
            true,
            currentTime + minBidPeriod,
          ),
      ).to.be.revertedWith("invalid start time");
    });

    it("Should create the auction", async () => {
      await tokenRegistry.addCollection(mockERC721.address);
      await mockERC721.connect(minter).setApprovalForAll(auction.address, true);

      const currentTime = await getCurrentBlockTimestamp();
      await auction
        .connect(minter)
        .createAuction(
          mockERC721.address,
          firstTokenId,
          ZERO_ADDRESS,
          pricePerItem,
          currentTime + 10,
          true,
          currentTime + minBidPeriod + 10,
        );
    });
  });
});
