const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("TokenRegistry", () => {
  let tokenRegistry;

  beforeEach(async () => {
    [deployer] = await ethers.getSigners();

    // Initialize TokenRegistry contract
    const TokenRegistry = await ethers.getContractFactory("TokenRegistry");
    tokenRegistry = await upgrades.deployProxy(TokenRegistry);

    // deploy mock ERC20 token
    const ERC20Mock = await ethers.getContractFactory("ERC20Mock");
    mockERC20 = await ERC20Mock.deploy("mockToken", "mockToken");

    // deploy mock ERC721 token
    const MockERC721 = await ethers.getContractFactory("MockERC721");
    mockERC721 = await MockERC721.deploy();

    // deploy mock ERC1155 token
    const MockERC1155 = await ethers.getContractFactory("MockERC1155");
    mockERC1155 = await MockERC1155.deploy();
  });

  describe("Collection", () => {
    it("Should be able to add the collection...", async () => {
      expect(await tokenRegistry.enabledCollection(mockERC721.address)).to.be.false;

      await tokenRegistry.addCollection(mockERC721.address);
      expect(await tokenRegistry.enabledCollection(mockERC721.address)).to.be.true;
    });

    it("Should revert if the collection was already added...", async () => {
      await tokenRegistry.addCollection(mockERC721.address);
      await expect(tokenRegistry.addCollection(mockERC721.address)).to.be.revertedWith("collection already added");
    });

    it("Should revert if the collection is not an NFT...", async () => {
      await expect(tokenRegistry.addCollection(mockERC20.address)).to.be.revertedWith("unexpected collection");
    });

    it("Should be able to remove the collection...", async () => {
      await tokenRegistry.addCollection(mockERC1155.address);
      expect(await tokenRegistry.enabledCollection(mockERC1155.address)).to.be.true;

      await tokenRegistry.removeCollection(mockERC1155.address);
      expect(await tokenRegistry.enabledCollection(mockERC1155.address)).to.be.false;
    });

    it("Should revert if the collection doesn't exist...", async () => {
      await expect(tokenRegistry.removeCollection(mockERC1155.address)).to.be.revertedWith("collection not exist");
    });
  });

  describe("Payment Token", () => {
    it("Should be able to add the payment token...", async () => {
      expect(await tokenRegistry.enabledPayToken(mockERC20.address)).to.be.false;

      await tokenRegistry.addPayToken(mockERC20.address);
      expect(await tokenRegistry.enabledPayToken(mockERC20.address)).to.be.true;
    });

    it("Should revert if the payment token was already added...", async () => {
      await tokenRegistry.addPayToken(mockERC20.address);
      await expect(tokenRegistry.addPayToken(mockERC20.address)).to.be.revertedWith("token already added");
    });

    it("Should revert if the payment token address is address(0)...", async () => {
      await expect(tokenRegistry.addPayToken(ethers.constants.AddressZero)).to.be.revertedWith("zero token address");
    });

    it("Should be able to remove the payment token...", async () => {
      await tokenRegistry.addPayToken(mockERC20.address);
      expect(await tokenRegistry.enabledPayToken(mockERC20.address)).to.be.true;

      await tokenRegistry.removePayToken(mockERC20.address);
      expect(await tokenRegistry.enabledPayToken(mockERC20.address)).to.be.false;
    });

    it("Should revert if the payment token doesn't exist...", async () => {
      await expect(tokenRegistry.removePayToken(mockERC20.address)).to.be.revertedWith("token not exist");
    });
  });
});
