//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

abstract contract OwnableByContract {

    address private immutable _contract;

    constructor() {
        _contract = msg.sender;
    }

    function contractOwner() public view returns(address) {
        return _contract;
    }

    modifier onlyContract() {
        require(msg.sender == _contract, "Caller is not the main contract");
        _;
    }
}

abstract contract OwnableByWorker is Ownable {

    address private _worker;

    event WorkOwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        setWorker(tx.origin);
        transferOwnership(tx.origin);
    }
    
    modifier onlyWorker() {
        // worker is deployer
        require(worker() == tx.origin, "OwnableByWorker: caller is not the owner");
        _;
    }

    function worker() public view returns(address) {
        return _worker;
    }

    function setWorker(address newWorker) public onlyOwner {
        address oldWorker = _worker;
        _worker = newWorker;
        emit WorkOwnershipTransferred(oldWorker, newWorker);
   }
}

abstract contract Withdrawble is Ownable {

    // for safety reason, if founds somehow stuck
    function withdraw(IERC20 token, uint256 amount) external onlyOwner {
        token.transfer(msg.sender, amount); // tx.origin?? to test!!!
    }
}

contract LoanManager is OwnableByWorker, Withdrawble {

    IAddressStorage private _address = new AddressProvider().getAddressStorage();
    CurveManager private curveManager = new CurveManager(_address);
    AaveManager private aaveManager = new AaveManager(_address);

    event CreationAddtionalContracts(string name, address _address);

    constructor() {
        emit CreationAddtionalContracts("curveManager", address(curveManager));
        emit CreationAddtionalContracts("aaveManager", address(aaveManager));
    }

    function borrowAndStake(IERC20 token, uint256 amount) external onlyWorker {
        // delegation alowance should be done not here but on aaveManager address
        aaveManager.borrow(token, amount, address(curveManager), owner());
        curveManager.depositAndStake(token, amount, owner());
    }

    function unstakeAndRepay(IERC20 token, uint256 amount) external onlyWorker {
        // alowance should be done not here but on curveManager address
        uint256 withdrawAmount = curveManager.unstakeAndWithdraw(token, amount, address(aaveManager), owner());
        aaveManager.repay(token, withdrawAmount, owner());
    }

    function withdrawFromAave(IERC20 token, uint256 amount) external onlyOwner {
        aaveManager.withdraw(token, amount);
    }

    function withdrawFromCurve(IERC20 token, uint256 amount) external onlyOwner {
        curveManager.withdraw(token, amount);
    }
}

contract CurveManager is OwnableByContract, Withdrawble {

    address private crvPoolAddress;
    address private am3CrvDeposit;

    address private immutable dai;
    address private immutable usdc;
    address private immutable usdt;

    CurvePool private immutable pool;
    Am3CurveDeposit private immutable depositPool;

    IERC20 private immutable depositToken;
    IERC20 private immutable am3CRV;

    constructor(IAddressStorage addressStorage) {
        crvPoolAddress = addressStorage.CRV_POOL_ADDRESS();
        am3CrvDeposit = addressStorage.am3CRV_DEPOSIT();

        dai = addressStorage.DAI();
        usdc = addressStorage.USDC();
        usdt = addressStorage.USDT();

        pool = CurvePool(crvPoolAddress);
        depositPool = Am3CurveDeposit(am3CrvDeposit);

        depositToken = IERC20(am3CrvDeposit);
        am3CRV = IERC20(addressStorage.am3CRV());
    }

    event AddLiquidity(address tokenAddress, uint256[3] amounts);
    event Deposit(address tokenAddress, uint256 amount);
    event Withdraw(address tokenAddress, uint256 amount);
    event RemoveLiquidity(address tokenAddress, uint256 amount);

    function depositAndStake(IERC20 token, uint256 amount, address mainAccount) external onlyContract {

        uint256[3] memory amounts = [uint256(0), uint256(0), uint256(0)];
        uint128 index = getTokenIndex(token);
        amounts[index] = amount;

        uint256 minMintAmount = 1;
        bool useUnderlying = true;

        bool succ = token.approve(crvPoolAddress, amount);
        require(succ, "Approve failed");

        uint256 am3CRVbalance = pool.add_liquidity(amounts, minMintAmount, useUnderlying); // revert
        emit AddLiquidity(crvPoolAddress, amounts);

        succ = am3CRV.approve(am3CrvDeposit, am3CRVbalance);
        require(succ, "Approve failed");

        depositPool.deposit(am3CRVbalance);
        emit Deposit(am3CrvDeposit, am3CRVbalance);

        uint256 depositBalance = depositToken.balanceOf(address(this));
        succ = depositToken.transfer(mainAccount, depositBalance);
        require(succ, "Transfer failed");
    }

    function unstakeAndWithdraw(IERC20 token, uint256 amount, address aaveManager, address mainAccount) external onlyContract returns(uint256) {

        uint256 virtualPrice = pool.get_virtual_price();
        amount = amount * (1 ether) / virtualPrice;

        bool succ = depositToken.transferFrom(mainAccount, address(this), amount);
        require(succ, "Transfer from failed");

        depositPool.withdraw(amount);
        emit Withdraw(am3CrvDeposit, amount);

        int128 index = int128(getTokenIndex(token));

        uint256 withdrawAmount = pool.remove_liquidity_one_coin(amount, index, 1, true);
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

contract AaveManager is OwnableByContract, Withdrawble {

    LendingPoolAddressesProvider private addressProvider;

    constructor(IAddressStorage addressStorage) {
        addressProvider 
            = LendingPoolAddressesProvider(addressStorage.LENDING_POOL_ADDRESS_PROVIDER());
    }

    function repay(IERC20 token, uint256 amount, address mainAccount) external onlyContract {

        bool succ = token.approve(address(getPool()), amount);
        require(succ, "Approve failed");

        getPool().repay(address(token), amount, 2, mainAccount);
    }

    function borrow(IERC20 token,  uint256 amount, address curveManager, address mainAccount) external onlyContract {

        getPool().borrow(address(token), amount, 2, 0, mainAccount);

        bool succ = token.transfer(curveManager, amount);
        require(succ, "Transfer failed");
    }

    function getPool() private returns(AavePool) {
        return AavePool(addressProvider.getLendingPool());
    }
}

contract AddressProvider is OwnableByContract {

    function getAddressStorage() external onlyContract returns(IAddressStorage) {
        uint chainId = block.chainid;
        if(chainId == 137) {
            return new MaticAddressStorage();
        } else if (chainId == 43114) {
            return new AvaxAddressStorage();
        } else if (chainId != 43114 && chainId != 137) {
            return new DevelopAddressStorage();
        } else {
            revert();
        }
    }
}

interface IAddressStorage {

    function CRV_POOL_ADDRESS() external view returns(address);
    function am3CRV_DEPOSIT() external view returns(address);

    function am3CRV() external view returns(address);

    function DAI() external view returns(address);
    function USDC() external view returns(address);
    function USDT() external view returns(address);

    function LENDING_POOL_ADDRESS_PROVIDER() external view returns(address);

}

contract MaticAddressStorage is IAddressStorage {

    address public override constant CRV_POOL_ADDRESS = 0x445FE580eF8d70FF569aB36e80c647af338db351;
    address public override constant am3CRV_DEPOSIT = 0x19793B454D3AfC7b454F206Ffe95aDE26cA6912c;

    address public override constant am3CRV = 0xE7a24EF0C5e95Ffb0f6684b813A78F2a3AD7D171;

    address public override constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address public override constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address public override constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;

    address public override constant LENDING_POOL_ADDRESS_PROVIDER = 0xd05e3E715d945B59290df0ae8eF85c1BdB684744;

}

contract AvaxAddressStorage is IAddressStorage {

    address public override constant CRV_POOL_ADDRESS = 0x7f90122BF0700F9E7e1F688fe926940E8839F353;
    address public override constant am3CRV_DEPOSIT = 0x5B5CFE992AdAC0C9D48E05854B2d91C73a003858;

    address public override constant am3CRV = 0x1337BedC9D22ecbe766dF105c9623922A27963EC;

    address public override constant DAI = 0xd586E7F844cEa2F87f50152665BCbc2C279D8d70;
    address public override constant USDC = 0xA7D7079b0FEaD91F3e65f86E8915Cb59c1a4C664;
    address public override constant USDT = 0xc7198437980c041c805A1EDcbA50c1Ce5db95118;

    address public override constant LENDING_POOL_ADDRESS_PROVIDER = 0xb6A86025F0FE1862B372cb0ca18CE3EDe02A318f;

}

contract DevelopAddressStorage is IAddressStorage {

    //TBD
    address public override constant CRV_POOL_ADDRESS = 0x0000000000000000000000000000000000000000;
    address public override constant am3CRV_DEPOSIT = 0x0000000000000000000000000000000000000001;

    address public override constant am3CRV = 0x0000000000000000000000000000000000000002;

    address public override constant DAI = 0x0000000000000000000000000000000000000003;
    address public override constant USDC = 0x0000000000000000000000000000000000000004;
    address public override constant USDT = 0x0000000000000000000000000000000000000005;

    address public override constant LENDING_POOL_ADDRESS_PROVIDER = 0x0000000000000000000000000000000000000006;

}

contract Am3CurveDeposit {

    function deposit(uint256) public {}

    function withdraw(uint256) public {}

}

contract CurvePool {

    function add_liquidity(uint256[3] memory,uint256, bool) public returns(uint256) {}

    function remove_liquidity_one_coin(uint256,int128,uint256,bool) public returns(uint256) {}

    function get_virtual_price() external view returns(uint256) {}

}

contract AavePool {

function repay(address, uint256, uint256, address) external  returns (uint256) {}

function borrow(address, uint256, uint256, uint16, address) external {}

}

contract LendingPoolAddressesProvider {

    function getLendingPool() external returns (address) {}
    
}
