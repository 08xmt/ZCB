pragma solidity ^0.8.20;
import "src/IZCBFactory.sol";
import "src/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title Zero-Coupon Bond Token Contract
/// @notice This contract implements a zero-coupon bond token using ERC20 standards
contract ZeroCouponBond is ERC20 {
    
    IZCBFactory public factory;
    IERC20 public underlying;
    uint public maturity;

    event Issue(uint amount, address indexed from, address indexed to);
    event Redeem(uint amount, address indexed from, address indexed to);

    //TODO: Figure out how to name tokens and token symbol
    //TODO: Override domain separators on init
    /// @notice Initializes the zero-coupon bond contract
    /// @dev Sets the maturity date and the underlying asset for the bond
    /// @param _maturity The timestamp at which the bond will mature
    /// @param _underlying The address of the underlying ERC20 token
    function init(uint _maturity, IERC20 _underlying) external {
        require(address(factory) == address(0), "Already initialized");
        require(maturity > block.timestamp, "Maturity must be in future");
        factory = IZCBFactory(msg.sender);
        maturity = _maturity;
        underlying = _underlying;
    }

    /// @notice Issues a specified amount of zero-coupon bonds to a recipient
    /// @dev Can only be called by an authorized issuer
    /// @param amount The number of bonds to issue
    /// @param from The address from which the underlying tokens are taken
    /// @param to The address to which the bonds are minted
    function issue(uint amount, address from,  address to) public {
        require(factory.isIssuer(msg.sender), "Non-issuer cant issue");
        underlying.transferFrom(from, address(this), amount);
        _mint(to, amount);
        emit Issue(amount, from, to);
    }

    /// @dev Internal function to redeem bonds
    /// @param amount The number of bonds to redeem
    /// @param from The address from which the bonds are burned
    /// @param to The address to which the underlying tokens are sent
    function _redeem(uint amount, address from, address to) internal {
        require(balanceOf[from] >= amount, "Cant redeem more than owned");
        if(!factory.isRedeemer(msg.sender))
            require(block.timestamp >= maturity, "Cant redeem before maturity");
        _burn(from, amount);
        underlying.transfer(to, amount);
        emit Redeem(amount, msg.sender, to);
    }
    
    /// @notice Redeems a specified amount of zero-coupon bonds for the underlying asset
    /// @param amount The number of bonds to redeem
    function redeem(uint amount) external {
        _redeem(amount, msg.sender, msg.sender);
    }

    /// @notice Redeems a specified amount of zero-coupon bonds to a specified recipient for the underlying asset
    /// @param amount The number of bonds to redeem
    /// @param to The address to which the underlying tokens are sent
    function redeem(uint amount, address to) external {
        _redeem(amount, msg.sender, to);
    }

    /// @notice Allows bond holders to redeem bonds on behalf of the owner
    /// @param amount The number of bonds to redeem
    /// @param from The address from which the bonds are redeemed
    /// @param to The address to which the underlying tokens are sent
    function redeemFrom(uint amount, address from, address to) external {
        allowance[from][msg.sender] -= amount;
        _redeem(amount, from, to);
    }
}
