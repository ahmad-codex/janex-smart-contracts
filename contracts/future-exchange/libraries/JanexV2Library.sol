pragma solidity ^0.8.0;

import "../../future-token/interfaces/IFutureTokenFactory.sol";
import "../../future-token/interfaces/IFutureToken.sol";

import "../../common/interfaces/IERC20.sol";

import "./SafeMath.sol";

library JanexV2Library {
    using SafeMath for uint256;

    // returns sorted token addresses, used to handle return values from pairs sorted in this 
    function sortTokens(address tokenA, address tokenB)
        internal
        pure
        returns (address token0, address token1)
    {
        require(tokenA != tokenB, "JanexV2Library: IDENTICAL_ADDRESSES");
        (token0, token1) = tokenA < tokenB
            ? (tokenA, tokenB)
            : (tokenB, tokenA);
        require(token0 != address(0), "JanexV2Library: ZERO_ADDRESS");
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(
        address factory,
        address tokenA,
        address tokenB
    ) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(
            bytes20(
                keccak256(
                    abi.encodePacked(
                        hex"ff",
                        factory,
                        keccak256(abi.encodePacked(token0, token1)),
                        hex"8bbe3b87a8ff316d03607692c9e315540483dd03b2a3eff7147a4e04f4503f25" // init code hash
                    )
                )
            )
        );
    }    

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) internal pure returns (uint256 amountB) {
        require(amountA > 0, "JanexV2Library: INSUFFICIENT_AMOUNT");
        require(reserveA > 0 && reserveB > 0, "JanexV2Library: INSUFFICIENT_LIQUIDITY");
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOutFuture(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountOut) {
        require(amountIn > 0, "JanexV2Library: INSUFFICIENT_INPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "JanexV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = amountIn.mul(reserveOut);
        uint256 denominator = reserveIn.add(amountIn);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountInFuture(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) internal pure returns (uint256 amountIn) {
        require(amountOut > 0, "JanexV2Library: INSUFFICIENT_OUTPUT_AMOUNT");
        require(reserveIn > 0 && reserveOut > 0, "JanexV2Library: INSUFFICIENT_LIQUIDITY");
        uint256 numerator = reserveIn.mul(amountOut);
        uint256 denominator = reserveOut.sub(amountOut);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOutFuture(
        address factory,
        uint256 amountIn,
        address tokenIn,
        address tokenOut,
        uint256 deadline
    ) internal view returns (uint256 amountOut) {
        (uint256 reserveIn, uint256 reserveOut) = getReservesFuture(factory, tokenIn, tokenOut, deadline);
        amountOut = getAmountOutFuture(amountIn, reserveIn, reserveOut);
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsInFuture(
        address factory,
        uint256 amountOut,
        address tokenIn,
        address tokenOut,
        uint256 deadline
    ) internal view returns (uint256 amountIn) {
        (uint256 reserveIn, uint256 reserveOut) = getReservesFuture(factory, tokenIn, tokenOut, deadline);
        amountIn = getAmountInFuture(amountOut, reserveIn, reserveOut);
    }

    // fetches and sorts the reserves for a pair
    function getReservesFuture(
        address factory,
        address tokenA,
        address tokenB,
        uint256 deadline
    ) internal view returns (uint256 reserveA, uint256 reserveB) {
        address futureContract = IFutureTokenFactory(factory).getFutureContract(tokenA, tokenB, deadline);
        reserveA = IERC20(tokenA).balanceOf(futureContract);
        reserveB = IERC20(tokenB).balanceOf(futureContract);
    }
}
