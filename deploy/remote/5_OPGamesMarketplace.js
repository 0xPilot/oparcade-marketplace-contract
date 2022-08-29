const { config: dotenvConfig } = require("dotenv");
const path = require("path");

dotenvConfig({ path: path.resolve(__dirname, "../.env") });

const deployOPGamesMarketplace = async (hre) => {
  const { deploy } = hre.deployments;
  const { deployer } = await hre.getNamedAccounts();

  // get contracts
  const addressRegistry = await hre.deployments.get('AddressRegistry');

  await deploy("OPGamesMarketplace", {
    from: deployer,
    args: [],
    log: true,
    proxy: {
      proxyContract: "OpenZeppelinTransparentProxy",
      viaAdminContract: "DefaultProxyAdmin",
      execute: {
        init: {
          methodName: "initialize",
          args: [addressRegistry.address, process.env.FEE_RECIPIENT_ADDRESS, process.env.PLATFORM_FEE],
        },
      },
    },
  });
};
module.exports = deployOPGamesMarketplace;
deployOPGamesMarketplace.tags = ["OPGamesMarketplace"];
