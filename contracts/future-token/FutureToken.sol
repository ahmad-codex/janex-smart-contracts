pragma solidity ^0.8.0;

import "./interfaces/IFutureToken.sol";
import "../common/ERC20.sol";

contract FutureToken is IFutureToken, ERC20 {

    constructor() ERC20("FutureToken", "", 18) { }
    
    function initialize(string memory _symbol) external override {
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) external override onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external override onlyOwner {
        _burn(msg.sender, amount);
    }
}
