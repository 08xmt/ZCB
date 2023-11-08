pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/IZCBFactory.sol";
import "src/ZeroCouponBond.sol";
import "src/Governable.sol";

/// @title ZCBFactory Contract
/// @notice Factory for creating Zero Coupon Bond (ZCB) tokens
contract ZCBFactory is IZCBFactory, Governable {
    
    mapping(address => bool) public isIssuer;
    mapping(address => bool) public isRedeemer;
    mapping(uint => address) public bonds;
    IERC20 public immutable underlying;
    uint public maxLifetime;
    uint public resolution;
    uint public offset;

    /// @notice Constructs the ZCBFactory contract
    /// @param _underlying The ERC20 token to be used as the underlying asset for ZCBs
    /// @param _maxLifetime The maximum lifetime in seconds for a ZCB
    /// @param _resolution The resolution in seconds for rounding maturities
    /// @param _offset The offset in seconds added after rounding maturities
    /// @param _gov The initial governor address for the Governable contract
    constructor(
        IERC20 _underlying,
        uint _maxLifetime,
        uint _resolution,
        uint _offset,
        address _gov
    ) Governable(_gov) {
        require(_resolution > 0, "Cant divide by 0");
        require(_maxLifetime > 0, "Lifetime 0");
        underlying  = _underlying;
        maxLifetime = _maxLifetime;
        resolution = _resolution;
        offset = _offset;
    }

    /// @notice Creates a new ZCB with a given maturity date
    /// @dev Maturity is rounded to the nearest resolution and must not exceed maxLifetime
    /// @param maturity The future timestamp at which the ZCB will mature
    /// @return The address of the newly created ZCB token contract
    function createZCB(uint maturity) public returns(address){
        require(isIssuer[msg.sender], "Only issuer can create ZCB");
        
        maturity = roundToResolution(maturity);
        require(maturity - block.timestamp <= maxLifetime, "Max lifetime exceeded");

        require(bonds[maturity] == address(0), "Already created");
        //TODO: Use minimal proxies/clones for major gas savings
        ZeroCouponBond bond = new ZeroCouponBond();
        bond.init(maturity, underlying);
        return address(bond);
    }

    /// @notice Retrieves the address of a ZCB for a given maturity, creating one if it does not exist
    /// @param maturity The future timestamp at which the ZCB will mature
    /// @return The address of the ZCB token contract
    function getZCB(uint maturity) external returns(address){
        //Create bond for maturity if it doesn't exist, otherwise return bond
        maturity = roundToResolution(maturity);
        return bonds[maturity] == address(0) ? createZCB(maturity) : bonds[maturity];
    }

    /// @notice Sets a new time resolution for rounding maturities
    /// @param newResolution The new resolution in seconds
    function setResolution(uint newResolution) external onlyGov {
        require(newResolution > offset, "Resolution must be higher than offset");
        require(newResolution > 0, "Cant divide by 0");
        resolution = newResolution;
    }

    /// @notice Sets a new offset to be added after rounding maturities
    /// @param newOffset The new offset in seconds
    function setOffset(uint newOffset) external onlyGov {
        require(newOffset < resolution, "Offset must be lower than resolution");
        offset= newOffset;
    }

    /// @notice Sets the maximum lifetime for a ZCB
    /// @param newMaxLifetime The new maximum lifetime in seconds
    function setMaxLifetime(uint newMaxLifetime) external onlyGov {
        require(newMaxLifetime > 0, "Max lifetime 0");
        maxLifetime = newMaxLifetime;
    }

    /// @notice Authorizes or deauthorizes an address as an issuer of ZCBs
    /// @param issuer The address in question
    /// @param canIssue Whether the address is authorized to issue ZCBs
    function setIssuer(address issuer, bool canIssue) external onlyGov {
        isIssuer[issuer] = canIssue;
    }
    /// @notice Authorizes or deauthorizes an address as a pre-mature redeemer of ZCBs
    /// @param redeemer The address in question
    /// @param canRedeem Whether the address is authorized to pre-mature redemption of ZCBs
    function setRedeemer(address redeemer, bool canRedeem) external onlyGov {
        isRedeemer[redeemer] = canRedeem;
    }

    function roundToResolution(uint maturity) public view returns(uint){
        //Round down to nearest RESOLUTION and add OFFSET
        //Ex: Round down to nearest day and add 6 hours
        return maturity - maturity % resolution + offset;   
    }
}
