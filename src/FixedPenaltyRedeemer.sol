pragma solidity ^0.8.20;

import "src/ZeroCouponBond.sol";
import "src/Governable.sol";

contract FixedPenaltyRedeemer is Governable {
    
    address public treasury;
    uint256 public dailyROI;
    uint256 constant SCALE = 1e18; // scale for fixed-point numbers (18 decimal places)
    constructor(
        uint _dailyROI,
        address _treasury,
        address _gov
    ) Governable(_gov) {
        treasury = _treasury;
        dailyROI = _dailyROI;
    }

    function pow(uint256 base, uint256 exponent) internal pure returns (uint256) {
        uint256 result = SCALE;
        base = base * SCALE;

        while (exponent != 0) {
            if (exponent % 2 != 0) {
                result = result * base / SCALE;
            }
            exponent /= 2;
            base = base * base / SCALE;
        }

        return result;
    }

    function calculateCompoundInterest(uint256 principal,  uint256 _days) public view returns (uint256) {
        uint256 dailyRoiScaled = dailyROI + SCALE; // Adjust dailyRoi to account for scaling
        uint256 compoundFactor = pow(dailyRoiScaled, _days);
        return principal * compoundFactor / SCALE;
    }

    function getRedemptionValue(uint amount, uint maturity) public view returns(uint) {
        return amount - getPenalty(amount, maturity);
    }

    function getPenalty(uint amount, uint maturity) public view returns(uint) {
        if(maturity <= block.timestamp) return 0;
        uint daysUntilExpiry = (maturity - block.timestamp) / 1 days + 1;
        uint interest = calculateCompoundInterest(amount, daysUntilExpiry);
        require(interest <= amount * 2, "Can't pay more than 100% in penalty");
        return interest - amount;
    }

    function redeem(address bond, uint amount) external {
        redeem(bond, amount, msg.sender);
    }

    function redeem(address bond, uint amount, address to) public {
        ZeroCouponBond zcb = ZeroCouponBond(bond);
        uint payout = getRedemptionValue(amount, zcb.maturity());
        uint penalty = amount - payout;
        ZeroCouponBond(bond).redeemFrom(payout, msg.sender, to);
        ZeroCouponBond(bond).redeemFrom(penalty, msg.sender, treasury);
    }

    function setDailyROI(uint newDailyRoi) external onlyGov {
        require(newDailyRoi < SCALE);
        dailyROI = newDailyRoi;
    }

    function setTreasury(address newTreasury) public onlyGov {
        treasury = newTreasury;
    }
}
