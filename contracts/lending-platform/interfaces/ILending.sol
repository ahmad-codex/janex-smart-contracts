pragma solidity ^0.8.0;

interface ILending {
    function sendCollateral(uint platformIndex, address borrowToken, uint256 amount) external;
    function withdrawCollateral(uint platformIndex, address borrowToken, uint256 amount) external;
    function getLendingPlatformCollateral(uint platformIndex, address borrowToken) external returns (uint, uint);
    function getLendingPlatformBorrow(uint platformIndex, address borrowToken) external returns (uint);
    function getLendingPlatforms(uint platformIndex) external view returns (address);
    function lendingPlatformsCount() external view returns (uint);

    function getBorrowableAmount(uint platformIndex, address borrowToken) external view returns (uint);
    function getDebtAmount(
        uint256 platformIndex,
        address borrowToken,
        uint256 borrowAmount,
        uint256 fromTimestamp,
        uint256 toTimestamp,
        uint256 fromBlock,
        uint256 toBlock
    ) external view returns(uint);

    function createLoan(uint platformIndex, address borrowToken, uint borrowAmount) external;
    function repayLoan(uint platformIndex, address borrowToken, uint repayAmount) external;
}
