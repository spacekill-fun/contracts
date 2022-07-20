const GameToken = artifacts.require("GameToken");

module.exports = function (deployer) {
  deployer.deploy(GameToken, "Space Kill King", "SKS");
};
