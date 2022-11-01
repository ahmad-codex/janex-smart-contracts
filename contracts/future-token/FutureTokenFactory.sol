pragma solidity ^0.8.0;

import "./FutureToken.sol";
import "./FutureContract.sol";
import "./interfaces/IFutureTokenFactory.sol";
import "../common/Ownable.sol";
import "../common/interfaces/IERC20.sol";

contract FutureTokenFactory is IFutureTokenFactory, Ownable {

    mapping(address => mapping(address => mapping(uint256 => address))) futureContract;

    address public override exchange;

    modifier onlyExchange() {
        require(msg.sender == exchange, "Future Token Factory: NOT_FROM_EXCHANGE");
        _;
    }

    function getFutureContract(address tokenA, address tokenB, uint256 expiryDate) public override view returns(address) {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        return futureContract[token0][token1][expiryDate];
    }

    function getFutureToken(address tokenIn, address tokenOut, uint256 expiryDate) public override view returns(address) {
        address futureContractAddress = getFutureContract(tokenIn, tokenOut, expiryDate);
        if (futureContractAddress != address(0)) {
           return futureTokenAddress(tokenIn, tokenOut, expiryDate);
        }
        return address(0);
    }

    function futureTokenAddress(address tokenIn, address tokenOut, uint256 expiryDate) internal view returns(address) {
        bytes memory bytecode = type(FutureToken).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(tokenIn, tokenOut, expiryDate));
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                salt,
                keccak256(bytecode)
            )
        );
        return address(uint160(uint256(hash)));
    }

    function createFuture(
        address tokenA,
        address tokenB,
        uint256 expiryDate,
        string memory expirySymbol
    ) external override onlyExchange returns (address future) {
        require(tokenA != tokenB, "Future Token Factory: TOKENS_IDENTICAL_ADDRESSES");
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), "Future Token Factory: TOKEN_ZERO_ADDRESS");
        require(futureContract[token0][token1][expiryDate] == address(0), "Future Token Factory: FUTURE_TOKEN_EXISTED");

        future = address(new FutureContract(token0, token1, expiryDate, exchange));
        createFutureToken(token0, token1, expiryDate, expirySymbol);
        createFutureToken(token1, token0, expiryDate, expirySymbol);
        futureContract[token0][token1][expiryDate] = future;
    }

    function createFutureToken(
        address tokenIn,
        address tokenOut,
        uint256 expiryDate,
        string memory expirySymbol
    ) internal returns (address futureTokenAddress) {
        bytes memory bytecode = type(FutureToken).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(tokenIn, tokenOut, expiryDate));
        assembly {
            futureTokenAddress := create2(0, add(bytecode, 0x20), mload(bytecode), salt)
        }
        FutureToken(futureTokenAddress).initialize(string(
            abi.encodePacked(
                IERC20(tokenIn).symbol(), "-",
                IERC20(tokenOut).symbol(), "-",
                expirySymbol
            )
        ));
    }

    function setExchange(address _exchange) external onlyOwner {
        exchange = _exchange;
    }

    function mintFuture(address tokenIn, address tokenOut, uint expiryDate, address to, uint amount) external override onlyExchange {
        address futureTokenAddress = getFutureToken(tokenIn, tokenOut, expiryDate);
        require(futureTokenAddress != address(0), "Future Token: INVALID");
        require(block.timestamp < expiryDate, "Future Token: MINT_AFTER_EXPIRY_DATE");
        FutureToken(futureTokenAddress).mint(to, amount);
    }

    function burnFuture(address tokenIn, address tokenOut, uint expiryDate, uint256 amount) external override onlyExchange {
        address futureTokenAddress = getFutureToken(tokenIn, tokenOut, expiryDate);
        require(futureTokenAddress != address(0), "Future Token: INVALID");
        require(block.timestamp >= expiryDate, "Future Token: BURN_BEFORE_EXPIRY_DATE");
        FutureToken(futureTokenAddress).burn(amount);
    }
}
