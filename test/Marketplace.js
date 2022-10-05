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
  let addressRegistry, tokenRegistry, marketplace, auction;

  const ZERO_ADDRESS = ethers.constants.AddressZero;
  const pricePerItem = ethers.utils.parseEther("1");
  const newPrice = ethers.utils.parseEther("2");

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
    await addressRegistry.updateMarketplace(marketplace.address);
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
      const Marketplace = await ethers.getContractFactory("OPGamesMarketplace");
      await expect(
        upgrades.deployProxy(Marketplace, [ZERO_ADDRESS, feeRecipient.address, platformFee]),
      ).to.be.revertedWith("unexpected address registry");
    });

    it("Should revert if fee recipient address is address(0)", async () => {
      const Marketplace = await ethers.getContractFactory("OPGamesMarketplace");
      await expect(
        upgrades.deployProxy(Marketplace, [addressRegistry.address, ZERO_ADDRESS, platformFee]),
      ).to.be.revertedWith("unexpected fee recipient");
    });

    it("Should revert if platform fee is equal to / greater than 1000", async () => {
      const Marketplace = await ethers.getContractFactory("OPGamesMarketplace");
      await expect(
        upgrades.deployProxy(Marketplace, [addressRegistry.address, feeRecipient.address, 1000]),
      ).to.be.revertedWith("platform fee exceeded");
    });
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

    it("Should revert if not hold the enough NFTs (ERC1155)", async () => {
      await expect(
        marketplace
          .connect(minter)
          .listItem(
            mockERC1155.address,
            firstTokenId,
            11,
            ZERO_ADDRESS,
            pricePerItem,
            await getCurrentBlockTimestamp(),
          ),
      ).to.be.revertedWith("must hold enough nfts");
    });

    it("Should revert if not approved (ERC1155)", async () => {
      await expect(
        marketplace
          .connect(minter)
          .listItem(
            mockERC1155.address,
            firstTokenId,
            10,
            ZERO_ADDRESS,
            pricePerItem,
            await getCurrentBlockTimestamp(),
          ),
      ).to.be.revertedWith("item not approved");
    });

    it("Should revert if the item type is not NFT", async () => {
      await expect(
        marketplace
          .connect(minter)
          .listItem(mockERC20.address, firstTokenId, 10, ZERO_ADDRESS, pricePerItem, await getCurrentBlockTimestamp()),
      ).to.be.revertedWith("invalid nft address");
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

    it("Should list the item with the native token (ERC721)", async () => {
      await tokenRegistry.addCollection(mockERC721.address);
      await mockERC721.connect(minter).setApprovalForAll(marketplace.address, true);
      await marketplace
        .connect(minter)
        .listItem(mockERC721.address, firstTokenId, 1, ZERO_ADDRESS, pricePerItem, await getCurrentBlockTimestamp());
    });

    it("Should list the item with the ERC20 token (ERC1155)", async () => {
      await tokenRegistry.addCollection(mockERC1155.address);
      await tokenRegistry.addPayToken(mockERC20.address);
      await mockERC1155.connect(minter).setApprovalForAll(marketplace.address, true);
      await marketplace
        .connect(minter)
        .listItem(
          mockERC1155.address,
          firstTokenId,
          1,
          mockERC20.address,
          pricePerItem,
          await getCurrentBlockTimestamp(),
        );
    });

    it("Should revert if already listed", async () => {
      await tokenRegistry.addCollection(mockERC721.address);
      await mockERC721.connect(minter).setApprovalForAll(marketplace.address, true);
      await marketplace
        .connect(minter)
        .listItem(mockERC721.address, firstTokenId, 1, ZERO_ADDRESS, pricePerItem, await getCurrentBlockTimestamp());

      await expect(
        marketplace
          .connect(minter)
          .listItem(mockERC721.address, firstTokenId, 1, ZERO_ADDRESS, pricePerItem, await getCurrentBlockTimestamp()),
      ).to.be.revertedWith("already listed");
    });
  });

  describe("cancelListing", () => {
    beforeEach(async () => {
      await tokenRegistry.addCollection(mockERC721.address);
      await mockERC721.connect(minter).setApprovalForAll(marketplace.address, true);
      await marketplace
        .connect(minter)
        .listItem(mockERC721.address, firstTokenId, 1, ZERO_ADDRESS, pricePerItem, await getCurrentBlockTimestamp());
    });

    it("Should revert if the item is not listed", async () => {
      await expect(marketplace.cancelListing(mockERC721.address, secondTokenId)).to.be.revertedWith("not listed item");
    });

    it("Should revert if not owning the item", async () => {
      await mockERC721.connect(minter).transferFrom(minter.address, owner.address, firstTokenId);
      await expect(marketplace.connect(minter).cancelListing(mockERC721.address, firstTokenId)).to.be.revertedWith(
        "not owning item",
      );
    });

    it("Should cancel the listed item", async () => {
      await marketplace.connect(minter).cancelListing(mockERC721.address, firstTokenId);
    });
  });

  describe("updateListing", () => {
    beforeEach(async () => {
      await tokenRegistry.addCollection(mockERC721.address);
      await mockERC721.connect(minter).setApprovalForAll(marketplace.address, true);
      await marketplace
        .connect(minter)
        .listItem(mockERC721.address, firstTokenId, 1, ZERO_ADDRESS, pricePerItem, await getCurrentBlockTimestamp());
    });

    it("Should revert if the item is not listed", async () => {
      await expect(
        marketplace.updateListing(mockERC721.address, secondTokenId, mockERC20.address, newPrice),
      ).to.be.revertedWith("not listed item");
    });

    it("Should revert if not owning the item", async () => {
      await mockERC721.connect(minter).transferFrom(minter.address, owner.address, firstTokenId);
      await expect(
        marketplace.connect(minter).updateListing(mockERC721.address, firstTokenId, mockERC20.address, newPrice),
      ).to.be.revertedWith("not owning item");
    });

    it("Should update the item", async () => {
      await tokenRegistry.addPayToken(mockERC20.address);
      await marketplace.connect(minter).updateListing(mockERC721.address, firstTokenId, mockERC20.address, newPrice);
    });
  });

  describe("buyItem", () => {
    beforeEach(async () => {
      await tokenRegistry.addCollection(mockERC721.address);
      await mockERC721.connect(minter).setApprovalForAll(marketplace.address, true);
      await marketplace
        .connect(minter)
        .listItem(mockERC721.address, firstTokenId, 1, ZERO_ADDRESS, pricePerItem, await getCurrentBlockTimestamp());
    });

    it("Should revert if the seller doesn't own the item", async () => {
      await mockERC721.connect(minter).transferFrom(minter.address, owner.address, firstTokenId);
      await expect(
        marketplace
          .connect(buyer)
          .buyItem(mockERC721.address, firstTokenId, ZERO_ADDRESS, minter.address, { value: pricePerItem }),
      ).to.be.revertedWith("not owning item");
    });

    it("Should revert when buying before the scheduled time", async () => {
      await mockERC721.setApprovalForAll(marketplace.address, true);
      await marketplace.listItem(
        mockERC721.address,
        secondTokenId,
        1,
        ZERO_ADDRESS,
        pricePerItem,
        ethers.constants.MaxUint256,
      );

      await expect(
        marketplace
          .connect(buyer)
          .buyItem(mockERC721.address, secondTokenId, ZERO_ADDRESS, owner.address, { value: pricePerItem }),
      ).to.be.revertedWith("item not buyable");
    });

    it("Should revert if the amount is not enough", async () => {
      await expect(
        marketplace.connect(buyer).buyItem(mockERC721.address, firstTokenId, ZERO_ADDRESS, minter.address),
      ).to.be.revertedWith("insufficient Ether to buy");
    });

    it("Should buy the item", async () => {
      const feeRecipientBalanceBefore = await feeRecipient.getBalance();
      const minterBalanceBefore = await minter.getBalance();

      await marketplace
        .connect(buyer)
        .buyItem(mockERC721.address, firstTokenId, ZERO_ADDRESS, minter.address, { value: pricePerItem });

      const feeRecipientBalanceAfter = await feeRecipient.getBalance();
      const minterBalanceAfter = await minter.getBalance();
      expect(feeRecipientBalanceAfter.sub(feeRecipientBalanceBefore)).to.be.equal(
        pricePerItem.mul(platformFee).div(1000),
      );
      expect(minterBalanceAfter.sub(minterBalanceBefore)).to.be.equal(pricePerItem.mul(1000 - platformFee).div(1000));
    });
  });

  describe("createOffer", () => {
    beforeEach(async () => {
      await tokenRegistry.addCollection(mockERC721.address);
      await tokenRegistry.addPayToken(mockERC20.address);
    });

    it("Should revert if the item is not an NFT", async () => {
      await expect(
        marketplace
          .connect(buyer)
          .createOffer(
            mockERC20.address,
            firstTokenId,
            mockERC20.address,
            1,
            100,
            (await getCurrentBlockTimestamp()) + 300,
          ),
      ).to.be.revertedWith("invalid nft address");
    });

    it("Should revert if the item is on the auction", async () => {
      const currentTime = await getCurrentBlockTimestamp();
      await mockERC721.connect(minter).setApprovalForAll(auction.address, true);
      await auction
        .connect(minter)
        .createAuction(
          mockERC721.address,
          firstTokenId,
          mockERC20.address,
          100,
          currentTime + 100,
          false,
          currentTime + 500,
        );

      await expect(
        marketplace
          .connect(buyer)
          .createOffer(
            mockERC721.address,
            firstTokenId,
            mockERC20.address,
            1,
            100,
            (await getCurrentBlockTimestamp()) + 300,
          ),
      ).to.be.revertedWith("cannot place an offer if auction is going on");
    });

    it("Should revert if the deadline is expired", async () => {
      await expect(
        marketplace
          .connect(buyer)
          .createOffer(
            mockERC721.address,
            firstTokenId,
            mockERC20.address,
            1,
            100,
            (await getCurrentBlockTimestamp()) - 300,
          ),
      ).to.be.revertedWith("invalid expiration");
    });

    it("Should revert if the native token is offered", async () => {
      await expect(
        marketplace
          .connect(buyer)
          .createOffer(
            mockERC721.address,
            firstTokenId,
            ZERO_ADDRESS,
            1,
            100,
            (await getCurrentBlockTimestamp()) + 300,
          ),
      ).to.be.revertedWith("disabled native token");
    });

    it("Should create an offer", async () => {
      await marketplace
        .connect(buyer)
        .createOffer(
          mockERC721.address,
          firstTokenId,
          mockERC20.address,
          1,
          100,
          (await getCurrentBlockTimestamp()) + 300,
        );
    });

    it("Should revert if the offer already exists", async () => {
      await marketplace
        .connect(buyer)
        .createOffer(
          mockERC721.address,
          firstTokenId,
          mockERC20.address,
          1,
          100,
          (await getCurrentBlockTimestamp()) + 300,
        );

      await expect(
        marketplace
          .connect(buyer)
          .createOffer(
            mockERC721.address,
            firstTokenId,
            mockERC20.address,
            1,
            100,
            (await getCurrentBlockTimestamp()) + 300,
          ),
      ).to.be.revertedWith("offer already created");
    });
  });

  describe("cancelOffer", () => {
    beforeEach(async () => {
      await tokenRegistry.addCollection(mockERC721.address);
      await tokenRegistry.addPayToken(mockERC20.address);

      await mockERC20.connect(buyer).approve(marketplace.address, 100);
      await marketplace
        .connect(buyer)
        .createOffer(
          mockERC721.address,
          firstTokenId,
          mockERC20.address,
          1,
          100,
          (await getCurrentBlockTimestamp()) + 300,
        );
    });

    it("Should cancel the offer", async () => {
      let offer = await marketplace.offers(mockERC721.address, firstTokenId, buyer.address);
      expect(offer.payToken).to.be.equal(mockERC20.address);

      await marketplace.connect(buyer).cancelOffer(mockERC721.address, firstTokenId);

      offer = await marketplace.offers(mockERC721.address, firstTokenId, buyer.address);
      expect(offer.payToken).to.be.equal(ZERO_ADDRESS);
    });
  });

  describe("acceptOffer", () => {
    beforeEach(async () => {
      await tokenRegistry.addCollection(mockERC721.address);
      await tokenRegistry.addPayToken(mockERC20.address);

      await mockERC20.connect(buyer).approve(marketplace.address, 100);
      await marketplace
        .connect(buyer)
        .createOffer(
          mockERC721.address,
          firstTokenId,
          mockERC20.address,
          1,
          100,
          (await getCurrentBlockTimestamp()) + 300,
        );
    });

    it("Should revert if the offer is accepted by non NFT owner", async () => {
      await mockERC721.connect(minter).setApprovalForAll(marketplace.address, true);
      await expect(marketplace.acceptOffer(mockERC721.address, firstTokenId, buyer.address)).to.be.revertedWith(
        "not owning item",
      );
    });

    it("Should accept the offer", async () => {
      await mockERC721.connect(minter).setApprovalForAll(marketplace.address, true);
      await marketplace.connect(minter).acceptOffer(mockERC721.address, firstTokenId, buyer.address);
    });

    it("Should revert if the offer not exist or expired", async () => {
      // offer doesn't exist
      await mockERC721.connect(minter).setApprovalForAll(marketplace.address, true);
      await expect(
        marketplace.connect(minter).acceptOffer(mockERC721.address, secondTokenId, buyer.address),
      ).to.be.revertedWith("offer not exists or expired");

      // offer was expired
      await increaseTime(350);
      await expect(
        marketplace.connect(minter).acceptOffer(mockERC721.address, firstTokenId, buyer.address),
      ).to.be.revertedWith("offer not exists or expired");
    });
  });

  describe("updatePlatformFee", () => {
    it("Should revert if the platform fee is equal to / greater than 100_0", async () => {
      const platformFee = 1000;
      await expect(marketplace.updatePlatformFee(platformFee)).to.be.revertedWith("platform fee exceeded");
    });

    it("Should update the platform fee", async () => {
      const oldPlatformFee = await marketplace.platformFee();

      const platformFee = 150;
      await marketplace.updatePlatformFee(platformFee);

      expect(await marketplace.platformFee()).to.equal(platformFee);
    });
  });

  describe("updatePlatformFeeRecipient", () => {
    it("Should revert if the platform fee recipient address is address(0)", async () => {
      const feeRecipient = ZERO_ADDRESS;
      await expect(marketplace.updatePlatformFeeRecipient(feeRecipient)).to.be.revertedWith("unexpected fee recipient");
    });

    it("Should update the platform fee recipient address", async () => {
      const feeRecipient = await marketplace.feeRecipient();

      await marketplace.updatePlatformFeeRecipient(buyer.address);

      expect(await marketplace.feeRecipient()).to.equal(buyer.address);
    });
  });

  describe("pause/unpause", () => {
    it("Should pause Oparcade", async () => {
      await marketplace.pause();

      expect(await marketplace.paused()).to.be.true;
    });
    it("Should unpause(resume) Oparcade", async () => {
      await marketplace.pause();
      expect(await marketplace.paused()).to.be.true;

      await marketplace.unpause();

      expect(await marketplace.paused()).to.be.false;
    });
  });
});
