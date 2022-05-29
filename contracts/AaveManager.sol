//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./Withdrawable.sol";

contract AaveManager is Ownable, Withdrawble {
    LendingPoolAddressesProvider private addressProvider;

    constructor(address _lendingPoolAddressesProvider) {
        addressProvider = LendingPoolAddressesProvider(
            _lendingPoolAddressesProvider
        );
    }

    function repay(
        IERC20 token,
        uint256 amount,
        address mainAccount
    ) external onlyOwner {
        bool succ = token.approve(address(getPool()), amount);
        require(succ, "Approve failed");

        getPool().repay(address(token), amount, 2, mainAccount);
    }

    function borrow(
        IERC20 token,
        uint256 amount,
        address curveManager,
        address mainAccount
    ) external onlyOwner {
        getPool().borrow(address(token), amount, 2, 0, mainAccount);

        bool succ = token.transfer(curveManager, amount);
        require(succ, "Transfer failed");
    }

    function getPool() private returns (AavePool) {
        return AavePool(addressProvider.getLendingPool());
    }
}

contract LendingPoolAddressesProvider {
    function getLendingPool() external returns (address) {}
}

contract AavePool {
    function repay(
        address,
        uint256,
        uint256,
        address
    ) external returns (uint256) {}

    function borrow(
        address,
        uint256,
        uint256,
        uint16,
        address
    ) external {}
}
