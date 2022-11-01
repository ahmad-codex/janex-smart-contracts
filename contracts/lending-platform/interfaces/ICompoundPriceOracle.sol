pragma solidity ^0.8.0;

interface ICompoundPriceOracle {
    function getUnderlyingPrice(address cToken) external view returns (uint);
}