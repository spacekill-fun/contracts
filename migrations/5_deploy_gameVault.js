const GameVault = artifacts.require("GameVault");

module.exports = async function (deployer) {
  await deployer.deploy(GameVault);
  console.log("GameVault deployed: ", GameVault.address)
};