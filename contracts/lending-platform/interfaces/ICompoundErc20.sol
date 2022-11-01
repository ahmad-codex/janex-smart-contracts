pragma solidity ^0.8.0;

interface ICompoundErc20 {
    function borrowRatePerBlock() external view returns (uint256);
    function borrow(uint amount) external;
    function repayBorrow(uint256 amount) external;
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function balanceOfUnderlying(address account) external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function borrowBalanceStored(address account) external view returns (uint);
    function mint(uint mintAmount) external returns (uint);
}