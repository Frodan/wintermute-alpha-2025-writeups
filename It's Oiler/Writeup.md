# It's Oiler

## Task
Oi, you're enjoying your cuppa tea and scrolling Twitter, where you noticed the post that Euler was exploited an hour ago (it's block 16818350 now). Realizing that you have exposure to it by depositing ETH previously and holding 4.7k eWETH at the moment, you want to save as much out as you can.

Withdraw as much as you can from Euler markets with supply still left in them. With a hack of this size, you think it's over. Dump all tokens you gathered into USDC and end with at least 2.5M USDC in your wallet.

We ended with 4M USDC, let us know if you beat it.

## Solution
It was not possible to withdraw the ETH itself from the market because it was fully drained. However, there still existed unaffected markets. I analyzed the market creation logs and got a full list of available markets. Then I collected data for available reserves and used the most liquid ones to borrow the maximum amount of funds, using our eETH as collateral.

### Steps

1. **Borrowing from Non-Isolated Markets**: Using eETH collateral to borrow maximum amounts from markets with large reserves (UNI, cbETH, agEUR, MKR, LINK, MATIC, ENS, oSQTH).

2. **Borrowing from Isolated Markets**: When non-isolated markets ran out of liquidity, switching to isolated markets with a separate wallet.

3. **Converting to USDC**: Swapping all borrowed tokens to USDC using Uniswap V3 with optimized routing paths.
