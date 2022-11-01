pragma solidity ^0.8.0;

import "./ICompoundPriceOracle.sol";

interface ICompoundComptroller {
    function markets(address) external view returns (bool, uint256, bool);

    function oracle() external view returns (ICompoundPriceOracle);

    function enterMarkets(address[] calldata)
        external
        returns (uint256[] memory);

    function getAccountLiquidity(address)
        external
        view
        returns (uint256, uint256, uint256);
}