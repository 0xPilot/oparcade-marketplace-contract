const deployERC721Factory = async (hre) => {
  const { deploy } = hre.deployments;
  const { deployer } = await hre.getNamedAccounts();

  await deploy("ERC721Factory", {
    from: deployer,
    args: [],
    log: true,
  });
};
module.exports = deployERC721Factory;
deployERC721Factory.tags = ["ERC721Factory"];