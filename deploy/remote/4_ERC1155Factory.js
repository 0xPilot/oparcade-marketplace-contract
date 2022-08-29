const deployERC1155Factory = async (hre) => {
  const { deploy } = hre.deployments;
  const { deployer } = await hre.getNamedAccounts();

  await deploy("ERC1155Factory", {
    from: deployer,
    args: [],
    log: true,
  });
};
module.exports = deployERC1155Factory;
deployERC1155Factory.tags = ["ERC1155Factory"];