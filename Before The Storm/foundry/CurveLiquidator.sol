// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ICurveController {
    function liquidate_extended(
        address user,
        uint256 min_x,
        uint256 frac,
        bool use_eth,
        address callbacker,
        uint256[] calldata callback_args
    ) external;
    
    function tokens_to_liquidate(address user, uint256 frac) external view returns (uint256);
}

interface ITriCrypto {
    function exchange(
        uint256 i,
        uint256 j,
        uint256 dx,
        uint256 min_dy,
        bool use_eth,
        address receiver
    ) external payable returns (uint256);
    
    function get_dx(uint256 i, uint256 j, uint256 dy) external view returns (uint256);
}

contract CurveLiquidator {
    using SafeERC20 for IERC20;

    // Core protocol addresses
    address private constant CONTROLLER = 0xEdA215b7666936DEd834f76f3fBC6F323295110A;
    address private constant LIQUIDATION_TARGET = 0x6F8C5692b00c2eBbd07e4FD80E332DfF3ab8E83c;
    
    // Curve TriCrypto pool configuration
    address private constant CRV_TRICRYPTO_POOL = 0x4eBdF703948ddCEA3B11f675B4D1Fba9d2414A14;
    uint256 private constant CRV_INDEX = 2;
    uint256 private constant CRVUSD_INDEX = 0;
    
    // Token addresses
    IERC20 private constant CRV = IERC20(0xD533a949740bb3306d119CC777fa900bA034cd52);
    IERC20 private constant CRVUSD = IERC20(0xf939E0A03FB07F59A73314E73794Be0E57ac1b4E);

    constructor() {
        CRV.safeApprove(CRV_TRICRYPTO_POOL, type(uint256).max);
        CRVUSD.safeApprove(CONTROLLER, type(uint256).max);
    }

    function liquidate(uint256 liquidationFraction) external {
        uint256 repayAmount = ICurveController(CONTROLLER).tokens_to_liquidate(
            LIQUIDATION_TARGET,
            liquidationFraction
        );
        
        uint256[] memory callbackArgs = new uint256[](1);
        callbackArgs[0] = repayAmount;

        ICurveController(CONTROLLER).liquidate_extended(
            LIQUIDATION_TARGET,
            0,
            liquidationFraction,
            false,
            address(this),
            callbackArgs
        );

        _withdrawProfits();
    }

    function callback_liquidate(
        address user,
        uint256 stablecoins,
        uint256 collateral,
        uint256 debt,
        uint256[] calldata callbackArgs
    ) external returns (uint256[2] memory) {
        require(msg.sender == CONTROLLER, "Unauthorized callback");
        
        uint256 repayAmount = callbackArgs[0];
        
        // Calculate required CRV amount with 1% buffer for slippage
        uint256 requiredCrv = ITriCrypto(CRV_TRICRYPTO_POOL).get_dx(
            CRV_INDEX,
            CRVUSD_INDEX,
            repayAmount
        ) * 101 / 100;
        
        // Swap CRV to crvUSD
        ITriCrypto(CRV_TRICRYPTO_POOL).exchange(
            CRV_INDEX,
            CRVUSD_INDEX,
            requiredCrv,
            0,
            false,
            address(this)
        );
        
        uint256 crvUsdBalance = CRVUSD.balanceOf(address(this));
        require(crvUsdBalance >= repayAmount, "Insufficient crvUSD");
        
        return [crvUsdBalance, 0];
    }

    function _withdrawProfits() private {
        // Swap remaining crvUSD back to CRV
        uint256 crvUsdBalance = CRVUSD.balanceOf(address(this));
        if (crvUsdBalance > 0) {
            ITriCrypto(CRV_TRICRYPTO_POOL).exchange(
                CRVUSD_INDEX,
                CRV_INDEX,
                crvUsdBalance,
                0,
                false,
                msg.sender
            );
        }
        
        // Transfer any remaining CRV
        uint256 crvBalance = CRV.balanceOf(address(this));
        if (crvBalance > 0) {
            CRV.safeTransfer(msg.sender, crvBalance);
        }
    }
}