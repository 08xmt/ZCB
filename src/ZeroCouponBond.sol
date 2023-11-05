pragma solidity ^0.8.20;
import "src/IZCBFactory.sol";

contract ZeroCouponBond is Mintable {
    
    IZCBFactory public factory;
    IERC20 public underlying;
    uint public maturity;
    mapping(address => bool) public redeemer;
    mapping(address => bool) public issuer;

    event Issue(uint amount, address indexed from, address indexed to);
    event Redeem(uint amount, address indexed from, address indexed to);

    function init(uint _maturity, IERC20 _underlying){
        require(address(factory) == address(0), "Already initialized");
        require(maturity > block.timestamp, "Maturity must be in future");
        factory = IFactory(msg.sender);
        maturity = _maturity;
        underlying = _underlying;
    }

    function issue(uint amount, address from,  address to) public {
        require(factory.isIssuer(msg.sender), "Non-issuer cant issue");
        underlying.transferFrom(from, address(this), amount);
        _mint(to, amount);
        emit Issue(amount, from, to);
    }

    function _redeem(uint amount, address from, address to) internal {
        require(balanceOf(from) >= amount, "Cant redeem more than owned");
        if(!factory.isRedeemer(msg.sender))
            require(block.timestamp >= maturity, "Cant redeem before maturity");
        _burn(from, amount);
        underlying.transfer(to, amount);
        emit Redeem(amount, msg.sender, to);
    }
    
    function redeem(uint amount) external {
        _redeem(amount, msg.sender, msg.sender);
    }

    function redeem(uint amount, address to) external {
        _redeem(amount, msg.sender, to);
    }

    function redeemFrom(uint amount, address from, address to) external {
        approve[from][msg.sender] -= amount;
        _redeem(amount, from, to);
    }

    function setIssuer(address issuer, bool canIssue) external onlyGov {
        issuers[issuer] = canIssue;
    }

    function setRedeemer(address redeemer, bool canPrematureRedeem) external onlyGov {
        redeemers[redeemer] = canPrematureRedeem;
    }

}
