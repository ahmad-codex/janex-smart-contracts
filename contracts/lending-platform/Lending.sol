pragma solidity ^0.8.0;
import "../future-exchange/libraries/SafeMath.sol";
import "./interfaces/ILending.sol";
import "./interfaces/IAaveLendingPool.sol";
import "./interfaces/IAaveAddressesProvider.sol";
import "./interfaces/IAavePriceOracle.sol";
import "./interfaces/DataTypes.sol";
import "./interfaces/ICompoundComptroller.sol";
import "./interfaces/ICompoundErc20.sol";
import "./interfaces/ICompoundPriceOracle.sol";
import "./libraries/WadRayMath.sol";
import "../common/interfaces/IERC20.sol";
import "./Converter.sol";

contract Lending is ILending {
    using SafeMath for uint256;
    using WadRayMath for uint256;

    address public admin;
    address public provider;

    address public usdc;
    address public dai;
    address public usdcAAVE;
    address public daiAAVE;
    address public converter;

    uint public compoundBorrowLimitPercent = 80;

    IAaveLendingPool public aaveLendingPool;
    ICompoundComptroller public compoundComptroller;
    mapping (address => ICompoundErc20) public compoundErc20;

    bool public flagAAVE = true;
    bool public flagCompound = true;

    struct AAVEInfo {
        uint collateral;
        uint borrowedAmount;
        uint liquidationThreshold;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "LENDING: Not admin address");
        _;
    }

    modifier onlyProvider() {
        require(msg.sender == provider, "LENDING: Not provider address");
        _;
    }

    constructor(address _admin, address _provider) {
        provider = _provider;
        admin = _admin;
    }

    function initiate(
        address _usdc,
        address _dai,
        address _usdcAAVE,
        address _daiAAVE,
        address _aaveLendingPool,
        address _compoundComptroller,
        address _compoundUsdc,
        address _compoundDai
    ) external onlyAdmin {
        aaveLendingPool = IAaveLendingPool(_aaveLendingPool); // kovan 0xE0fBa4Fc209b4948668006B2bE61711b7f465bAe
        compoundComptroller = ICompoundComptroller(_compoundComptroller); // kovan 0x2EAa9D77AE4D8f9cdD9FAAcd44016E746485bddb
        compoundErc20[_usdc] = ICompoundErc20(_compoundUsdc); // kovan 0x4a92e71227d294f041bd82dd8f78591b75140d63
        compoundErc20[_dai] = ICompoundErc20(_compoundDai); // kovan 0x3f0a0ea2f86bae6362cf9799b523ba06647da018
        usdc = _usdc;
        dai = _dai;
        usdcAAVE = _usdcAAVE;
        daiAAVE = _daiAAVE;

        IERC20(_usdc).approve(_compoundUsdc, type(uint).max);
        IERC20(_dai).approve(_compoundDai, type(uint).max);
        IERC20(_usdcAAVE).approve(_aaveLendingPool, type(uint).max);
        IERC20(_daiAAVE).approve(_aaveLendingPool, type(uint).max);
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }

    function setConverter(address _converter) external onlyAdmin {
        converter = _converter;
        IERC20(usdc).approve(_converter, type(uint).max);
        IERC20(dai).approve(_converter, type(uint).max);
        IERC20(usdcAAVE).approve(_converter, type(uint).max);
        IERC20(daiAAVE).approve(_converter, type(uint).max);
    }

    function setProvider(address _provider) external onlyAdmin {
        provider = _provider;
    }

    function setcompoundBorrowLimitPercent(uint _limit) external onlyAdmin {
        compoundBorrowLimitPercent = _limit;
    }

    function setStatusFlag(uint index, bool value) external onlyAdmin {
        if (index == 1) flagAAVE = value;
        if (index == 2) flagCompound = value;
    }

    function getLendingPlatforms(uint256 index) override external view returns (address) {
        if (index == 1) return address(aaveLendingPool);
        if (index == 2) return address(compoundComptroller);
        return address(0);
    }

    function lendingPlatformsCount() override public pure returns (uint) {
        return 2;
    }

    function createLoan(uint platformIndex, address borrowToken, uint borrowAmount) external override{
        require(borrowToken != address(0), "LENDING: Invalid borrow token!");
        if (platformIndex == 1) {
            require(flagAAVE == true, "LENDING: Lending platform not available");
            uint availableAmount = this.getBorrowableAmount(1, borrowToken);
            require (borrowAmount <= availableAmount, "LENDING: Borrow more than collateral");

            if (borrowToken == usdc && converter != address(0)) {
                aaveLendingPool.borrow(usdcAAVE, borrowAmount, 1, 0, address(this));
                Converter(converter).convert(usdcAAVE, borrowAmount, usdc);
            } else {
                require(borrowToken == daiAAVE || borrowToken == usdcAAVE, "Lending: Invalid borrow token!");
                aaveLendingPool.borrow(borrowToken, borrowAmount, 1, 0, address(this));
            }
        }
        else if (platformIndex == 2) {
            require(flagCompound == true, "LENDING: Lending platform not available");
            require(address(compoundErc20[borrowToken]) != address(0), "Lending: Invalid borrow token!");

            uint availableBorrowAmount = _getCompoundAvailableBorrowAmount(borrowToken, true);
            require(borrowAmount <= availableBorrowAmount * compoundBorrowLimitPercent / 100, "LENDING: Borrow more than collateral");
            compoundErc20[borrowToken].borrow(borrowAmount);
        }
        else revert("LENDING: Invalid Lending Platform index");
        IERC20(borrowToken).transfer(msg.sender, borrowAmount);
    }

    function repayLoan(uint platformIndex, address borrowToken, uint repayAmount) override external {
        require(borrowToken != address(0), "LENDING: Invalid borrow token!");
        IERC20(borrowToken).transferFrom(msg.sender, address(this), repayAmount);
        if (platformIndex == 1) {
            require(flagAAVE == true, "LENDING: Lending platform not available");
            uint borrowedAmount = this.getLendingPlatformBorrow(1, borrowToken);
            require (repayAmount <= borrowedAmount, "Lending: Repay more than allowed!");
            require (repayAmount != 0, "Lending: Repay a certain amount!");
            if (borrowToken == usdc && converter != address(0)) {
                Converter(converter).convert(usdc, repayAmount, usdcAAVE);
                aaveLendingPool.repay(usdcAAVE, repayAmount, 1, address(this));
            } else {
                require(borrowToken == daiAAVE || borrowToken == usdcAAVE, "Lending: Invalid borrow token!");
                aaveLendingPool.repay(borrowToken, repayAmount, 1, address(this));
            }
        }
        else if (platformIndex == 2) {
            require(flagCompound == true, "LENDING: Lending platform not available");
            require(address(compoundErc20[borrowToken]) != address(0), "Lending: Invalid borrow token!");
            uint borrowedAmount = this.getLendingPlatformBorrow(2, borrowToken);
            require (repayAmount <= borrowedAmount, "Lending: Repay more than allowed!");
            require (repayAmount != 0, "Lending: Repay a certain amount!");
            compoundErc20[borrowToken].repayBorrow(repayAmount);
        }
        else revert("LENDING: Invalid Lending Platform index");
    }

    function getBorrowableAmount(uint platformIndex, address borrowToken) override external view returns (uint availableBorrowAmount) {
        if (platformIndex == 1) {
            if (!flagAAVE) return 0;
            if (borrowToken != daiAAVE && borrowToken != usdcAAVE) {
                if (borrowToken == usdc && converter != address(0)) {
                    borrowToken = usdcAAVE;
                } else {
                    return 0;
                }
            }

            AAVEInfo memory infor;
            (uint collateralETH, uint borrowedAmountETH,, uint liquidationThreshold,,uint healthFactorETH) = aaveLendingPool.getUserAccountData(address(this));

            IAaveAddressesProvider addressesProvider = aaveLendingPool.getAddressesProvider();
            IAavePriceOracle oracle = addressesProvider.getPriceOracle();
            uint priceReserveETH = oracle.getAssetPrice(borrowToken);

            DataTypes.ReserveConfigurationMap memory reserveConfig = aaveLendingPool.getConfiguration(borrowToken);
            uint decimalReserve = (reserveConfig.data % (2 ** 55)) >> (48);

            infor.collateral = collateralETH * (10 ** decimalReserve)/ priceReserveETH;
            uint healthFactor = healthFactorETH / (10 ** 17);
            if(borrowedAmountETH > 0) {
                if(healthFactor <= 15) {
                    return 0;
                }
                else {
                    uint sumBorrowAmountETH = (collateralETH * liquidationThreshold) / 15000;
                    availableBorrowAmount = (sumBorrowAmountETH - borrowedAmountETH) * (10 ** decimalReserve) / priceReserveETH;
                }
            } else {
                availableBorrowAmount = (infor.collateral * liquidationThreshold) / 15000;
            }
        }
        if (platformIndex == 2) {
            if (!flagCompound) return 0;
            if (address(compoundErc20[borrowToken]) == address(0)) return 0;

            return _getCompoundAvailableBorrowAmount(borrowToken, false) * compoundBorrowLimitPercent / 100;
        }
    }

    function getDebtAmount(
        uint256 platformIndex,
        address borrowToken,
        uint256 borrowAmount,
        uint256 fromTimestamp,
        uint256 toTimestamp,
        uint256 fromBlock,
        uint256 toBlock
    ) override external view returns(uint debtAmount) {
        if (platformIndex == 1) {
            if (!flagAAVE) return 0;
            if (borrowToken != daiAAVE && borrowToken != usdcAAVE) {
                if (borrowToken == usdc && converter != address(0)) {
                    borrowToken = usdcAAVE;
                } else {
                    return 0;
                }
            }

            DataTypes.ReserveData memory reserveData = aaveLendingPool.getReserveData(borrowToken);
            uint interestRateAAVE = reserveData.currentStableBorrowRate;
            uint interestAAVE = _calculateCompoundedInterest(interestRateAAVE, fromTimestamp, toTimestamp);
            debtAmount = (interestAAVE * borrowAmount) / 10 ** 27;
        }
        if (platformIndex == 2) {
            if (!flagCompound) return 0;
            if (address(compoundErc20[borrowToken]) == address(0)) return 0;

            uint blockNumber = fromBlock > 0 && toBlock > 0
                ? toBlock - fromBlock
                : (toTimestamp - fromTimestamp) / 13; // estimate block time = 13
            uint interestRate = compoundErc20[borrowToken].borrowRatePerBlock() * blockNumber;
            debtAmount =  borrowAmount + borrowAmount * interestRate / (10 ** 18);
        }
    }

    function _calculateCompoundedInterest(
        uint256 rate,
        uint256 lastUpdateTimestamp,
        uint256 currentTimestamp
    ) internal pure returns (uint256) {
        uint256 exp = currentTimestamp.sub(uint256(lastUpdateTimestamp));

        if (exp == 0) {
          return WadRayMath.ray();
        }

        uint256 expMinusOne = exp - 1;
        uint256 expMinusTwo = exp > 2 ? exp - 2 : 0;
        uint256 SECONDS_PER_YEAR = 365 days;

        uint256 ratePerSecond = rate / SECONDS_PER_YEAR;

        uint256 basePowerTwo = ratePerSecond.rayMul(ratePerSecond);
        uint256 basePowerThree = basePowerTwo.rayMul(ratePerSecond);

        uint256 secondTerm = exp.mul(expMinusOne).mul(basePowerTwo) / 2;
        uint256 thirdTerm = exp.mul(expMinusOne).mul(expMinusTwo).mul(basePowerThree) / 6;

        return WadRayMath.ray().add(ratePerSecond.mul(exp)).add(secondTerm).add(thirdTerm);
    }

    function sendCollateral(uint platformIndex, address collateralToken, uint256 amount) external override onlyProvider {
        require(collateralToken != address(0), "LENDING: Invalid borrow token!");

        IERC20(collateralToken).transferFrom(msg.sender, address(this), amount);
        if (platformIndex == 1) {
            require(flagAAVE == true, "LENDING: Lending platform not available");
            require(collateralToken == daiAAVE, "LENDING: Invalid borrow token!");

            aaveLendingPool.deposit(collateralToken, amount, address(this), 0);
            aaveLendingPool.setUserUseReserveAsCollateral(collateralToken, true);
        }
        else if (platformIndex == 2) {
            require(flagCompound == true, "LENDING: Lending platform not available");
            require(address(compoundErc20[collateralToken]) != address(0), "LENDING: Invalid borrow token!");
            compoundErc20[collateralToken].mint(amount);

            address[] memory cTokens = new address[](1);
            cTokens[0] = address(compoundErc20[collateralToken]);
            uint256[] memory errors = compoundComptroller.enterMarkets(cTokens);
            require (errors[0] == 0, "COMPOUND: Enter market failed.");
        }
        else revert("LENDING: Invalid Lending Platform index");
    }

    function withdrawCollateral(uint platformIndex, address collateralToken, uint256 amount) external override onlyProvider {
        require(collateralToken != address(0), "Lending: Invalid borrow token!");

        if (platformIndex == 1) {
            require(flagAAVE == true, "LENDING: Lending platform not available");
            require(collateralToken == daiAAVE, "LENDING: Invalid borrow token!");

            (, uint borrowedAmountETH,,,,) = aaveLendingPool.getUserAccountData(address(this));
            (, uint withdrawAmount) = this.getLendingPlatformCollateral(1, collateralToken);
            require( amount <= withdrawAmount, "LENDING: COLLATERAL_NOT_ENOUGH");

            if (borrowedAmountETH > 0){
                aaveLendingPool.withdraw(collateralToken, amount, msg.sender);
            } else {
                aaveLendingPool.withdraw(collateralToken, amount, msg.sender);
            }
        }
        else if (platformIndex == 2) {
            require(flagCompound == true, "LENDING: Lending platform not available");
            require(address(compoundErc20[collateralToken]) != address(0), "Lending: Invalid borrow token!");

            uint error = compoundErc20[collateralToken].redeemUnderlying(amount);
            (, uint withdrawAmount) = this.getLendingPlatformCollateral(2, collateralToken);
            require(error == 0, "COMPOUND: Don't have enough balance/liquidity to withdraw");
            require(amount <= withdrawAmount, "LENDING: COLLATERAL_NOT_ENOUGH");
            IERC20(collateralToken).transfer(msg.sender, amount);
        }
        else revert("LENDING: Invalid Lending Platform index");

    }

    function _getCompoundAvailableBorrowAmount(address borrowToken, bool throwError) internal view returns(uint) {
        (uint error, uint liquidity, uint shortfall) = compoundComptroller.getAccountLiquidity(address(this));
        if (throwError) {
            require(error == 0, "COMPOUND: Get liquidity error");
            require(shortfall == 0, "COMPOUND: Account liquidity have low collateral");
        } else {
            if (error != 0 || shortfall != 0) return 0;
        }

        ICompoundPriceOracle oracle = compoundComptroller.oracle();
        uint underlyingPrice = oracle.getUnderlyingPrice(address(compoundErc20[borrowToken]));
        return liquidity * (10 ** 18) / underlyingPrice;
    }

    function getLendingPlatformCollateral(uint platformIndex, address collateralToken)
        override
        external
        returns (uint collateralAmount, uint withdrawableAmount)
	{
        require(collateralToken != address(0), "LENDING: Invalid borrow token!");
        if (platformIndex == 1) {
            if (!flagAAVE) return (0, 0);
            if (collateralToken != daiAAVE && collateralToken != usdcAAVE) {
                if (collateralToken == dai && converter != address(0)) {
                    collateralToken = daiAAVE;
                } else {
                    return (0, 0);
                }
            }

            (uint collateralETH, uint borrowedAmountETH,, uint liquidationThreshold,,) = aaveLendingPool.getUserAccountData(address(this));
            IAaveAddressesProvider addressesProvider = aaveLendingPool.getAddressesProvider();
            IAavePriceOracle oracle = addressesProvider.getPriceOracle();
            uint priceReserveETH = oracle.getAssetPrice(collateralToken);
            DataTypes.ReserveConfigurationMap memory reserveConfig = aaveLendingPool.getConfiguration(collateralToken);
            uint decimalReserve = (reserveConfig.data % (2 ** 55)) >> (48);

            collateralAmount = collateralETH * (10 ** decimalReserve)/ priceReserveETH;
            if (borrowedAmountETH > 0) {
                uint withdrawableAmountETH = collateralETH - (15000 * borrowedAmountETH / liquidationThreshold);
                withdrawableAmount = withdrawableAmountETH * (10 ** decimalReserve) / priceReserveETH;
            } else {
                withdrawableAmount = collateralAmount;
            }
        }
        else if (platformIndex == 2) {
            if (!flagCompound) return (0, 0);
            if (address(compoundErc20[collateralToken]) == address(0)) return (0, 0);

            collateralAmount = compoundErc20[collateralToken].balanceOfUnderlying(address(this));
            uint liquidity = _getCompoundAvailableBorrowAmount(collateralToken, false);
            if (liquidity > 0 && collateralAmount > 0) {
                (,uint factor,) = compoundComptroller.markets(address(compoundErc20[collateralToken]));
                withdrawableAmount = liquidity * 10 ** 18 / factor;
            } else {
                withdrawableAmount = collateralAmount;
            }
        }
    }

    function getLendingPlatformBorrow(uint platformIndex, address borrowToken)
        override
        external
        returns (uint borrowedAmount)
	{
	    require(borrowToken != address(0), "LENDING: Invalid borrow token!");
	    if (platformIndex == 1) {
            if (!flagAAVE) return (0);
            if (borrowToken != daiAAVE && borrowToken != usdcAAVE) {
                if (borrowToken == usdc && converter != address(0)) {
                    borrowToken = usdcAAVE;
                } else {
                    return 0;
                }
            }

            (, uint borrowedAmountETH,,,,) = aaveLendingPool.getUserAccountData(address(this));
            IAaveAddressesProvider addressesProvider = aaveLendingPool.getAddressesProvider();
            IAavePriceOracle oracle = addressesProvider.getPriceOracle();
            uint priceReserveETH = oracle.getAssetPrice(borrowToken);
            DataTypes.ReserveConfigurationMap memory reserveConfig = aaveLendingPool.getConfiguration(borrowToken);
            uint decimalReserve = (reserveConfig.data % (2 ** 55)) >> (48);
            borrowedAmount = borrowedAmountETH * (10 ** decimalReserve)/ priceReserveETH;
	    }
	    else if (platformIndex == 2) {
            if (!flagCompound) return (0);
            if (address(compoundErc20[borrowToken]) == address(0)) return (0);
            borrowedAmount = compoundErc20[borrowToken].borrowBalanceCurrent(address(this));
	    }
	}
}
