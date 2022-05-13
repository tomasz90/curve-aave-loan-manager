//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./OwnableByWorker.sol";
import "./Withdrawable.sol";
import "./CurveManager.sol";
import "./AaveManager.sol";

contract LoanManager is OwnableByWorker, Withdrawble {

    CurveManager private curveManager;
    AaveManager private aaveManager;

    event CreationAddtionalContracts(string name, address _address);

    constructor(
        address _lendingPoolAddressesProvider,
        address _crvPool,
        address _am3CrvDeposit,
        address _am3CRV,
        address _dai,
        address _usdc,
        address _usdt
    ) {

        aaveManager = new AaveManager(_lendingPoolAddressesProvider);

        curveManager = new CurveManager(
            _crvPool,
            _am3CrvDeposit,
            _am3CRV,
            _dai,
            _usdc,
            _usdt
        );


        emit CreationAddtionalContracts("aaveManager", address(aaveManager));
        emit CreationAddtionalContracts("curveManager", address(curveManager));
    }

    function borrowAndStake(IERC20 token, uint256 amount) external onlyWorker {
        // delegation alowance should be done not here but on aaveManager address
        aaveManager.borrow(token, amount, address(curveManager), owner());
        curveManager.depositAndStake(token, amount, owner());
    }

    function unstakeAndRepay(IERC20 token, uint256 amount) external onlyWorker {
        // alowance should be done not here but on curveManager address
        uint256 withdrawAmount = curveManager.unstakeAndWithdraw(
            token,
            amount,
            address(aaveManager),
            owner()
        );
        aaveManager.repay(token, withdrawAmount, owner());
    }

    function withdrawFromAave(IERC20 token, uint256 amount) external onlyOwner {
        aaveManager.withdraw(token);
    }

    function withdrawFromCurve(IERC20 token, uint256 amount)
        external
        onlyOwner
    {
        curveManager.withdraw(token);
    }
}
