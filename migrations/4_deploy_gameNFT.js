const GameNFT = artifacts.require("GameNFT");

module.exports = async function (deployer) {
  await deployer.deploy(GameNFT, "Space Kill NFT", "SKNFT");
  console.log("GameNFT deployed: ", GameNFT.address);
  const mintAdmin = "0x550bB66C3050C2e9C5DC2b35aa924485b48B67d0";
  const nftInstance = await GameNFT.deployed();
  await nftInstance.enableAdmin(mintAdmin);
  console.log(`${mintAdmin} is added as mint admin`)
};