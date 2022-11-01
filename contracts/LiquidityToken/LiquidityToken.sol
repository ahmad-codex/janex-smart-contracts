pragma solidity ^0.8.0;
import "../common/ERC20.sol";
import "./interfaces/ILiquidityToken.sol";

contract LiquidityToken is ILiquidityToken, ERC20 {
    constructor() ERC20("Liquidity Token", "LQT", 18){
    }
    
    function mint(address to, uint256 amount) external override{
        _mint(to, amount);
    }

    function burn(uint256 amount) external override{
        _burn(msg.sender, amount);
    }
}

