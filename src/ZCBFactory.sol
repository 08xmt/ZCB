pragma solidity ^0.8.20;

import "src/IZCBFactory.sol";
import "src/ZeroCouponBond.sol";

contract ZCBFactory is IZCBFactory, Governable {
    
    mapping(address => bool) public isIssuer;
    mapping(address => bool) public isRedeemer;
    mapping(uint => address) public bonds;
    IERC20 public immutable underlying;
    uint public maxLifetime;
    uint public resolution;
    uint public offset;

    constructor(
        IERC20 _underlying,
        uint _maxLifetime,
        uint _resolution,
        uint offset
    ){
        require(_resolution > 0, "Cant divide by 0");
        require(_maxLifeTime > 0, "Lifetime 0");
        underlying  = _underlying;
        maxLifetime = _maxLifetime;
        resolution = _resolution;
        offset = _offset;
    }

    function createZCB(uint maturity) external returns(address){
        require(isIssuer(msg.sender), "Only issuer can create ZCB");
        
        maturity = roundToResolution(maturity);
        require(maturity - block.timestamp <= maxLifetime, "Max lifetime exceeded");

        require(bonds[maturity] == address(0), "Already created")
        //TODO: Use minimal proxies/clones for major gas savings
        ZeroCouponBond bond = new ZeroCouponBond(underlying);
        bond.init(maturity);
        
    }

    function getZCB(uint maturity) external {
        //Create bond for maturity if it doesn't exist, otherwise return bond
        maturity = roundToResolution(maturity);
        return bonds[maturity] == address(0) ? createZCB(maturity) : bonds[maturity];
    }

    function setResolution(uint newResolution) external onlyGov {
        require(newResolution > offset, "Resolution must be higher than offset");
        require(newResolution > 0, "Cant divide by 0");
        resolution = newResolution;
    }

    function setOffset(uint newOffset) external onlyGov {
        require(newOffset < resolution, "Offset must be lower than resolution");
        offset= newOffset;
    }

    function setMaxLifetime(uint newMaxLifetime) external onlyGov {
        require(newMaxLifetime > 0, "Max lifetime 0");
        maxLifetime = newMaxLifetime;
    }

    function setIssuer(address issuer, bool canIssue) external onlyGov {
        isIssuer[issuer] = canIssue;
    }

    function setRedeemer(address redeemer, bool canIssue) external onlyGov {
        isRedeemer[redeemer] = canRedeem;
    }

    function roundToResolution(uint maturity) external view returns(uint){
        //Round down to nearest RESOLUTION and add OFFSET
        //Ex: Round down to nearest day and add 6 hours
        return maturity - maturity % resolution + offSet;   
    }
}
