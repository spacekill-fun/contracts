const GovernanceToken = artifacts.require("GovernanceToken");

module.exports = function (deployer) {
  deployer.deploy(GovernanceToken, "Among US Governance Token", "AMGT", "1000000000000000000000000000");
};