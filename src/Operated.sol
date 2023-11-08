pragma solidity ^0.8.20;

import "src/Governable.sol";

abstract contract Operated is Governable {

    address public operator;

    constructor(address _operator, address _gov) Governable(_gov){
        operator = _operator;
    }

    error OnlyOperator();

    modifier onlyOperator() {
        if(msg.sender != gov) revert OnlyGov();
        _;
    }

    function setOperator(address newOperator) external onlyGov {
        operator = newOperator;
    }
}
