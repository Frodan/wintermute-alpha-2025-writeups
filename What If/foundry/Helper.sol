// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "./interfaces/IBalancerVault.sol";
import "./interfaces/ICurvePool.sol";
import "./interfaces/IERC20.sol";
import "./interfaces/IWETH.sol";
import "./interfaces/IAAVE.sol";
import "./interfaces/IwstETH.sol";
import "./interfaces/ICrvUSDPool.sol";
import "./interfaces/ITricryptoPool.sol";
import "./interfaces/IUniswapV3Pool.sol";
import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Router.sol";
import "./interfaces/IAAVEV3.sol";

contract Helper {
    // Protocol interfaces
    IBalancerVault private constant BALANCER = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    IAAVE private constant AAVE_V2 = IAAVE(0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9);
    IAAVEV3 private constant AAVE_V3 = IAAVEV3(0x87870Bca3F3fD6335C3F4ce8392D69350B4fA4E2);
    IUniswapV2Router private constant UNI_V2_ROUTER = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    
    // Token interfaces
    IWETH private constant WETH = IWETH(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 private constant STETH = IERC20(0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84);
    IwstETH private constant WSTETH = IwstETH(0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0);
    IERC20 private constant CRVUSD = IERC20(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);
    IERC20 private constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    
    // Pool interfaces
    ICurvePool private constant STETH_NG_POOL = ICurvePool(0x21E27a5E5513D6e65C4f830167390997aA84843a);
    ICurvePool private constant CURVE_STETH_ETH_POOL = ICurvePool(0xDC24316b9AE028F1497c275EB9192a3Ea0f67022);
    ICrvUSDPool private constant CRVUSD_ETH_POOL = ICrvUSDPool(0x1681195C176239ac5E72d9aeBaCf5b2492E0C4ee);
    ITricryptoPool private constant CURVE_TRICRYPTO_LLAMA_POOL = ITricryptoPool(0x2889302a794dA87fBF1D6Db415C1492194663D13);
    IUniswapV3Pool private constant UNI_V3_WSTETH_WETH_POOL = IUniswapV3Pool(0x109830a1AAaD605BbF02a9dFA7B0B92EC2FB7dAa);
    IUniswapV2Pair private constant UNI_V2_STETH_WETH_POOL = IUniswapV2Pair(0x4028DAAC072e492d34a3Afdbef0ba7e35D8b55C4);
    
    uint160 private constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970341;
    
    function executeFlashLoan(uint256 amount) external payable {
        address[] memory tokens = new address[](1);
        uint256[] memory amounts = new uint256[](1);
        
        tokens[0] = address(WETH);
        amounts[0] = amount;
        
        BALANCER.flashLoan(address(this), tokens, amounts, "");
    }
    
    function receiveFlashLoan(
        address[] memory,
        uint256[] memory amounts,
        uint256[] memory,
        bytes memory
    ) external {
        require(msg.sender == address(BALANCER), "Invalid caller");
        
        uint256 flashloanAmount = amounts[0];
        
        WETH.withdraw(flashloanAmount);
        uint256 stethAmount = STETH_NG_POOL.exchange{value: flashloanAmount}(0, 1, flashloanAmount, 0);
        
        STETH.approve(address(AAVE_V2), stethAmount);
        AAVE_V2.deposit(address(STETH), stethAmount, address(this), 0);
        
        AAVE_V2.borrow(address(WETH), flashloanAmount, 2, 0, address(this));
        WETH.transfer(address(BALANCER), flashloanAmount);
    }

    function borrowFromAave(address token, uint256 amount) external {
        AAVE_V2.borrow(token, amount, 2, 0, address(this));
    }
    
    function depositStethToAave(uint256 wethAmount) external {
        WETH.withdraw(wethAmount);
        uint256 stethAmount = CURVE_STETH_ETH_POOL.exchange{value: wethAmount}(0, 1, wethAmount, 0);
        
        STETH.approve(address(AAVE_V2), stethAmount);
        AAVE_V2.deposit(address(STETH), stethAmount, address(this), 0);
    }
    
    function swapWethToWsteth(uint256 wethAmount) external {
        WETH.approve(address(UNI_V3_WSTETH_WETH_POOL), wethAmount);
        
        UNI_V3_WSTETH_WETH_POOL.swap(
            address(this),
            false, // WETH->wstETH
            int256(wethAmount),
            MAX_SQRT_RATIO,
            ""
        );
    }
    
    function swapWethToStethUniV2(uint256 wethAmount) external {
        WETH.approve(address(UNI_V2_ROUTER), wethAmount);
        
        address[] memory path = new address[](2);
        path[0] = address(WETH);
        path[1] = address(STETH);
        
        UNI_V2_ROUTER.swapExactTokensForTokens(
            wethAmount,
            0, // accept any amount of STETH
            path,
            address(this),
            block.timestamp + 300
        );
    }
    
    function swapWethToCrvUSDToWsteth(uint256 wethAmount) external returns (uint256, uint256) {
        WETH.approve(address(CRVUSD_ETH_POOL), wethAmount);
        CRVUSD_ETH_POOL.exchange(1, 0, wethAmount, 0);
        
        uint256 crvusdBalance = CRVUSD.balanceOf(address(this));
        
        CRVUSD.approve(address(CURVE_TRICRYPTO_LLAMA_POOL), crvusdBalance);
        uint256 wstethReceived = CURVE_TRICRYPTO_LLAMA_POOL.exchange(0, 2, crvusdBalance, 0);
        
        return (crvusdBalance, wstethReceived);
    }
    
    function uniswapV3SwapCallback(
        int256 amount0Delta,
        int256 amount1Delta,
        bytes calldata
    ) external {
        require(msg.sender == address(UNI_V3_WSTETH_WETH_POOL), "Invalid callback caller");
        
        if (amount0Delta > 0) {
            WSTETH.transfer(msg.sender, uint256(amount0Delta));
        } else if (amount1Delta > 0) {
            WETH.transfer(msg.sender, uint256(amount1Delta));
        }
    }
    
    function wrapSTETH() external {
        uint256 stethBalance = STETH.balanceOf(address(this));
        require(stethBalance > 0, "No stETH to wrap");
        
        STETH.approve(address(WSTETH), stethBalance);
        WSTETH.wrap(stethBalance);
    }
    
    function supplyCollateralAndBorrowUSDC(uint256 wstethAmount) external returns (uint256 usdcBorrowed) {
        uint256 wethBalance = WETH.balanceOf(address(this));
        
        WSTETH.approve(address(AAVE_V3), wstethAmount);
        WETH.approve(address(AAVE_V3), wethBalance);
        AAVE_V3.supply(address(WSTETH), wstethAmount, address(this), 0);
        AAVE_V3.supply(address(WETH), wethBalance, address(this), 0);
        
        (, , uint256 availableBorrowsBase, , ,) = AAVE_V3.getUserAccountData(address(this));
        
        usdcBorrowed = (availableBorrowsBase * 1e6) / 1e8;
        
        if (usdcBorrowed > 0) {
            AAVE_V3.borrow(address(USDC), usdcBorrowed, 2, 0, address(this));
        }
        
        return usdcBorrowed;
    }
    
    function withdrawToken(address token) external {
        uint256 balance = IERC20(token).balanceOf(address(this));
        if (balance > 0) {
            IERC20(token).transfer(msg.sender, balance);
        }
    }
    
    function withdrawETH() external {
        uint256 balance = address(this).balance;
        if (balance > 0) {
            payable(msg.sender).transfer(balance);
        }
    }
    
    receive() external payable {}
}