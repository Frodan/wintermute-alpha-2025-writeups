// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Script.sol";
import "../src/Helper.sol";
import "../src/interfaces/IERC20.sol";
import "../src/interfaces/IAAVE.sol";

contract Solution is Script {
    // Tokens
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant STETH = 0xae7ab96520DE3A18E5e111B5EaAb095312D7fE84;
    address private constant WSTETH = 0x7f39C581F595B53c5cb19bD0b3f8dA6c935E2Ca0;
    address private constant CRVUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    
    // Protocols
    address private constant AAVE_V2 = 0x7d2768dE32b0b80b7a3454c06BdAc94A69DDc7A9;
    
    // Strategy parameters
    uint256 private constant TARGET_FLASHLOAN = 7300 ether;
    uint256 private constant BORROW_AMOUNT = 3522 ether;
    uint256 private constant UNI_V3_SWAP = 1500 ether;
    uint256 private constant UNI_V2_SWAP = 500 ether;
    uint256 private constant CRVUSD_SWAP = 10000 ether;
    uint256 private constant OPTIMAL_WSTETH = 30138 ether;
    
    uint256 private constant ETH_PRICE = 2600;
    uint256 private constant WSTETH_ETH_RATIO = 116;
    
    function printHelperBalances(address helper) private view {
        console.log("Helper WETH:", IERC20(WETH).balanceOf(helper) / 1e18);
        console.log("Helper wstETH:", IERC20(WSTETH).balanceOf(helper) / 1e18);
        console.log("Helper crvUSD:", IERC20(CRVUSD).balanceOf(helper) / 1e18);
    }
    
    function run() external {
        vm.startBroadcast();
        
        Helper helper = new Helper();
        console.log("Deployed Helper:", address(helper));
        
        // Execute multi-pool arbitrage strategy
        helper.executeFlashLoan(TARGET_FLASHLOAN);
        helper.borrowFromAave(WETH, BORROW_AMOUNT);
        helper.swapWethToWsteth(UNI_V3_SWAP);
        helper.swapWethToStethUniV2(UNI_V2_SWAP);
        helper.swapWethToCrvUSDToWsteth(CRVUSD_SWAP);
        helper.wrapSTETH();

        printHelperBalances(address(helper));
        
        // Calculate total portfolio value
        uint256 finalWeth = IERC20(WETH).balanceOf(address(helper));
        uint256 finalSteth = IERC20(STETH).balanceOf(address(helper));
        uint256 finalWsteth = IERC20(WSTETH).balanceOf(address(helper));
        uint256 finalCrvusd = IERC20(CRVUSD).balanceOf(address(helper));
        
        (uint256 totalCollateralETH, uint256 totalDebtETH, , , ,) = IAAVE(AAVE_V2).getUserAccountData(address(helper));
        uint256 aaveNetETH = totalCollateralETH > totalDebtETH ? totalCollateralETH - totalDebtETH : 0;
        
        uint256 totalValueUSD = 
            (finalWeth * ETH_PRICE) / 1e18 +
            (finalSteth * ETH_PRICE) / 1e18 +
            (finalWsteth * WSTETH_ETH_RATIO * ETH_PRICE) / (100 * 1e18) +
            finalCrvusd / 1e18 +
            (aaveNetETH * ETH_PRICE) / 1e18;
            
        console.log("Portfolio value: $", totalValueUSD);
        
        // Maximize USDC borrowing from Aave V3
        uint256 usdcBorrowed = helper.supplyCollateralAndBorrowUSDC(OPTIMAL_WSTETH);
        console.log("USDC borrowed:", usdcBorrowed / 1e6);
        
        // Transfer final USDC to deployer
        helper.withdrawToken(USDC);
        uint256 finalUSDC = IERC20(USDC).balanceOf(msg.sender);
        
        console.log("=== CHALLENGE COMPLETE ===");
        console.log("Final USDC:", finalUSDC / 1e6);
        console.log("=========================");
        
        vm.stopBroadcast();
    }
}