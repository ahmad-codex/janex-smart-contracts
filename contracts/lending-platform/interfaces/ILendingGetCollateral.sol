pragma solidity ^0.8.0;

interface ILendingGetCollateral {
    function getLendingPlatformCollateral(uint platformIndex, address borrowToken)
        external view
        returns (uint collateralAmount, uint withdrawableAmount);

    function getLendingPlatformBorrow(uint platformIndex, address borrowToken)
        external view
        returns (uint borrowedAmount);
}
