// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

interface IEToken {
    function balanceOf(address account) external view returns (uint256);
    function balanceOfUnderlying(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface IDToken {
    function borrow(uint256 subAccountId, uint256 amount) external;
}

interface IMarkets {
    function enterMarket(uint256 subAccountId, address newMarket) external;
    function underlyingToDToken(address underlying) external view returns (address);
}

interface IUniswapV3Router {
    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }
    
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);
}

contract Solution is Script {
    // ============ Configuration ============
    
    // Core addresses
    address constant USER_ADDRESS = <YOUR_WALLET_ADDRESS>;
    address constant eETH_ADDRESS = 0x1b808F49ADD4b8C6b5117d9681cF7312Fcf0dC1D;
    address constant MARKETS_ADDRESS = 0x3520d5a913427E6F0D6A83E07ccD4A4da316e4d3;
    address constant WETH_ADDRESS = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC_ADDRESS = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant UNISWAP_V3_ROUTER = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    
    // Isolated market configuration
    uint256 constant ISOLATED_PRIVATE_KEY = <RANDOM_PRIVATE_KEY>;
    uint256 constant COLLATERAL_SPLIT_PERCENTAGE = 46; // 46% to isolated account
    uint256 constant LDO_BORROW_AMOUNT = <LDO_BORROW_AMOUNT>; // Constant LDO amount to borrow
    uint256 constant GAS_AMOUNT = 0.02 ether;
    
    // Token addresses for borrowing
    address constant UNI_ADDRESS = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address constant CBETH_ADDRESS = 0xBe9895146f7AF43049ca1c1AE358B0541Ea49704;
    address constant AGEUR_ADDRESS = 0x1a7e4e63778B4f12a199C062f3eFdD288afCBce8;
    address constant MKR_ADDRESS = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
    address constant LINK_ADDRESS = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address constant MATIC_ADDRESS = 0x7D1AfA7B718fb893dB30A3aBc0Cfc608AaCfeBB0;
    address constant ENS_ADDRESS = 0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72;
    address constant OSQTH_ADDRESS = 0xf1B99e3E573A1a9C5E6B2Ce818b617F0E664E86B;
    address constant LDO_ADDRESS = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
    
    // Swap configuration (pool fees)
    uint24 constant FEE_100 = 100;
    uint24 constant FEE_500 = 500;
    uint24 constant FEE_3000 = 3000;

    function run() external {
        
        // Step 1: Borrow from non-isolated markets
        borrowFromNonIsolatedMarkets();
        
        // Step 2: Calculate available eETH for isolated account
        IEToken eETH = IEToken(eETH_ADDRESS);
        uint256 eETHToTransfer = (eETH.balanceOf(USER_ADDRESS) * COLLATERAL_SPLIT_PERCENTAGE) / 100;
        
        // Step 3: Borrow from isolated markets using separate account
        borrowLDOFromIsolatedMarket(eETHToTransfer);

        // Step 4: Swap all borrowed tokens to USDC
        swapAllTokensToUSDC();
    }

    function borrowLDOFromIsolatedMarket(uint256 eETHAmount) internal {
        IEToken eETH = IEToken(eETH_ADDRESS);
        IMarkets markets = IMarkets(MARKETS_ADDRESS);
        
        address isolatedAccount = vm.addr(ISOLATED_PRIVATE_KEY);
        
        vm.startBroadcast();
        
        // Send ETH for gas
        (bool success,) = isolatedAccount.call{value: GAS_AMOUNT}("");
        require(success, "ETH transfer failed");
        
        // Transfer eETH to isolated account
        eETH.transfer(isolatedAccount, eETHAmount);
        
        vm.stopBroadcast();
        
        // Switch to isolated account
        vm.startBroadcast(ISOLATED_PRIVATE_KEY);
        
        // Enter WETH market as collateral
        markets.enterMarket(0, WETH_ADDRESS);
        
        // Borrow LDO
        address dLDO = markets.underlyingToDToken(LDO_ADDRESS);
        IDToken(dLDO).borrow(0, LDO_BORROW_AMOUNT);
        
        // Transfer LDO back to main account
        uint256 ldoBorrowed = IERC20(LDO_ADDRESS).balanceOf(isolatedAccount);
        IERC20(LDO_ADDRESS).transfer(USER_ADDRESS, ldoBorrowed);
        
        vm.stopBroadcast();
    }

    function borrowFromNonIsolatedMarkets() internal {
        IMarkets markets = IMarkets(MARKETS_ADDRESS);
        
        vm.startBroadcast();
        
        // Enter WETH market as collateral
        markets.enterMarket(0, WETH_ADDRESS);
        
        // Top value tokens to borrow
        address[8] memory tokens = [
            UNI_ADDRESS,
            CBETH_ADDRESS,
            AGEUR_ADDRESS,
            MKR_ADDRESS,
            LINK_ADDRESS,
            MATIC_ADDRESS,
            ENS_ADDRESS,
            OSQTH_ADDRESS
        ];
        
        // Borrow each token
        for (uint i = 0; i < tokens.length; i++) {
            address dToken = markets.underlyingToDToken(tokens[i]);
            if (dToken != address(0)) {
                try IDToken(dToken).borrow(0, type(uint256).max) {
                } catch {
                }
            }
        }
        
        vm.stopBroadcast();
    }

    function swapAllTokensToUSDC() internal {
        vm.startBroadcast();
        
        IUniswapV3Router v3Router = IUniswapV3Router(UNISWAP_V3_ROUTER);
        
        address[9] memory tokens = [
            UNI_ADDRESS,
            CBETH_ADDRESS,
            AGEUR_ADDRESS,
            MKR_ADDRESS,
            LINK_ADDRESS,
            MATIC_ADDRESS,
            ENS_ADDRESS,
            OSQTH_ADDRESS,
            LDO_ADDRESS
        ];
        
        for (uint i = 0; i < tokens.length; i++) {
            uint256 balance = IERC20(tokens[i]).balanceOf(USER_ADDRESS);
            if (balance > 0) {
                // Reset allowance first (for tokens like USDT)
                IERC20(tokens[i]).approve(UNISWAP_V3_ROUTER, 0);
                IERC20(tokens[i]).approve(UNISWAP_V3_ROUTER, type(uint256).max);
                
                bytes memory path = _getSwapPath(tokens[i]);
                
                try v3Router.exactInput(IUniswapV3Router.ExactInputParams({
                    path: path,
                    recipient: USER_ADDRESS,
                    deadline: block.timestamp + 300,
                    amountIn: balance,
                    amountOutMinimum: 0
                })) returns (uint256) {
                } catch {
                }
            }
        }
        
        vm.stopBroadcast();
    }

    function _getSwapPath(address token) internal pure returns (bytes memory) {
        if (token == UNI_ADDRESS) {
            return abi.encodePacked(token, FEE_3000, WETH_ADDRESS, FEE_500, USDC_ADDRESS);
        } else if (token == CBETH_ADDRESS) {
            return abi.encodePacked(token, FEE_500, WETH_ADDRESS, FEE_500, USDC_ADDRESS);
        } else if (token == AGEUR_ADDRESS) {
            return abi.encodePacked(token, FEE_100, USDC_ADDRESS);
        } else if (token == MKR_ADDRESS) {
            return abi.encodePacked(token, FEE_3000, WETH_ADDRESS, FEE_500, USDC_ADDRESS);
        } else if (token == LINK_ADDRESS) {
            return abi.encodePacked(token, FEE_3000, WETH_ADDRESS, FEE_500, USDC_ADDRESS);
        } else if (token == MATIC_ADDRESS) {
            return abi.encodePacked(token, FEE_3000, WETH_ADDRESS, FEE_500, USDC_ADDRESS);
        } else if (token == ENS_ADDRESS) {
            return abi.encodePacked(token, FEE_3000, WETH_ADDRESS, FEE_500, USDC_ADDRESS);
        } else if (token == OSQTH_ADDRESS) {
            return abi.encodePacked(token, FEE_3000, WETH_ADDRESS, FEE_500, USDC_ADDRESS);
        } else {
            return abi.encodePacked(token, FEE_3000, WETH_ADDRESS, FEE_500, USDC_ADDRESS);
        }
    }
}