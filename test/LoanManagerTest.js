const {deployContract, deployMockContract} = require("ethereum-waffle");
const {MockProvider} = require("@ethereum-waffle/provider");
const {use, expect} = require("chai");
const {waffleChai} = require("@ethereum-waffle/chai");
const LoanManager = artifacts.require("LoanManager");
const IERC20 = artifacts.require("IERC20");

use(waffleChai);

describe("LoanManager", async function () {
    this.timeout(5000);

    const [owner, notOwner] = new MockProvider().getWallets();
    const amount = 5;
    let token;
    let loanManager;

    const lendingPoolAddressProvider = "0x0000000000000000000000000000000000000000";
    const crvPool = "0x0000000000000000000000000000000000000001";
    const am3CrvDeposit = "0x0000000000000000000000000000000000000002";
    const am3CRV = "0x0000000000000000000000000000000000000003";
    const dai = "0x0000000000000000000000000000000000000004";
    const usdc = "0x0000000000000000000000000000000000000005";
    const usdt = "0x0000000000000000000000000000000000000006";

    beforeEach(async function () {
        this.timeout(5000);
        token = await deployMockContract(owner, IERC20.abi);
        loanManager = await deployContract(owner, LoanManager, [
            lendingPoolAddressProvider,
            crvPool,
            am3CrvDeposit,
            am3CRV,
            dai,
            usdc,
            usdt,
        ]);
    });

    it("should return owner", async () => {
        let returnedOwner = await loanManager.owner();
        await assert.equal(owner.address, returnedOwner, "Creator should be the owner, but it is not");
    });

    it("should return worker as owner when worker wasnt assigned yet", async () => {
        let returnedWorker = await loanManager.worker();
        await assert.equal(owner.address, returnedWorker, "Creator should be the owner, but it is not");
    });

    it("should return worker", async () => {
        await loanManager.setWorker(notOwner.address);
        let returnedWorker = await loanManager.worker();
        await assert.equal(notOwner.address, returnedWorker, "Creator should be the owner, but it is not");
    });

    it("Old owner should not be able to withdraw", async () => {
        await loanManager.transferOwnership(notOwner.address);
        await expect(loanManager.withdraw(token.address)).to.be.revertedWith("Ownable: caller is not the owner");
    });

    it("Owner should be able to withdraw", async function () {
        await token.mock.transfer.returns(true);
        await loanManager.withdraw(token.address);
        await expect("transfer").to.be.calledOnContract(token);
    });

    it("Owner should not able to call borrowAndStake function after assigning worker", async function () {
        await loanManager.setWorker(notOwner.address);
        await expect(loanManager.borrowAndStake(token.address, amount)).to.be.revertedWith(
            "OwnableByWorker: caller is not the owner"
        );
    });

    it("Owner should not able to call unstakeAndRepay function after assigning worker", async function () {
        await loanManager.setWorker(notOwner.address);
        await expect(loanManager.unstakeAndRepay(token.address, amount)).to.be.revertedWith(
            "OwnableByWorker: caller is not the owner"
        );
    });

    it("Owner should able to call withdrawFromAave function", async function () {
        await token.mock.transfer.returns(true);
        await loanManager.withdrawFromAave(token.address);
        await expect("transfer").to.be.calledOnContract(token);
    });

    it("Owner should able to call withdrawFromCurve function", async function () {
        await token.mock.transfer.returns(true);
        await loanManager.withdrawFromCurve(token.address);
        await expect("transfer").to.be.calledOnContract(token);
    });

    it("Worker should not able to call withdrawFromAave function", async function () {
        // we assume that worker is deployer, then he reassingn role to the owner
        let newOwner = notOwner.address;
        await loanManager.transferOwnership(newOwner);
        await expect(loanManager.withdrawFromAave(token.address)).to.be.revertedWith(
            "Ownable: caller is not the owner"
        );
    });

    it("Worker should not able to call withdrawFromCurve function", async function () {
        // we assume that worker is deployer, then he reassingn role to the owner
        let newOwner = notOwner.address;
        await loanManager.transferOwnership(newOwner);
        await expect(loanManager.withdrawFromCurve(token.address)).to.be.revertedWith(
            "Ownable: caller is not the owner"
        );
    });
});
