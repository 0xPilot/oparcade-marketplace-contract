const settings = async (hre) => {
  // get contracts
  const addressRegistry = await ethers.getContract('AddressRegistry');
  const tokenRegistry = await ethers.getContract('TokenRegistry');
  const opGamesMarketplace = await ethers.getContract('OPGamesMarketplace');
  const opGamesAuction = await ethers.getContract('OPGamesAuction');

  // register TokenRegistry contract address
  await addressRegistry.updateTokenRegistry(tokenRegistry.address);

  // register OPGamesMarketplace contract address
  await addressRegistry.updateMarketplace(opGamesMarketplace.address);

  // register OPGamesAuction contract address
  await addressRegistry.updateAuction(opGamesAuction.address);
};
module.exports = settings;
settings.tags = ["Settings"];
settings.dependencies = ["AddressRegistry", "TokenRegistry", "OPGamesMarketplace", "OPGamesAuction"];
