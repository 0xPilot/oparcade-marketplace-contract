const { config: dotenvConfig } = require("dotenv");
const path = require("path");

dotenvConfig({ path: path.resolve(__dirname, "../.env") });

const deployOPGamesAuction = async (hre) => {
  const { deploy } = hre.deployments;
  const { deployer } = await hre.getNamedAccounts();

  // get contracts
  const addressRegistry = await hre.deployments.get('AddressRegistry');

  await deploy("OPGamesAuction", {
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
module.exports = deployOPGamesAuction;
deployOPGamesAuction.tags = ["OPGamesAuction"];
