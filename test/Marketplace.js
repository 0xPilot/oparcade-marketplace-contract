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

describe("Marketplace", () => {
  let marketplace;

  const ZERO_ADDRESS = ethers.constants.AddressZero;
  const pricePerItem = ethers.utils.parseEther("1");

  const firstTokenId = 1;
  const secondTokenId = 2;
  const platformFee = 10_0;

  beforeEach(async () => {
    [owner, minter, buyer, feeRecipient] = await ethers.getSigners();

    // Initialize AddressRegistry contract
    const AddressRegistry = await ethers.getContractFactory("AddressRegistry");
    addressRegistry = await upgrades.deployProxy(AddressRegistry);

    // Initialize TokenRegistry contract
    const TokenRegistry = await ethers.getContractFactory("TokenRegistry");
    tokenRegistry = await upgrades.deployProxy(TokenRegistry);

    // Initialize Marketplace contract
    const Marketplace = await ethers.getContractFactory("OPGamesMarketplace");
    marketplace = await upgrades.deployProxy(Marketplace, [addressRegistry.address, feeRecipient.address, platformFee]);

    // deploy mock ERC20 token
    const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    mockERC20 = await ERC20Mock.deploy("mockToken", "mockToken");

    // deploy mock ERC721 token
    const MockERC721 = await ethers.getContractFactory("MockERC721");
    mockERC721 = await MockERC721.deploy();

    // Register the contract addresses
    await addressRegistry.updateTokenRegistry(tokenRegistry.address);
    await addressRegistry.updateMarketplace(marketplace.address);

    // Mint NFTs
    await mockERC721.mint(minter.address, 1);
    await mockERC721.mint(owner.address, 2);
  });

  describe("listItem", () => {
    it("Should revert if not owning NFT", async () => {
      await expect(
        marketplace.listItem(
          mockERC721.address,
          firstTokenId,
          1,
          ZERO_ADDRESS,
          pricePerItem,
          await getCurrentBlockTimestamp(),
        ),
      ).to.be.revertedWith("not owning item");
    });

    it("Should revert if not approved", async () => {
      await expect(
        marketplace
          .connect(minter)
          .listItem(mockERC721.address, firstTokenId, 1, ZERO_ADDRESS, pricePerItem, await getCurrentBlockTimestamp()),
      ).to.be.revertedWith("item not approved");
    });

    it("Should revert if the collection is not approved", async () => {
      await mockERC721.connect(minter).setApprovalForAll(marketplace.address, true);
      await expect(
        marketplace
          .connect(minter)
          .listItem(mockERC721.address, firstTokenId, 1, ZERO_ADDRESS, pricePerItem, await getCurrentBlockTimestamp()),
      ).to.be.revertedWith("invalid collection");
    });

    it("Should revert if the payment token is not approved", async () => {
      await tokenRegistry.addCollection(mockERC721.address);
      await mockERC721.connect(minter).setApprovalForAll(marketplace.address, true);
      await expect(
        marketplace
          .connect(minter)
          .listItem(
            mockERC721.address,
            firstTokenId,
            1,
            mockERC20.address,
            pricePerItem,
            await getCurrentBlockTimestamp(),
          ),
      ).to.be.revertedWith("invalid pay token");
    });

    it("Should list the item with the native token", async () => {
      await tokenRegistry.addCollection(mockERC721.address);
      await mockERC721.connect(minter).setApprovalForAll(marketplace.address, true);
      await marketplace
        .connect(minter)
        .listItem(mockERC721.address, firstTokenId, 1, ZERO_ADDRESS, pricePerItem, await getCurrentBlockTimestamp());
    });

    it("Should list the item with the ERC20 token", async () => {
      await tokenRegistry.addCollection(mockERC721.address);
      await tokenRegistry.addPayToken(mockERC20.address);
      await mockERC721.connect(minter).setApprovalForAll(marketplace.address, true);
      await marketplace
        .connect(minter)
        .listItem(
          mockERC721.address,
          firstTokenId,
          1,
          mockERC20.address,
          pricePerItem,
          await getCurrentBlockTimestamp(),
        );
    });
  });
});
