//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
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