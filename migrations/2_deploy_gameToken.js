const GameToken = artifacts.require("GameToken");

module.exports = function (deployer) {
  deployer.deploy(GameToken, "Among US Game Token", "AUGT");
};
