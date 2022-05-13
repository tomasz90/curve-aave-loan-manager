//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
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