const GovernanceToken = artifacts.require("GovernanceToken");

module.exports = async function (deployer) {
  await deployer.deploy(GovernanceToken, " Space Kill King", "SKK", "1000000000000000000000000000");
  console.log("GovernanceToken deployed: ", GovernanceToken.address);
};