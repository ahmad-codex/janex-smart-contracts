const Lending = artifacts.require("Lending");
const Converter = artifacts.require("Converter");
const ERC20 = artifacts.require("ERC20");
const {
    LENDING, CONVERTER, ADMIN_ADDRESS, PROVIDER_ADDRESS,
    USDC, USDC_AAVE, DAI, DAI_AAVE,
    AAVE_LENDING_POOL, COMPOUND_COMPTROLLER,
    COMPOUND_USDC, COMPOUND_DAI,
    DO_SEND_CONVERTER, USDC_CONVERTER, USDC_AAVE_CONVERTER,
    DO_SEND_COLLATERAL, DAI_COLLATERAL, DAI_AAVE_COLLATERAL,
} = require('../config/config.json');
const { BigNumber } = require('bignumber.js');

module.exports = async function (deployer, network, accounts) {

    let converter;
    let converterAddress = CONVERTER;
    if (converterAddress) {
        converter = await Converter.at(CONVERTER);
    } else {
        await deployer.deploy(Converter);
        converter = await Converter.deployed();
        converterAddress = converter.address;
    }

    let lending;
    let lendingAddress = LENDING;
    if (lendingAddress) {
        lending = await Lending.at(LENDING);
    } else {
        const admin = ADMIN_ADDRESS || accounts[0];
        const provider = PROVIDER_ADDRESS || accounts[0];
        await deployer.deploy(Lending, admin, provider);
        lending = await Lending.deployed();
        lendingAddress = lending.address;
    }

    console.log();
    console.log("Deployed Converter contract:", converterAddress);
    console.log("Deployed Lending contract:", lendingAddress);

    if (await lending.usdc() == '0x0000000000000000000000000000000000000000') {
        await lending.initiate(
            USDC, DAI, USDC_AAVE, DAI_AAVE, AAVE_LENDING_POOL,
            COMPOUND_COMPTROLLER, COMPOUND_USDC, COMPOUND_DAI
        );
        console.log('Done - Initiate Lending contract');
    }

    if (await lending.converter() != converterAddress) {
        await lending.setConverter(converterAddress);
        console.log('Done - Set Converter for Lending contract');
    }

    if (DO_SEND_COLLATERAL) {
        if (DAI_AAVE_COLLATERAL > 0) {
            const daiAave = await ERC20.at(DAI_AAVE);
            const daiAaveAllowance = await daiAave.allowance(accounts[0], lendingAddress);
            const daiAaveCollateral = new BigNumber(DAI_AAVE_COLLATERAL).times(1e18);
            if (new BigNumber(daiAaveAllowance).lt(daiAaveCollateral)) {
                await daiAave.approve(lendingAddress, '1000000000000000000000000');
                console.log('Done - Approve DAI AAVE for Lending');
            }
            await lending.sendCollateral(1, DAI_AAVE, daiAaveCollateral);
            console.log('Done - Send DAI collateral to AAVE');
        }

        if (DAI_COLLATERAL > 0) {
            const dai = await ERC20.at(DAI);
            const daiAllowance = await dai.allowance(accounts[0], lendingAddress);
            const daiCollateral = new BigNumber(DAI_COLLATERAL).times(1e18);
            if (new BigNumber(daiAllowance).lt(daiCollateral)) {
                await dai.approve(lendingAddress, '1000000000000000000000000');
                console.log('Done - Approve DAI for Lending');
            }
            await lending.sendCollateral(2, DAI, daiCollateral);
            console.log('Done - Send DAI collateral to Compound');
        }
    }

    if (DO_SEND_CONVERTER) {
        const usdc = await ERC20.at(USDC);
        if (USDC_CONVERTER > 0) {
            const usdcConvert = new BigNumber(USDC_CONVERTER).times(1e6);
            await usdc.transfer(converterAddress, usdcConvert);
            console.log('Done - Send USDC to Converter');
        }

        const usdcAave = await ERC20.at(USDC_AAVE);
        if (USDC_AAVE_CONVERTER > 0) {
            const usdcAaveConvert = new BigNumber(USDC_AAVE_CONVERTER).times(1e6);
            await usdcAave.transfer(converterAddress, usdcAaveConvert);
            console.log('Done - Send USDC AAVE to Converter');
        }
    }
    console.log();
};
