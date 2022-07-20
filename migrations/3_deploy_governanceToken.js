const GovernanceToken = artifacts.require("GovernanceToken");

module.exports = function (deployer) {
  deployer.deploy(GovernanceToken, " Space Kill King", "SKK", "1000000000000000000000000000");
};