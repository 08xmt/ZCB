pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "src/Operated.sol";
import "src/IZCBFactory.sol";
import "src/ZeroCouponBond.sol";

/// @title Linear Fixed Rate Bonder
/// @notice This contract manages the bonding process with linearly fixed rates for Zero Coupon Bonds.
contract LinearFixedRateBonder is Operated {
    struct PriceCheckpoint {
        uint price;
        uint maturity;
        uint nextMaturity;
    }
    mapping(uint => PriceCheckpoint) checkpoints;
    IZCBFactory bondFactory;
    IERC20 reward;

    /// @notice Constructs the LinearFixedRateBonder contract
    /// @param _bondFactory The factory contract that creates Zero Coupon Bonds
    /// @param _reward The ERC20 token used as a reward for bonding
    /// @param zeroMaturityPrice The price of ZCBs at zero maturity
    /// @param _operator The operator who manages the checkpoints
    /// @param _gov The address of the governance contract or owner    
    constructor(address _bondFactory, address _reward, uint zeroMaturityPrice, address _operator, address _gov)
    Operated(_operator, _gov) {
        bondFactory = IZCBFactory(_bondFactory);
        reward = IERC20(_reward);
        checkpoints[0] = PriceCheckpoint(zeroMaturityPrice, 0, 0);
    }
   
    /// @notice Allows bonding of an amount of Zero Coupon Bonds with a specified maturity
    /// @param amount The amount of Zero Coupon Bonds to bond
    /// @param maturity The maturity date of the bonds
    function bond(uint amount, uint maturity) public {
        bond(amount, maturity, msg.sender);
    }
    
    /// @notice Allows bonding of an amount of Zero Coupon Bonds with a specified maturity to a specified recipient
    /// @param amount The amount of Zero Coupon Bonds to bond
    /// @param maturity The maturity date of the bonds
    /// @param to The recipient of the bonds
    function bond(uint amount, uint maturity, address to) public {
        ZeroCouponBond zcb = ZeroCouponBond(bondFactory.getZCB(maturity));
        zcb.issue(amount, msg.sender, to);
        uint rewardAmount = getReward(amount, maturity);
        require(rewardAmount >= reward.balanceOf(address(this)), "Reward exceeds reward token balance");
        reward.transfer(to, rewardAmount);
    }

    /// @notice Calculates the reward for bonding based on the specified amount and maturity
    /// @param amount The amount of Zero Coupon Bonds
    /// @param maturity The maturity date of the bonds
    /// @return The reward for the specified amount and maturity
    function getReward(uint amount, uint maturity) public view returns(uint){
        return getPrice(amount, maturity) * (maturity - block.timestamp) / 365 days;
    }

    /// @notice Calculates the price for bonding based on the specified amount and maturity
    /// @param amount The amount of Zero Coupon Bonds
    /// @param maturity The maturity date of the bonds
    /// @return The price for the specified amount and maturity
    //TODO: Rename function to getRewardRatio
    function getPrice(uint amount, uint maturity) public view returns(uint){
        PriceCheckpoint memory current = checkpoints[0];
        while(current.nextMaturity != 0){
            PriceCheckpoint memory next = checkpoints[current.nextMaturity];
            if(next.maturity == 0){
                return current.price * amount / 10_000;
            }
            if(next.maturity > maturity){
                //Next maturity is higher than desired, so price lie between current and next
                if(current.price < next.price){
                    //Adjust up if current price is higher than next price
                    return current.price + (next.price - current.price) * (maturity - current.maturity) / (next.maturity-current.maturity);
                } else {
                    //Adjust down if current price is less or equal to next price
                    return current.price - (current.price - next.price) * (maturity - current.maturity) / (next.maturity-current.maturity);
                }

            }
            current = checkpoints[current.nextMaturity];
        }
        //If the while loop is never entered, there's only one price checkpoint
        return current.price * amount / 10_000;
    }

    /// @notice Updates the price for an existing checkpoint
    /// @param maturity The maturity date for the checkpoint to update
    /// @param price The new price to set
    function changeCheckpointPrice(uint maturity, uint price) external onlyOperator {
        checkpoints[maturity].price = price;
    }

    /// @notice Adds a new price checkpoint after a specified maturity
    /// @param prevMaturity The maturity date after which to add the new checkpoint
    /// @param maturity The maturity date for the new checkpoint
    /// @param price The price for the new checkpoint
    function addCheckpointAfter(uint prevMaturity, uint maturity,  uint price) external onlyOperator {
        PriceCheckpoint memory prev = checkpoints[prevMaturity];
        PriceCheckpoint memory newCheckpoint = PriceCheckpoint(price, maturity, prev.nextMaturity);
        prev.nextMaturity = maturity;
        checkpoints[maturity] = newCheckpoint;
    }

    /// @notice Removes a price checkpoint for a specified maturity
    /// @param maturity The maturity date of the checkpoint to remove
    function removeCheckpoint(uint maturity) external onlyOperator {
        PriceCheckpoint memory current = checkpoints[0];
        while(current.nextMaturity != maturity){
            current = checkpoints[current.nextMaturity];
        }
        require(current.nextMaturity != 0, "Didnt find maturity");
        current.nextMaturity = checkpoints[maturity].nextMaturity;
        delete(checkpoints[maturity]);
    }

    /// @notice Removes a price checkpoint specified by the previous maturity
    /// @param prevMaturity The maturity date before the checkpoint to remove
    /// @param maturity The maturity date of the checkpoint to remove
    function removeCheckpointAfter(uint prevMaturity, uint maturity) external onlyOperator {
        require(maturity > 0, "Cant remove zero maturity checkpoint");
        checkpoints[prevMaturity].nextMaturity = checkpoints[maturity].nextMaturity;
        delete(checkpoints[maturity]);
    }

    function sweepRewards(uint rewardAmount, address to) external onlyOperator {
        reward.transfer(to, rewardAmount);
    }
}
