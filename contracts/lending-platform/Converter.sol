pragma solidity ^0.8.0;

import "../common/interfaces/IERC20.sol";

contract Converter {
    
    function convert(address tokenIn, uint amount, address tokenOut) external {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amount);
        IERC20(tokenOut).transfer(msg.sender, amount);
    }
}