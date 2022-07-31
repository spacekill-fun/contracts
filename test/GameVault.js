const GameVault = artifacts.require("GameVault");
const GameToken = artifacts.require("GameToken");

contract("GameVault", (accounts) => {


    beforeEach(async function () {
        const gameTokenInstance = await GameToken.deployed();
        const gameVaultInstance = await GameVault.deployed();
        gameTokenInstance.mint(gameVaultInstance.address, "100000000000000000000");
    });

    it("should withdraw erc20 token properly", async () => {
        const gameTokenInstance = await GameToken.deployed();
        const gameVaultInstance = await GameVault.deployed();
        const gameTokenBalance = await gameVaultInstance.getTokenBalance(gameTokenInstance.address);
        console.log("gameTokenBalance: ", gameTokenBalance.toString());
        const amountToWithdraw = "10000000000000000000";
        const withdrawToAccount = accounts[1];
        await gameVaultInstance.withdraw(gameTokenInstance.address, withdrawToAccount, amountToWithdraw);
        const balanceAfterWithdraw = await gameTokenInstance.balanceOf(withdrawToAccount);
        assert.equal(amountToWithdraw, balanceAfterWithdraw.toString(), "bad withdraw");
    });
});