pragma solidity ^0.8.0;
import "./interfaces/IExchangeRouter.sol";
import "../future-exchange/interfaces/IFutureExchangeRouter.sol";
import "../future-token/interfaces/IFutureToken.sol";
import "../future-token/interfaces/IFutureTokenFactory.sol";
import "../future-token/interfaces/IFutureContract.sol";
import "../lending-platform/interfaces/ILending.sol";
import "../common/interfaces/IERC20.sol";
import "../common/interfaces/IOwnable.sol";
import "../future-token/interfaces/IFutureContract.sol";
import "../lending-platform/interfaces/ILending.sol";
import "../lending-platform/interfaces/DataTypes.sol";
import "../staking/interfaces/IStakingPool.sol";

contract Janex {

    struct BorrowInfo {
        uint platformIndex;
        uint amount;
        uint startTime;
        uint startBlock;
    }

    struct TradeInfo {
        address exchange;
        address futureExchange;
        address futureContract;
    }

    struct ProfitInfo {
        uint amount;
        uint debt;
        uint expiryDate;
    }

    struct FeeInfo {
        uint trading;
        uint lending;
    }

    address public usdc;
    address public weth;
    address public tradingService;
    address public admin;
    address public lendingContract;
    address public stakingPool;

    uint256 public feeWithdrawByUSDC = 2e6; // 2 USDC
    uint256 public feeTradingByEth = 5e15; // 0.005 ETH
    uint256 public feeLendingByEth = 5e15; // 0.005 ETH
    uint256 public borrowRateLimit = 70; // 70%


    address[] futureExchanges;
    address[] exchanges;
    mapping(address => uint) futureExchangeIndex;
    mapping(address => uint) exchangeIndex;

    mapping(address => uint) availableAmount;
    mapping(address => uint) investAmount;
    mapping(address => uint) totalTradingAmount;

    mapping(address => mapping(address => uint)) tradingAmount;
    mapping(address => mapping(address => uint)) revenueAmount;
    mapping(address => mapping(address => uint)) liquidatedAmount;
    mapping(address => mapping(address => bool)) isTradeClosed;
    mapping(address => mapping(address => BorrowInfo[])) userBorrowInfo;

    address[] tradeUsers;
    mapping(address => uint256) tradeUserIndex;
    
    uint public airdropPercent = 10;
    uint public airdropAmount;
    uint public airdropReceiverCount = 0;
    mapping(address => bool) isAirdropReceiver;
    
    mapping(address => bool) isStaked;

    event Airdrop(address indexed user, uint amount, uint indexed timestamp);

    event Deposit(address indexed user, uint amount, uint indexed timestamp);
    event Withdraw(address indexed user, uint amount, uint fee, uint indexed timestamp);
    event Trade(
        address indexed user,
        address indexed futureContract,
        uint256 deadline,
        uint256 amount,
        uint256 profit,
        uint256 fee,
        uint256 indexed timestamp);
    event Borrow(
        address indexed user,
        address indexed futureContract,
        uint256 indexed platformIndex,
        uint256 amount,
        uint256 interest,
        uint256 fee);
    event Liquidate(address indexed user, address indexed futureContract, uint profitActual, uint indexed timestamp);
    event UnpaidLoan(address indexed user, address indexed futureContract, uint indexed platformIndex, uint amount);

    modifier onlyAdmin() {
        require(msg.sender == admin, "JanexV2: NOT_ADMIN_ADDRESS");
        _;
    }

    constructor(address _usdc, address _weth, address _tradingService, address _admin) {
        usdc = _usdc;
        weth = _weth;
        tradingService = _tradingService;
        admin = _admin;
    }

    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
    }
    
    function setAirdropPercent(uint percent) external onlyAdmin {
        airdropPercent = percent;
    }

    function setFeeWithdrawByUSDC(uint256 fee) external onlyAdmin {
        feeWithdrawByUSDC = fee;
    }

    function setFeeTradingByETH(uint256 fee) external onlyAdmin {
        feeTradingByEth = fee;
    }

    function setFeeLendingByEth(uint256 fee) external onlyAdmin {
        feeLendingByEth = fee;
    }

    function setBorrowRateLimit(uint256 borrowRate) external onlyAdmin {
        borrowRateLimit = borrowRate;
    }

    function setLending(address lending) external onlyAdmin {
        lendingContract = lending;
        IERC20(usdc).approve(address(lending), type(uint256).max);
    }
    
    function setStakingPool(address pool) external onlyAdmin {
        stakingPool = pool;
    }

    function tradeAvailableUsers() external view returns(address[] memory) {
        return tradeUsers;
    }

    function getFutureExchanges(uint256 index) external view returns (address) {
        return futureExchanges[index];
    }

    function getExchanges(uint256 index) external view returns (address) {
        return exchanges[index];
    }

    function getLendingFeeByEth() external view returns (uint256) {
        return feeLendingByEth;
    }

    function getBorrowingRateLimit() external view returns(uint256) {
        return borrowRateLimit;
    }

    function getLending() external view returns(address) {
        return lendingContract;
    }
    
    function getStakingPool() external view returns(address) {
        return stakingPool;
    }

    function getAvailableAmount(address user) external view returns (uint256) {
        return availableAmount[user];
    }

    function getInvestAmount(address user) external view returns (uint256) {
        return investAmount[user];
    }

    function getTradingAmount(address user) external view returns (uint256) {
        return totalTradingAmount[user];
    }

    function getTradingAmountOnFutureContract(address user, address futureContract) external view returns (uint256) {
        return tradingAmount[user][futureContract];
    }

    function getUserBorrowInfo(address user, address futureContract) external view returns(BorrowInfo[] memory) {
        return userBorrowInfo[user][futureContract];
    }

    function getLiquidateInfo(address user, address futureContract) external view returns (uint liquidateAmount, bool isTradeClose) {
        liquidateAmount = liquidatedAmount[user][futureContract];
        isTradeClose = isTradeClosed[user][futureContract];
    }

    function getTradeUserIndex(address user) external view returns (uint256) {
        return tradeUserIndex[user];
    }

    function addFutureExchange(address exchange) external {
        require(!isFutureExchange(exchange), "JanexV2: FUTURE_EXCHANGE_ADDED");
        futureExchanges.push(exchange);
        futureExchangeIndex[exchange] = futureExchanges.length;
    }

    function addExchange(address exchange) external {
        require(!isExchange(exchange), "JanexV2: EXCHANGE_ADDED");
        exchanges.push(exchange);
        exchangeIndex[exchange] = exchanges.length;
        IERC20(usdc).approve(address(exchange), type(uint256).max);
    }

    function removeFutureExchange(address exchange) external {
        require(isFutureExchange(exchange), "JanexV2: FUTURE_EXCHANGE_NOT_ADDED");
        if (futureExchanges.length > 1) {
            uint256 index = futureExchangeIndex[exchange] - 1;
            futureExchanges[index] = futureExchanges[futureExchanges.length - 1];
        }
        futureExchanges.pop();
        futureExchangeIndex[exchange] = 0;
        IERC20(usdc).approve(address(exchange), 0);
    }

    function removeExchange(address exchange) external {
        require(isExchange(exchange), "JanexV2: EXCHANGE_NOT_ADDED");
        if (exchanges.length > 1) {
            uint256 index = exchangeIndex[exchange] - 1;
            exchanges[index] = exchanges[exchanges.length - 1];
        }
        exchanges.pop();
        exchangeIndex[exchange] = 0;
        IERC20(usdc).approve(address(exchange), 0);
    }

    function isFutureExchange(address exchange) public view returns (bool) {
        return futureExchangeIndex[exchange] > 0;
    }

    function isExchange(address exchange) public view returns (bool) {
        return exchangeIndex[exchange] > 0;
    }

    function futureExchangesCount() external view returns (uint256) {
        return futureExchanges.length;
    }

    function exchangesCount() external view returns (uint256) {
        return exchanges.length;
    }

    function deposit(uint256 amount) external {
        require(amount > 0, "JanexV2: AMOUNT_LOWER_EQUAL_FEE");
        IERC20(usdc).transferFrom(msg.sender, address(this), amount);
        _deposit(amount);
        _addTradingUser();
    }

    function setIsStaking(bool _isStaked) external {
        if(_isStaked){
            require(tradeUserIndex[msg.sender] != 0, "JanexV2: NOT_IS_TRADE_USER");
        }
        isStaked[msg.sender] = _isStaked;
    }

    function getIsStaking(address user) external view returns (bool) {
        return isStaked[user];
    }

    function _deposit(uint256 amount) internal {
        availableAmount[msg.sender] += amount;
        emit Deposit(msg.sender, amount, block.timestamp);
    }

    function _addTradingUser() internal {
        if (tradeUserIndex[msg.sender] == 0) {
            tradeUsers.push(msg.sender);
            tradeUserIndex[msg.sender] = tradeUsers.length;
        }
    }

    function withdraw(uint256 amount, address to) external {
        require(availableAmount[msg.sender] >= amount + feeWithdrawByUSDC , "JanexV2: AVAILABLE_AMOUNT_NOT_ENOUGH");
        IERC20(usdc).transfer(to, amount);
        _wthdraw(amount);
        IERC20(usdc).transfer(admin, feeWithdrawByUSDC);
        _removeTradingUser(msg.sender);
    }

    function _wthdraw(uint256 amount) internal {
        availableAmount[msg.sender] -= amount + feeWithdrawByUSDC;
        emit Withdraw(msg.sender, amount, feeWithdrawByUSDC, block.timestamp);
    }

    function _removeTradingUser(address user) internal {
        if (availableAmount[user] == 0) {
            if (tradeUsers.length > 0) {
                uint256 index = tradeUserIndex[user] - 1;
                uint256 lastUserIndex = tradeUsers.length - 1;
                address lastUser = tradeUsers[lastUserIndex];
                tradeUserIndex[lastUser] = tradeUserIndex[user];
                tradeUsers[index] = lastUser;
            }
            tradeUserIndex[user] = 0;
            tradeUsers.pop();
        }
    }

    function withdrawLiquidate(address futureContract, address to, address user) external {
        require(!isTradeClosed[user][futureContract], "JanexV2: TRADE_CLOSED");
        if (liquidatedAmount[user][futureContract] == 0) {
            this.liquidate(futureContract, user);
        }
        uint amount;
        if(isStaked[user] == true){
            uint requireLocktime = IStakingPool(stakingPool).getRequireLockTime(user);
            require(requireLocktime != 0, "JanexV2: no start staking");
            require(block.timestamp >= requireLocktime, "JanexV2: can't withdraw in locktime");
            uint returnStakingAmount = IStakingPool(stakingPool).withdraw(user);
            isStaked[user] == false;
            amount = returnStakingAmount - feeWithdrawByUSDC;
        } else {
            amount = liquidatedAmount[user][futureContract] - feeWithdrawByUSDC;
        }
        
        IERC20(usdc).transfer(to, amount);
        IERC20(usdc).transfer(admin, feeWithdrawByUSDC);
        isTradeClosed[user][futureContract] = true;
        _updateLiquidateAmount(user, futureContract);
        emit Withdraw(user, amount, feeWithdrawByUSDC, block.timestamp);
    }

    function reinvest(address futureContract, address user) external {
        require(!isTradeClosed[user][futureContract], "JanexV2: TRADE_CLOSED");
        if (liquidatedAmount[user][futureContract] == 0) {
            this.liquidate(futureContract, user);
        }
        if(isStaked[user] == true){
            uint requireLocktime = IStakingPool(stakingPool).getRequireLockTime(user);
            require(block.timestamp >= requireLocktime, "Janex: can't withdraw in locktime");
            uint returnStakingAmount = IStakingPool(stakingPool).withdraw(user);
            isStaked[user] == false;
            availableAmount[msg.sender] += returnStakingAmount;
        } else {
            availableAmount[msg.sender] += liquidatedAmount[user][futureContract];
        }
        isTradeClosed[user][futureContract] = true;
        _updateLiquidateAmount(user, futureContract);
        _addTradingUser();
    }

    function liquidate(address futureContract, address user) public {
        require(liquidatedAmount[user][futureContract] == 0, "JanexV2: ALREADY_LIQUIDATED");
        require(totalTradingAmount[user] > 0, "JanexV2: TRADING_AMOUNT_NOT_ENOUGH");
        address tokenA = IFutureContract(futureContract).token0();
        address tokenB = IFutureContract(futureContract).token1();
        require(tokenA == usdc || tokenB == usdc, "JanexV2: INVALID_TOKEN");

        address tokenInvest = tokenA == usdc ? tokenB : tokenA;
        uint256 expiryDate = IFutureContract(futureContract).expiryDate();
        address futureFactory = IOwnable(futureContract).owner();
        address futureExchange = IFutureTokenFactory(futureFactory).exchange();
        address futureToken = IFutureTokenFactory(futureFactory).getFutureToken(tokenInvest, usdc, expiryDate);

        if (IERC20(futureToken).allowance(address(this), futureExchange) == 0) {
            IERC20(futureToken).approve(futureExchange, type(uint256).max);
        }
        
        uint revenue = revenueAmount[user][futureContract];
        IFutureExchangeRouter(futureExchange).closeFuture(tokenInvest, usdc, expiryDate, address(this), revenue);
        
        uint debt = _repayLoan(user, futureContract);
        uint actualProfit = revenue - tradingAmount[user][futureContract] - debt;
        liquidatedAmount[user][futureContract] = revenue - debt;
        airdropAmount += liquidatedAmount[user][futureContract] * airdropPercent / 100;
        liquidatedAmount[user][futureContract] -= liquidatedAmount[user][futureContract] * airdropPercent / 100;
        
        if (isAirdropReceiver[user] == false) {
            airdropReceiverCount += 1;
            isAirdropReceiver[user] = true;
        }
        
        if (isStaked[user] == true){
            if (IStakingPool(stakingPool).getEndTime() > expiryDate){
                if (IERC20(usdc).allowance(address(this), stakingPool) == 0) {
                    IERC20(usdc).approve(stakingPool, type(uint256).max);
                }
                uint amountStaking = liquidatedAmount[user][futureContract];
                require(IERC20(usdc).balanceOf(address(this)) >= amountStaking, "JanexV2: insufficient balance");
                IStakingPool(stakingPool).stakingOnBehalf(user, amountStaking);
            }
        }

        emit Liquidate(user, futureContract, actualProfit, block.timestamp);
    }

    function _swapFee(uint feeEth) internal returns(uint usedUsdc) {
        address[] memory pair = new address[](2);
        pair[0] = usdc;
        pair[1] = weth;

        uint256 deadline = block.timestamp + 3600;

        (address exchange, uint256 feeTradingUsdc) = _selectBestPriceExchange(pair, feeEth);
        if (address(exchange) != address(0)) {
            uint[] memory amounts = IExchangeRouter(exchange).swapTokensForExactETH(feeTradingByEth, feeTradingUsdc, pair, tradingService, deadline);
            return (amounts[0]);
        }
    }

    function _selectBestPriceExchange(address[] memory pair, uint256 amount)
        internal view returns (address selected, uint256 inAmount)
    {
        inAmount = type(uint256).max;
        for (uint256 i = 0; i < exchanges.length; i++) {
            IExchangeRouter exchange = IExchangeRouter(exchanges[i]);
            try exchange.getAmountsIn(amount, pair) returns (uint256[] memory inAmounts) {
                if (inAmount > inAmounts[0]) {
                    inAmount = inAmounts[0];
                    selected = exchanges[i];
                }
            } catch {}
        }
    }

    function _getUserLoans(address user, address futureContract) internal view returns(BorrowInfo[] memory userLoans) {
        uint count = ILending(lendingContract).lendingPlatformsCount();
        userLoans = new BorrowInfo[](count);

        BorrowInfo[] memory loans = userBorrowInfo[user][futureContract];
        if (loans.length > 0) {
            for (uint i = 0; i < loans.length; i++) {
                uint index = loans[i].platformIndex - 1;
                if (userLoans[index].platformIndex == 0) {
                    userLoans[index] = loans[i];
                } else {
                    userLoans[index].amount += loans[i].amount;
                }
            }
        }
    }

    function _repayLoan(address user, address futureContract) internal returns(uint totalDebt) {
        BorrowInfo[] memory loans = _getUserLoans(user, futureContract);
        if (loans.length > 0) {
            for (uint i = 0; i < loans.length; i++) {
                if (loans[i].platformIndex > 0) {
                    uint debt = _getDebtAmount(loans[i], block.timestamp, block.number);
                    if (totalDebt + debt > revenueAmount[user][futureContract]) {
                        uint unpaidDebt = totalDebt + debt - revenueAmount[user][futureContract];
                        debt = revenueAmount[user][futureContract] - totalDebt;
                        emit UnpaidLoan(user, futureContract, loans[i].platformIndex, unpaidDebt);
                    }
                    if (debt > 0) {
                        totalDebt += debt;
                        ILending(lendingContract).repayLoan(loans[i].platformIndex, usdc, debt);
                    }
                }
            }
        }
    }

    function _updateLiquidateAmount(address user, address futureContract) internal {
        totalTradingAmount[user] -= tradingAmount[user][futureContract];
        tradingAmount[user][futureContract] = 0;
    }

    function maxProfitable(address user) external view returns (
        uint256 tradeAmount,
        uint256 profitAmount,
        TradeInfo memory trade,
        BorrowInfo memory borrowInfo
    ) {
        FeeInfo memory fee = FeeInfo(_convertEthToUsdc(feeTradingByEth), _convertEthToUsdc(feeLendingByEth));
        if (availableAmount[user] > fee.trading) {
            tradeAmount = availableAmount[user];
            BorrowInfo[] memory loans = _getAvailableLoans(tradeAmount);
            if (loans.length == 0) {
                loans = new BorrowInfo[](1);
            }
            for (uint k = 0; k < futureExchanges.length; k++) {
                address[] memory futureContracts = IFutureExchangeRouter(futureExchanges[k]).getListFutureContractsInPair(usdc);
                for (uint j = 0; j < futureContracts.length; j++) {
                    for (uint i = 0; i < exchanges.length; i++) {
                        TradeInfo memory _trade = TradeInfo(exchanges[i], futureExchanges[k], futureContracts[j]);
                        for (uint l = 0; l < loans.length; l++) {
                            ProfitInfo memory profit = _calculateProfit(user, tradeAmount, fee, _trade, loans[l]);
                            if (profit.amount > profitAmount) {
                                profitAmount = profit.amount;
                                trade = _trade;
                                if (profit.debt > 0 && loans[l].amount > 0) {
                                    borrowInfo = loans[l];
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function _convertEthToUsdc(uint amount) internal view returns(uint) {
        address[] memory pair = new address[](2);
        pair[0] = usdc;
        pair[1] = weth;
        (, uint256 feeTradingUsdc) = _selectBestPriceExchange(pair, amount);
        return feeTradingUsdc;
    }

    function _getAvailableLoans(uint amount) internal view returns (BorrowInfo[] memory loans) {
        uint borrowLimit = amount * borrowRateLimit / 100;
        try ILending(lendingContract).lendingPlatformsCount() returns(uint platformCount) {
            loans = new BorrowInfo[](platformCount);
            for (uint i = 0; i < platformCount; ++i) {
                loans[i] = _getAvailableLoan(i + 1, borrowLimit);
            }
        } catch {}
    }

    function _getAvailableLoan(uint platformIndex, uint borrowLimit) internal view returns (BorrowInfo memory loan) {
        uint borrowAmount = ILending(lendingContract).getBorrowableAmount(platformIndex, usdc);
        if (borrowAmount > borrowLimit)
            borrowAmount = borrowLimit;
        loan = BorrowInfo(platformIndex, borrowAmount, block.timestamp, block.number);
    }

    function _calculateProfit(
        address user,
        uint256 amount,
        FeeInfo memory fee,
        TradeInfo memory trade,
        BorrowInfo memory loan
    ) internal view returns (ProfitInfo memory profit) {
        profit.expiryDate = IFutureContract(trade.futureContract).expiryDate();
        if (profit.expiryDate > block.timestamp) {
            address[] memory pairs = _getPairs(trade.futureContract);
            if (pairs[0] != address(0)) {
                if (amount > fee.trading) {
                    uint tradeAmount = amount - fee.trading;
                    uint revenue = _getRevenue(tradeAmount, profit.expiryDate, pairs, trade);
                    if (revenue > amount) {
                        profit.amount = revenue - amount;
                    }
                    if (loan.platformIndex > 0) {
                        tradeAmount += loan.amount;
                        if (userBorrowInfo[user][trade.futureContract].length == 0) {
                            if (tradeAmount > fee.lending) {
                                tradeAmount -= fee.lending;
                            } else {
                                return profit;
                            }
                        }
                        revenue = _getRevenue(tradeAmount, profit.expiryDate, pairs, trade);
                        uint debt = _getDebtAmount(loan, profit.expiryDate, 0);
                        if (revenue > amount + debt) {
                            uint profitLoan = revenue - amount - debt;
                            if (profitLoan > profit.amount) {
                                profit.amount = profitLoan;
                                profit.debt = debt;
                            }
                        }
                    }
                }
            }
        }
    }

    function _getPairs(address futureContract) internal view returns (address[] memory pairs) {
        address token0 = IFutureContract(futureContract).token0();
        address token1 = IFutureContract(futureContract).token1();
        pairs = new address[](2);
        if (token0 == usdc || token1 == usdc) {
            (pairs[0], pairs[1]) = token0 == usdc ? (usdc, token1) : (usdc, token0);
        }
    }

    function _getRevenue(uint amount, uint expiryDate, address[] memory pairs, TradeInfo memory trade)
        internal view returns (uint revenue)
    {
        IExchangeRouter exchange = IExchangeRouter(trade.exchange);
        IFutureExchangeRouter futureExchange = IFutureExchangeRouter(trade.futureExchange);
        try exchange.getAmountsOut(amount, pairs) returns(uint[] memory amountsOut) {
            try futureExchange.getAmountsOutFuture(amountsOut[1], pairs[1], usdc, expiryDate) returns(uint _revenue) {
                revenue = _revenue;
            } catch {}
        } catch {}
    }

    function _getDebtAmount(BorrowInfo memory loan, uint endTime, uint endBlock) internal view returns(uint) {
        return ILending(lendingContract).getDebtAmount(
            loan.platformIndex, usdc, loan.amount,
            loan.startTime, endTime, loan.startBlock, endBlock);
    }

    function invest(
        address user,
        uint256 amount,
        TradeInfo memory trade,
        uint256 platformIndex,
        uint256 borrowAmount
    ) external {
        require(availableAmount[user] >= amount, "JanexV2: AVAILABLE_AMOUNT_NOT_ENOUGH");
        FeeInfo memory fee = FeeInfo(_swapFee(feeTradingByEth), _convertEthToUsdc(feeLendingByEth));
        BorrowInfo memory loan = _getBorrowForTrade(amount, borrowAmount, platformIndex);
        ProfitInfo memory profit = _calculateProfit(user, amount, fee, trade, loan);
        require(profit.amount > 0, "JanexV2: NOT_PROFITABLE");

        uint tradeAmount = amount - fee.trading;
        if (profit.debt > 0) {
            uint interest = profit.debt - loan.amount;
            ILending(lendingContract).createLoan(platformIndex, usdc, loan.amount);
            emit Borrow(user, trade.futureContract, loan.platformIndex, loan.amount, interest, fee.lending);

            tradeAmount += loan.amount;
            if (userBorrowInfo[user][trade.futureContract].length == 0) {
                tradeAmount -= _swapFee(feeLendingByEth);
            }
            userBorrowInfo[user][trade.futureContract].push(loan);
        }

        uint revenue = _executeTrade(tradeAmount, profit.expiryDate, trade);
        require(revenue > amount + profit.debt, "JanexV2: NOT_PROFITABLE");
        profit.amount = revenue - amount - profit.debt;

        _updateTradingAmount(user, trade.futureContract, amount, revenue);
        _removeTradingUser(user);

        emit Trade(user, trade.futureContract, profit.expiryDate,
            amount, profit.amount, fee.trading, block.timestamp);
    }

    function _getBorrowForTrade(uint amount, uint borrowAmount, uint platformIndex)
        internal view returns (BorrowInfo memory loan)
    {
        if (platformIndex != 0) {
            uint256 borrowLimit = amount * borrowRateLimit / 100;
            loan = _getAvailableLoan(platformIndex, borrowLimit);
            require(borrowAmount <= loan.amount, "JanexV2: BORROW_AMOUNT_EXCEED_LIMIT");
            loan.amount = borrowAmount;
        }
    }

    function _executeTrade(uint amount, uint expiryDate, TradeInfo memory trade) internal returns(uint) {
        address[] memory pairs = _getPairs(trade.futureContract);
        uint256[] memory amounts = IExchangeRouter(trade.exchange).getAmountsOut(amount, pairs);

        uint allowance = IERC20(pairs[1]).allowance(address(this), trade.futureExchange);
        if (allowance < amounts[1]) {
            IERC20(pairs[1]).approve(trade.futureExchange, type(uint256).max);
        }

        // Swap USDC->Token
        IExchangeRouter exchange = IExchangeRouter(trade.exchange);
        exchange.swapExactTokensForTokens(amount, amounts[1], pairs, address(this), expiryDate);
        // Swap Token->USDC Future
        IFutureExchangeRouter futureExchange = IFutureExchangeRouter(trade.futureExchange);
        return futureExchange.swapFuture(pairs[1], pairs[0], expiryDate, address(this), amounts[1]);
    }

    function _updateTradingAmount(address user, address futureContract, uint amount, uint revenue) internal {
        totalTradingAmount[user] += amount;
        tradingAmount[user][futureContract] += amount;
        investAmount[user] += amount;
        availableAmount[user] -= amount;
        revenueAmount[user][futureContract] += revenue;
    }

    function claimAirdrop() external {
        require(airdropReceiverCount > 0, "Janex: CANNOT_RECEIVE_AIRDROP");
        require(isAirdropReceiver[msg.sender] == true, "Janex: USER_CANNOT_RECEIVE_AIRDROP");
        uint256 airdropAmountReturn = airdropAmount / airdropReceiverCount;
        IERC20(usdc).transfer(msg.sender, airdropAmountReturn);
        isAirdropReceiver[msg.sender] = false;
        airdropReceiverCount--;
        airdropAmount -= airdropAmountReturn;
        emit Airdrop(msg.sender, airdropAmountReturn, block.timestamp);
    }

    function airdrop(address[] memory users) external onlyAdmin {
        require(airdropReceiverCount > 0, "Janex: CANNOT_RECEIVE_AIRDROP");
        uint256 airdropAmountReturn = airdropAmount / airdropReceiverCount;
        uint256 countAirdropUserSuccess = 0;
        for(uint i = 0; i < users.length; i++) 
        {
            if(isAirdropReceiver[users[i]] == true){
                IERC20(usdc).transfer(users[i], airdropAmountReturn);
                isAirdropReceiver[users[i]] = false;
                countAirdropUserSuccess++;
                emit Airdrop(users[i], airdropAmountReturn, block.timestamp);
            }
        }
        airdropReceiverCount -= countAirdropUserSuccess;
        airdropAmount -= (airdropAmountReturn * countAirdropUserSuccess);
    }

}
