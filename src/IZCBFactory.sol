pragma solidity ^0.8.20;

interface IZCBFactory {
    function isIssuer(address) external returns(bool);
    function isRedeemer(address) external returns(bool);
    function getZCB(uint maturity) external returns(address);
}
