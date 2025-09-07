// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {CurveLiquidator} from "../src/CurveLiquidator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICurveController {
    function debt(address user) external view returns (uint256);
    function health(address user, bool full) external view returns (int256);
}

contract LiquidatePositionScript is Script {
    address constant CURVE_CONTROLLER = 0xEdA215b7666936DEd834f76f3fBC6F323295110A;
    address constant LIQUIDATION_TARGET = 0x6F8C5692b00c2eBbd07e4FD80E332DfF3ab8E83c;
    address constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;
    address constant CRVUSD = 0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E;
    
    // Liquidation parameters
    uint256 constant LIQUIDATION_FRACTION = 1e15; // 0.1% = 0.001 = 1e15 / 1e18
    
    function run() external {
        vm.startBroadcast();
        
        address deployer = msg.sender;
        
        // Verify position is liquidatable
        ICurveController controller = ICurveController(CURVE_CONTROLLER);
        int256 health = controller.health(LIQUIDATION_TARGET, true);
        uint256 debt = controller.debt(LIQUIDATION_TARGET);
        
        require(health < 0, "Position is healthy");
        require(debt > 0, "No debt to liquidate");
        
        // Deploy liquidator contract
        CurveLiquidator liquidator = new CurveLiquidator();
        
        // Record initial balances
        uint256 initialCrvBalance = IERC20(CRV).balanceOf(deployer);
        
        // Execute liquidation
        liquidator.liquidate(LIQUIDATION_FRACTION);
        
        // Verify profit
        uint256 finalCrvBalance = IERC20(CRV).balanceOf(deployer);
        uint256 profit = finalCrvBalance - initialCrvBalance;
        
        console2.log("Liquidation successful!");
        console2.log("CRV profit:", profit / 1e18);
        console2.log("Final CRV balance:", finalCrvBalance / 1e18);
        
        vm.stopBroadcast();
    }
}