const GameVault = artifacts.require("GameVault");

module.exports = async function (deployer) {
  await deployer.deploy(GameVault);
  console.log("GameVault deployed: ", GameVault.address)

  const withdrawAdmin = "0x550bB66C3050C2e9C5DC2b35aa924485b48B67d0";
  const gameVaultInstance = await GameVault.deployed();
  await gameVaultInstance.enableAdmin(withdrawAdmin);

  console.log(`${withdrawAdmin} is addded as withdraw admin`);
};