const FutureTokenFactory = artifacts.require("FutureTokenFactory");
const FutureExchangeRouter = artifacts.require("FutureExchangeRouter");
const ERC20 = artifacts.require("ERC20");
const {
    USDC, WETH, FUTURE_EXPIRY_DATE,
    FUTURE_TOKEN_FACTORY, FUTURE_EXCHANGE_ROUTER,
    DO_ADD_LIQUIDITY, WETH_LIQUIDITY, USDC_LIQUIDITY,
} = require('../config/config.json');
const moment = require('moment');
const { BigNumber } = require('bignumber.js');

module.exports = async function (deployer, network, accounts) {

    let futureTokenFactory;
    let futureTokenFactoryAddress = FUTURE_TOKEN_FACTORY;
    if (futureTokenFactoryAddress) {
        futureTokenFactory = await FutureTokenFactory.at(FUTURE_TOKEN_FACTORY);
    } else {
        await deployer.deploy(FutureTokenFactory);
        futureTokenFactory = await FutureTokenFactory.deployed();
        futureTokenFactoryAddress = futureTokenFactory.address;
    }

    let futureExchangeRouter;
    let futureExchangeRouterAddress = FUTURE_EXCHANGE_ROUTER;
    if (futureExchangeRouterAddress) {
        futureExchangeRouter = await FutureExchangeRouter.at(FUTURE_EXCHANGE_ROUTER);
    } else {
        await deployer.deploy(FutureExchangeRouter, futureTokenFactoryAddress, WETH);
        futureExchangeRouter = await FutureExchangeRouter.deployed();
        futureExchangeRouterAddress = futureExchangeRouter.address;
    }

    console.log();
    console.log("Deployed Future Token Factory:", futureTokenFactoryAddress);
    console.log("Deployed Future Exchange Router:", futureExchangeRouterAddress);

    const exchange = await futureTokenFactory.exchange();
    if (exchange != futureExchangeRouterAddress) {
        await futureTokenFactory.setExchange(futureExchangeRouterAddress);
        console.log('Done - Set Exchange for Future Token Factory');
    }

    if (DO_ADD_LIQUIDITY) {
        const weth = await ERC20.at(WETH);
        const wethAllowance = await weth.allowance(accounts[0], futureExchangeRouterAddress);
        const wethLiquidity = new BigNumber(WETH_LIQUIDITY).times(1e18);
        if (new BigNumber(wethAllowance).lt(wethLiquidity)) {
            await weth.approve(futureExchangeRouterAddress, '10000000000000000000');
            console.log('Done - Approve WETH for Future Exchange Router');
        }

        const usdc = await ERC20.at(USDC);
        const usdcAllowance = await usdc.allowance(accounts[0], futureExchangeRouterAddress);
        const usdcLiquidity = new BigNumber(USDC_LIQUIDITY).times(1e6);
        if (new BigNumber(usdcAllowance).lt(usdcLiquidity)) {
            await usdc.approve(futureExchangeRouterAddress, '10000000000000');
            console.log('Done - Approve USDC for Future Exchange Router');
        }

        const expiryDate = FUTURE_EXPIRY_DATE ? FUTURE_EXPIRY_DATE : moment().add(30, 'day').unix();
        await futureExchangeRouter.addLiquidityFuture(WETH, USDC, wethLiquidity, usdcLiquidity, expiryDate, expiryDate.toString());
        console.log(`Done - Add liquidity WETH-USDC-${expiryDate} for Future Exchange Router`);
    }

    console.log();
};
