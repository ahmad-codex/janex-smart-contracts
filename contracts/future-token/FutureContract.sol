pragma solidity ^0.8.0;

import "./interfaces/IFutureContract.sol";
import "../common/interfaces/IERC20.sol";
import "../common/Ownable.sol";

contract FutureContract is IFutureContract, Ownable {
    
    address public override token0;
    address public override token1;
    uint256 public override expiryDate;
    
    constructor(address _token0, address _token1, uint _expiryDate, address approval) {
        require(_expiryDate > block.timestamp, "Future Contract: EXPIRY_DATE_BEFORE_NOW");
        (token0, token1) = (_token0, _token1);
        expiryDate = _expiryDate;
        IERC20(token0).approve(approval, type(uint256).max);
        IERC20(token1).approve(approval, type(uint256).max);
    }
}