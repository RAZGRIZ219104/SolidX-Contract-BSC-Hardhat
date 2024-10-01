// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface IPancakeswapV3Factory {
    /// @notice Emitted when the owner of the factory is changed
    /// @param oldOwner The owner before the owner was changed
    /// @param newOwner The owner after the owner was changed
    event OwnerChanged(address indexed oldOwner, address indexed newOwner);

    /// @notice Emitted when a pool is created
    /// @param token0 The first token of the pool by address sort order
    /// @param token1 The second token of the pool by address sort order
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @param tickSpacing The minimum number of ticks between initialized ticks
    /// @param pool The address of the created pool
    event PoolCreated(
        address indexed token0,
        address indexed token1,
        uint24 indexed fee,
        int24 tickSpacing,
        address pool
    );

    /// @notice Emitted when a new fee amount is enabled for pool creation via the factory
    /// @param fee The enabled fee, denominated in hundredths of a bip
    /// @param tickSpacing The minimum number of ticks between initialized ticks for pools created with the given fee
    event FeeAmountEnabled(uint24 indexed fee, int24 indexed tickSpacing);

    /// @notice Returns the current owner of the factory
    /// @dev Can be changed by the current owner via setOwner
    /// @return The address of the factory owner
    function owner() external view returns (address);

    /// @notice Returns the tick spacing for a given fee amount, if enabled, or 0 if not enabled
    /// @dev A fee amount can never be removed, so this value should be hard coded or cached in the calling context
    /// @param fee The enabled fee, denominated in hundredths of a bip. Returns 0 in case of unenabled fee
    /// @return The tick spacing
    function feeAmountTickSpacing(uint24 fee) external view returns (int24);

    /// @notice Returns the pool address for a given pair of tokens and a fee, or address 0 if it does not exist
    /// @dev tokenA and tokenB may be passed in either token0/token1 or token1/token0 order
    /// @param tokenA The contract address of either token0 or token1
    /// @param tokenB The contract address of the other token
    /// @param fee The fee collected upon every swap in the pool, denominated in hundredths of a bip
    /// @return pool The pool address
    function getPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external view returns (address pool);

    /// @notice Creates a pool for the given two tokens and fee
    /// @param tokenA One of the two tokens in the desired pool
    /// @param tokenB The other of the two tokens in the desired pool
    /// @param fee The desired fee for the pool
    /// @dev tokenA and tokenB may be passed in either order: token0/token1 or token1/token0. tickSpacing is retrieved
    /// from the fee. The call will revert if the pool already exists, the fee is invalid, or the token arguments
    /// are invalid.
    /// @return pool The address of the newly created pool
    function createPool(address tokenA, address tokenB, uint24 fee) external returns (address pool);

    /// @notice Updates the owner of the factory
    /// @dev Must be called by the current owner
    /// @param _owner The new owner of the factory
    function setOwner(address _owner) external;

    /// @notice Enables a fee amount with the given tickSpacing
    /// @dev Fee amounts may never be removed once enabled
    /// @param fee The fee amount to enable, denominated in hundredths of a bip (i.e. 1e-6)
    /// @param tickSpacing The spacing between ticks to be enforced for all pools created with the given fee amount
    function enableFeeAmount(uint24 fee, int24 tickSpacing) external;
}

interface IPancakeswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IPancakeswapV3Pool {
    function slot0()
        external
        view
        returns (
            uint160 sqrtPriceX96,
            int24 tick,
            uint16 observationIndex,
            uint16 observationCardinality,
            uint16 observationCardinalityNext,
            uint8 feeProtocol,
            bool unlocked
        );

    function feeGrowthGlobal0X128() external view returns (uint256);

    function feeGrowthGlobal1X128() external view returns (uint256);

    function protocolFees() external view returns (uint128 token0, uint128 token1);

    function liquidity() external view returns (uint128);

    function ticks(
        int24 tick
    )
        external
        view
        returns (
            uint128 liquidityGross,
            int128 liquidityNet,
            uint256 feeGrowthOutside0X128,
            uint256 feeGrowthOutside1X128,
            int56 tickCumulativeOutside,
            uint160 secondsPerLiquidityOutsideX128,
            uint32 secondsOutside,
            bool initialized
        );

    function tickBitmap(int16 wordPosition) external view returns (uint256);

    function positions(
        bytes32 key
    )
        external
        view
        returns (
            uint128 _liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    function observations(
        uint256 index
    )
        external
        view
        returns (
            uint32 blockTimestamp,
            int56 tickCumulative,
            uint160 secondsPerLiquidityCumulativeX128,
            bool initialized
        );

    function token0() external view returns (address);

    function token1() external view returns (address);
}

interface IPancakeswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

interface IPancakeswapV2Router01 {
    function factory() external pure returns (address);
    function WBNB() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);
    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);
    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountIn);
    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
    function getAmountsIn(
        uint amountOut,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

interface IPancakeswapV2Router02 is IPancakeswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

library Quote {

    // For BSC
    address public constant pancakeswapFactoryV2 = 0xcA143Ce32Fe78f1f7019d7d551a6402fC5350c73; // pancakeswapFactoryV2
    address public constant pancakeswapFactoryV3 = 0x0BFbCF9fa4f9C56B0F40a671Ad40E0805A091865; // pancakeswapFactoryV3
    address public constant pancakeswapV2Router02 = 0x10ED43C718714eb63d5aA57B78B54704E256024E; // pancakeswap Router V2
    address public constant USDC = 0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d;
    address public constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c; // WBNB in fact
    // address public constant WBTC = 0xA01b9cAFE2230093fbf0000B43701E03717F77cE; // not sure
    address public constant DAI = 0x1AF3F329e8BE154074D8769D1FFa4eE058B1DBc3;
    address public constant SDX = 0xA76A6cC7fa9ab055b6101d443FD975520eb8cC75;

    function _quoteTo(address origin, address to, uint256 amount) internal view returns (uint256) {
        if (amount == 0) return amount;
        // Find v3 pool
        // uint16[4] memory fees = [3000, 500, 10000, 100];
        // for (uint8 i = 0; i < fees.length; i++) {
        //     address pool = IPancakeswapV3Factory(pancakeswapFactoryV3).getPool(origin, to, fees[i]);
        //     if (pool != address(0)) {
        //         (uint160 sqrtPriceX96, , , , , , ) = IPancakeswapV3Pool(pool).slot0();
        //         if (IPancakeswapV3Pool(pool).token0() == origin) {
        //             return
        //                 (amount * (sqrtPriceX96 * 2 ** 96) ** 2 * 10 ** ERC20(origin).decimals()) /
        //                 10 ** ERC20(to).decimals();
        //         } else {
        //             return
        //                 (amount * 10 ** ERC20(to).decimals()) /
        //                 (sqrtPriceX96 * 2 ** 96) ** 2 /
        //                 10 ** ERC20(origin).decimals();
        //         }
        //     }
        // }
        // Find v2 pool
        address pair = IPancakeswapV2Factory(pancakeswapFactoryV2).getPair(origin, to);
        if (pair != address(0)) {
            uint256 reserve0;
            uint256 reserve1;
            if (IPancakeswapV2Pair(pair).token0() == origin) {
                (reserve0, reserve1, ) = IPancakeswapV2Pair(pair).getReserves();
            } else {
                (reserve1, reserve0, ) = IPancakeswapV2Pair(pair).getReserves();
            }
            return IPancakeswapV2Router02(pancakeswapV2Router02).quote(amount, reserve0, reserve1);
        }
        return 0;
    }

    function _quoteWBNBToSDX(uint256 amount) internal view returns (uint256) {
        if (amount == 0) return amount;

        address pair = IPancakeswapV2Factory(pancakeswapFactoryV2).getPair(WBNB, SDX);
        if (pair != address(0)) {
            uint256 reserve0;
            uint256 reserve1;
            if (IPancakeswapV2Pair(pair).token0() == WBNB) {
                (reserve0, reserve1, ) = IPancakeswapV2Pair(pair).getReserves();
            } else {
                (reserve1, reserve0, ) = IPancakeswapV2Pair(pair).getReserves();
            }
            return IPancakeswapV2Router02(pancakeswapV2Router02).quote(amount, reserve0, reserve1);
        }
        return 0;
    }

    function quoteToSDX(address origin, uint256 amount) public view returns (uint256) {
        if (amount == 0) return amount;

        uint256 quotedAmount;
        if (origin == SDX) return amount;
        if (origin == WBNB) return _quoteWBNBToSDX(amount);
        if (origin == USDC || origin == USDT || origin == DAI) {
            quotedAmount = _quoteTo(origin, WBNB, amount);
            if (quotedAmount > 0) return _quoteWBNBToSDX(quotedAmount);
        }

        quotedAmount = _quoteTo(origin, WBNB, amount);
        if (quotedAmount > 0) return _quoteWBNBToSDX(quotedAmount);

        quotedAmount = _quoteTo(origin, USDC, amount);
        quotedAmount = _quoteTo(USDC, WBNB, quotedAmount);
        if (quotedAmount > 0) return _quoteWBNBToSDX(quotedAmount);

        // quotedAmount = _quoteTo(origin, WBTC, amount);
        // quotedAmount = _quoteTo(WBTC, WBNB, quotedAmount);
        // if (quotedAmount > 0) return _quoteWBNBToSDX(quotedAmount);

        quotedAmount = _quoteTo(origin, USDT, amount);
        quotedAmount = _quoteTo(USDT, WBNB, quotedAmount);
        if (quotedAmount > 0) return _quoteWBNBToSDX(quotedAmount);

        quotedAmount = _quoteTo(origin, DAI, amount);
        quotedAmount = _quoteTo(DAI, WBNB, quotedAmount);
        if (quotedAmount > 0) return _quoteWBNBToSDX(quotedAmount);

        return 0;
    }
}
