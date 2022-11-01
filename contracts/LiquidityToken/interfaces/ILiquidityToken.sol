pragma solidity ^0.8.0;
import "../../common/interfaces/IERC20.sol";

interface ILiquidityToken is IERC20{
    
    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;
}