pragma solidity ^0.8.0;

import "./interfaces/IFutureExchangeRouter.sol";
import "../future-token/interfaces/IFutureTokenFactory.sol";
import "../future-token/interfaces/IFutureToken.sol";
import "../common/interfaces/IERC20.sol";
import "./libraries/JanexV2Library.sol";
import "./libraries/SafeMath.sol";
import "../LiquidityToken/interfaces/ILiquidityToken.sol";
import "../LiquidityToken/LiquidityToken.sol";
import "../future-token/interfaces/IFutureContract.sol";


contract FutureExchangeRouter is IFutureExchangeRouter{
    using SafeMath for uint256;

    address public override futureTokenFactory;
    address public weth;

    mapping(address => address[]) listFutureContractsInPair;
    mapping(address => address) getLiquidityToken;

    constructor(address _futureTokenFactory, address _weth) {
        futureTokenFactory = _futureTokenFactory;
        weth = _weth;
    }

    receive() external payable {
        assert(msg.sender == weth); // only accept ETH via fallback from the WETH contract
    }

    function getListFutureContractsInPair(address token)
        external
        view
        override
        returns (address[] memory)
    {
        return listFutureContractsInPair[token];
    }

    function isFutureContract(
        address tokenA,
        address tokenB,
        uint256 expiryDate
    ) internal view returns (address) {
        address futureContract = IFutureTokenFactory(futureTokenFactory).getFutureContract(tokenA, tokenB, expiryDate);
        require(futureContract != address(0), "Future Exchange Router: FUTURE_TOKEN_DOES_NOT_EXISTS");
        return futureContract;
    }

    function addLiquidityFuture(
        address tokenA,
        address tokenB,
        uint256 amountA,
        uint256 amountB,
        uint256 expiryDate,
        string memory expirySymbol
    ) external override {
        address futureContract = IFutureTokenFactory(futureTokenFactory).getFutureContract(tokenA, tokenB, expiryDate);
        if (futureContract == address(0)) {
            futureContract = IFutureTokenFactory(futureTokenFactory).createFuture(tokenA, tokenB, expiryDate, expirySymbol);
            listFutureContractsInPair[tokenA].push(futureContract);
            listFutureContractsInPair[tokenB].push(futureContract);
        }
        
        uint256 reserveA = IERC20(tokenA).balanceOf(futureContract);
        uint256 reserveB = IERC20(tokenB).balanceOf(futureContract);
        if (reserveA != 0 && reserveB != 0) {
            require(
                amountB == JanexV2Library.quote(amountA, reserveA, reserveB),
                "Future Exchange Router: LIQUIDITY_AMOUNT_INVALID"
            );
        }

        address liquidityToken = getLiquidityToken[futureContract];
        if (liquidityToken == address(0)) {
            getLiquidityToken[futureContract] = liquidityToken = address(new LiquidityToken());
        }
        
        uint256 liquiditySupply = ILiquidityToken(liquidityToken).totalSupply();
        uint256 liquidityAmount = liquiditySupply == 0
            ? sqrt(amountA * amountB)
            : (liquiditySupply * amountA) / reserveA;        
        ILiquidityToken(liquidityToken).mint(msg.sender, liquidityAmount);

        IERC20(tokenA).transferFrom(msg.sender, futureContract, amountA);
        IERC20(tokenB).transferFrom(msg.sender, futureContract, amountB);
    }
    
    function withdrawLiquidityFuture(
        address tokenA,
        address tokenB,
        uint256 expiryDate,         
        address to,
        uint256 amountLiquidity
    ) override external {
        address futureContract = IFutureTokenFactory(futureTokenFactory).getFutureContract(tokenA, tokenB, expiryDate);
        address liquidityToken = getLiquidityToken[futureContract];
        uint256 liquidityTokenSupply = ILiquidityToken(liquidityToken).totalSupply();
        
        ILiquidityToken(liquidityToken).transferFrom(msg.sender, address(this), amountLiquidity);
        ILiquidityToken(liquidityToken).burn(amountLiquidity);
        
        uint256 reserveA = IERC20(tokenA).balanceOf(futureContract);
        uint256 reserveB = IERC20(tokenB).balanceOf(futureContract);
        
        uint256 amountA = (reserveA * amountLiquidity) / liquidityTokenSupply;
        uint256 amountB = (reserveB * amountLiquidity) / liquidityTokenSupply;

        IERC20(tokenA).transferFrom(futureContract, to, amountA);
        IERC20(tokenB).transferFrom(futureContract, to, amountB);
    }

    function sqrt(uint256 x) internal pure returns (uint256) {
        uint256 n = x / 2;
        uint256 lstX = 0;
        while (n != lstX) {
            lstX = n;
            n = (n + x / n) / 2;
        }
        return uint256(n);
    }

    function swapFuture(
        address tokenIn,
        address tokenOut,
        uint256 expiryDate,
        address to,
        uint256 amountIn
    ) external override returns(uint amountOut) {
        address futureContract = isFutureContract(tokenIn, tokenOut, expiryDate);
        amountOut = getAmountsOutFuture(amountIn, tokenIn, tokenOut, expiryDate);
        address futureToken = IFutureTokenFactory(futureTokenFactory).getFutureToken(tokenIn, tokenOut, expiryDate);
        uint256 amountMint = getAmountMint(futureToken, tokenOut, amountOut);
        IERC20(tokenIn).transferFrom(msg.sender, futureContract, amountIn);
        IERC20(tokenOut).transferFrom(futureContract, address(this), amountOut);
        IFutureTokenFactory(futureTokenFactory).mintFuture(tokenIn, tokenOut, expiryDate, to, amountMint);
    }

    function closeFuture(
        address tokenIn,
        address tokenOut,
        uint256 expiryDate,
        address to,
        uint256 amountOut
    ) external override {
        address futureToken = IFutureTokenFactory(futureTokenFactory).getFutureToken(tokenIn, tokenOut, expiryDate);
        uint256 amountMinted = getAmountMint(futureToken, tokenOut, amountOut);
        IERC20(futureToken).transferFrom(msg.sender, futureTokenFactory, amountMinted);
        IFutureTokenFactory(futureTokenFactory).burnFuture(tokenIn, tokenOut, expiryDate, amountMinted);
        IERC20(tokenOut).transfer(to, amountOut);
    }

    function getAmountMint(
        address futureToken,
        address tokenOut,
        uint256 amountOut
    ) internal view returns (uint256 amountMint) {
        amountMint = amountOut;
        uint256 decimalFuture = IERC20(futureToken).decimals();
        uint256 decimalOut = IERC20(tokenOut).decimals();
        if (decimalFuture > decimalOut)
            amountMint *= 10 ** (decimalFuture - decimalOut);
        if (decimalFuture < decimalOut)
            amountMint /= 10 ** (decimalOut - decimalFuture);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(
        uint256 amount, 
        address tokenIn, 
        address tokenOut, 
        uint256 expiryDate
    ) public view returns(uint) {
        address futureContract = IFutureTokenFactory(futureTokenFactory).getFutureContract(tokenIn, tokenOut, expiryDate);
        uint256 reserveIn = IERC20(tokenIn).balanceOf(futureContract);
        uint256 reserveOut = IERC20(tokenOut).balanceOf(futureContract);
        if (reserveIn != 0 && reserveOut != 0) {
            return JanexV2Library.quote(amount, reserveIn, reserveOut);
        }
        return 0;
    }

    function getAmountsOutFuture(
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint256 deadline
    ) public view override returns (uint) {
        return JanexV2Library.getAmountsOutFuture(futureTokenFactory, amountIn, tokenIn, tokenOut, deadline);
    }

    function getAmountsInFuture(
        uint256 amountOut,
        address tokenIn,
        address tokenOut,
        uint256 deadline
    ) public view override returns (uint) {
        return JanexV2Library.getAmountsInFuture(futureTokenFactory, amountOut, tokenIn, tokenOut, deadline);
    }
}
