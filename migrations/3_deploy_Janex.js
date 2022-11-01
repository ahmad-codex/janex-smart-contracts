const Janex = artifacts.require("Janex");
const Lending = artifacts.require("Lending");
const FutureExchangeRouter = artifacts.require("FutureExchangeRouter");
const ERC20 = artifacts.require("ERC20");
const {
    USDC, WETH, LENDING, Janex,
    TRADING_SERVICE, ADMIN_ADDRESS,
    EXCHANGES, FUTURE_EXCHANGE_ROUTER,
    DO_DEPOSIT, USDC_DEPOSIT,
    DO_SET_FEE, FEE_TRADING, FEE_LENDING,
} = require('../config/config.json');
const { BigNumber } = require('bignumber.js');

module.exports = async function (deployer, network, accounts) {

    let Janex;
    let JanexAddress = Janex;
    if (JanexAddress) {
        Janex = await Janex.at(Janex);
    } else {
        const adminAddress = ADMIN_ADDRESS ? ADMIN_ADDRESS : accounts[0];
        const tradingService = TRADING_SERVICE ? TRADING_SERVICE : accounts[0];
        await deployer.deploy(Janex, USDC, WETH, tradingService, adminAddress);
        Janex = await Janex.deployed();
        JanexAddress = Janex.address;
    }
    console.log();
    console.log('Deployed Janex:', JanexAddress);

    const futureExchangeRouter = FUTURE_EXCHANGE_ROUTER
        ? await FutureExchangeRouter.at(FUTURE_EXCHANGE_ROUTER)
        : await FutureExchangeRouter.deployed();
    if (futureExchangeRouter) {
        if (!await Janex.isFutureExchange(futureExchangeRouter.address)) {
            await Janex.addFutureExchange(futureExchangeRouter.address);
            console.log('Done - Add Future Exchange for Janex:', futureExchangeRouter.address);
        }
    }

    if (EXCHANGES && EXCHANGES.length > 0) {
        for (const exchange of EXCHANGES) {
            if (!await Janex.isExchange(exchange)) {
                await Janex.addExchange(exchange);
                console.log('Done - Add Exchange for Janex:', exchange);
            }
        }
    }

    const lending = LENDING
        ? await Lending.at(LENDING)
        : await Lending.deployed();
    if (await Janex.lendingContract() != lending.address) {
        await Janex.setLending(lending.address);
        console.log('Done - Set Lending for Janex:', lending.address);
    }

    if (DO_DEPOSIT) {
        const usdc = await ERC20.at(USDC);
        const usdcAllowance = await usdc.allowance(accounts[0], JanexAddress);
        const usdcDeposit = new BigNumber(USDC_DEPOSIT).times(1e6);
        if (new BigNumber(usdcAllowance).lt(usdcDeposit)) {
            await usdc.approve(JanexAddress, '1000000000');
            console.log('Done - Approve USDC for Janex');
        }
        await Janex.deposit(usdcDeposit);
        console.log('Done - Deposit USDC to Janex');
    }

    if (DO_SET_FEE) {
        const feeTrading = new BigNumber(FEE_TRADING).times(1e18);
        await Janex.setFeeTradingByETH(feeTrading);
        console.log('Done - Set trading fee');

        const feeLending = new BigNumber(FEE_LENDING).times(1e18);
        await Janex.setFeeLendingByEth(feeLending);
        console.log('Done - Set lending fee');
    }

    console.log();
};
