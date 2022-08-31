const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("AddressRegistry", () => {
  let addressRegistry;

  before(async () => {
    [deployer, marketplace, auction, tokenRegistry] = await ethers.getSigners();

    // Initialize AddressRegistry contract
    const AddressRegistry = await ethers.getContractFactory("AddressRegistry");
    addressRegistry = await upgrades.deployProxy(AddressRegistry);
  });

  it("Should be able to update Marketplace...", async () => {
    await addressRegistry.updateMarketplace(marketplace.address);
    expect(await addressRegistry.marketplace()).to.equal(marketplace.address);
  });

  it("Should revert if new Marketplace address is address (0)...", async () => {
    await expect(addressRegistry.updateMarketplace(ethers.constants.AddressZero)).to.be.revertedWith("!Marketplace");
  });

  it("Should be able to update Auction...", async () => {
    await addressRegistry.updateAuction(auction.address);
    expect(await addressRegistry.auction()).to.equal(auction.address);
  });

  it("Should revert if new Auction address is address (0)...", async () => {
    await expect(addressRegistry.updateAuction(ethers.constants.AddressZero)).to.be.revertedWith("!Auction");
  });

  it("Should be able to update TokenRegistry...", async () => {
    await addressRegistry.updateTokenRegistry(tokenRegistry.address);
    expect(await addressRegistry.tokenRegistry()).to.equal(tokenRegistry.address);
  });

  it("Should revert if new TokenRegistry address is address (0)...", async () => {
    await expect(addressRegistry.updateTokenRegistry(ethers.constants.AddressZero)).to.be.revertedWith(
      "!TokenRegistry",
    );
  });
});
