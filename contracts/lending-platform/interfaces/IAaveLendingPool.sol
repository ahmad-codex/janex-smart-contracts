pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import {IAaveAddressesProvider} from "./IAaveAddressesProvider.sol";
import {DataTypes} from "./DataTypes.sol";

interface IAaveLendingPool {

  function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;

  function withdraw(address asset, uint256 amount, address to) external returns (uint256);

  function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;

  function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external returns (uint256);

  function swapBorrowRateMode(address asset, uint256 rateMode) external;

  function rebalanceStableBorrowRate(address asset, address user) external;

  function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;

  function liquidationCall(
    address collateralAsset,
    address debtAsset,
    address user,
    uint256 debtToCover,
    bool receiveAToken
  ) external;

  function flashLoan(
    address receiverAddress,
    address[] calldata assets,
    uint256[] calldata amounts,
    uint256[] calldata modes,
    address onBehalfOf,
    bytes calldata params,
    uint16 referralCode
  ) external;

  function getUserAccountData(address user)
    external
    view
    returns (
      uint256 totalCollateralETH,
      uint256 totalDebtETH,
      uint256 availableBorrowsETH,
      uint256 currentLiquidationThreshold,
      uint256 ltv,
      uint256 healthFactor
    );

  function initReserve(
    address reserve,
    address aTokenAddress,
    address stableDebtAddress,
    address variableDebtAddress,
    address interestRateStrategyAddress
  ) external;

  function setReserveInterestRateStrategyAddress(address reserve, address rateStrategyAddress) external;

  function setConfiguration(address reserve, uint256 configuration) external;

  function getConfiguration(address asset) external view returns (DataTypes.ReserveConfigurationMap memory);

  function getUserConfiguration(address user) external view returns (DataTypes.UserConfigurationMap memory);

  function getReserveNormalizedIncome(address asset) external view returns (uint256);

  function getReserveNormalizedVariableDebt(address asset) external view returns (uint256);

  function getReserveData(address asset) external view returns (DataTypes.ReserveData memory);

  function finalizeTransfer(
    address asset,
    address from,
    address to,
    uint256 amount,
    uint256 balanceFromAfter,
    uint256 balanceToBefore
  ) external;

  function getReservesList() external view returns (address[] memory);

  function getAddressesProvider() external view returns (IAaveAddressesProvider);

  function setPause(bool val) external;

  function paused() external view returns (bool);
}