//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Withdrawable.sol";

contract CurveManager is Ownable, Withdrawble {
    address private crvPoolAddress;
    address private am3CrvDeposit;

    address private immutable dai;
    address private immutable usdc;
    address private immutable usdt;

    CurvePool private immutable pool;
    Am3CurveDeposit private immutable depositPool;

    IERC20 private immutable depositToken;
    IERC20 private immutable am3CRV;

    constructor(
        address _crvPool,
        address _am3CrvDeposit,
        address _am3CRV,
        address _dai,
        address _usdc,
        address _usdt
    ) {
        
        pool = CurvePool(_crvPool);
        depositPool = Am3CurveDeposit(_am3CrvDeposit);

        depositToken = IERC20(_am3CrvDeposit);
        am3CRV = IERC20(_am3CRV);

        dai = _dai;
        usdc = _usdc;
        usdt = _usdt;
    }

    event AddLiquidity(address tokenAddress, uint256[3] amounts);
    event Deposit(address tokenAddress, uint256 amount);
    event Withdraw(address tokenAddress, uint256 amount);
    event RemoveLiquidity(address tokenAddress, uint256 amount);

    function depositAndStake(
        IERC20 token,
        uint256 amount,
        address mainAccount
    ) external onlyOwner {
        uint256[3] memory amounts = [uint256(0), uint256(0), uint256(0)];
        uint128 index = getTokenIndex(token);
        amounts[index] = amount;

        uint256 minMintAmount = 1;
        bool useUnderlying = true;

        bool succ = token.approve(crvPoolAddress, amount);
        require(succ, "Approve failed");

        uint256 am3CRVbalance = pool.add_liquidity(
            amounts,
            minMintAmount,
            useUnderlying
        ); // revert
        emit AddLiquidity(crvPoolAddress, amounts);

        succ = am3CRV.approve(am3CrvDeposit, am3CRVbalance);
        require(succ, "Approve failed");

        depositPool.deposit(am3CRVbalance);
        emit Deposit(am3CrvDeposit, am3CRVbalance);

        uint256 depositBalance = depositToken.balanceOf(address(this));
        succ = depositToken.transfer(mainAccount, depositBalance);
        require(succ, "Transfer failed");
    }

    function unstakeAndWithdraw(
        IERC20 token,
        uint256 amount,
        address aaveManager,
        address mainAccount
    ) external onlyOwner returns (uint256) {
        uint256 virtualPrice = pool.get_virtual_price();
        amount = (amount * (1 ether)) / virtualPrice;

        bool succ = depositToken.transferFrom(
            mainAccount,
            address(this),
            amount
        );
        require(succ, "Transfer from failed");

        depositPool.withdraw(amount);
        emit Withdraw(am3CrvDeposit, amount);

        int128 index = int128(getTokenIndex(token));

        uint256 withdrawAmount = pool.remove_liquidity_one_coin(
            amount,
            index,
            1,
            true
        );
        emit RemoveLiquidity(crvPoolAddress, amount);

        succ = token.transfer(aaveManager, withdrawAmount);
        require(succ, "Transfer failed");

        return withdrawAmount;
    }

    function getTokenIndex(IERC20 token) private view returns (uint128) {
        address tokenAddress = address(token);
        if (tokenAddress == dai) {
            return 0;
        } else if (tokenAddress == usdc) {
            return 1;
        } else if (tokenAddress == usdt) {
            return 2;
        } else {
            revert("Invalid token address");
        }
    }
}

contract CurvePool {
    function add_liquidity(
        uint256[3] memory,
        uint256,
        bool
    ) public returns (uint256) {}

    function remove_liquidity_one_coin(
        uint256,
        int128,
        uint256,
        bool
    ) public returns (uint256) {}

    function get_virtual_price() external view returns (uint256) {}
}

contract Am3CurveDeposit {
    function deposit(uint256) public {}

    function withdraw(uint256) public {}
}
