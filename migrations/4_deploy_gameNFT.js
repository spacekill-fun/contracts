const GameNFT = artifacts.require("GameNFT");

module.exports = async function (deployer) {
  await deployer.deploy(GameNFT, "Among US NFT", "AUNFT");
  console.log("GameNFT deployed: ", GameNFT.address);
};