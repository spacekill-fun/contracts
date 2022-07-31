const GameToken = artifacts.require("GameToken");

module.exports = async function (deployer) {
  await deployer.deploy(GameToken, "Space Kill King", "SKS");
  console.log("GameToken deployed: ", GameToken.address);
};
