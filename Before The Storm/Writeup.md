# Before The Storm

## Task

UwU Lend was drained for $20M a few days ago, and you discovered that the ["exploiter's"](https://etherscan.io/address/0x6F8C5692b00c2eBbd07e4FD80E332DfF3ab8E83c) Llamalend position became unhealthy, making it ripe for liquidation. Since you have no capital at the moment, the only way to execute this liquidation is by using a flash loan.

Your goal: Have at least 20k CRV in your registered wallet after the liquidation.

## Solution

This appeared to be a straightforward task, though debugging took considerable time.

The unhealthy position on UwU Lend is a CRV/crvUSD position. In a typical liquidation, the liquidator pays crvUSD and receives CRV with a premium as a reward. Interestingly, UwU Lend supports flash liquidation, which allows you to receive CRV first and return the required crvUSD amount before the transaction ends. Additionally, while the position is quite large, UwU Lend permits liquidating only a fraction of it at a time.

### Liquidation Steps

1. **Initiate Partial Liquidation**: Call the liquidate function for a small fraction of the position (0.5%)
2. **Token Swap**: In the liquidator contract's callback, swap a portion of the received CRV to crvUSD via Curve's crvUSD/ETH/CRV (TriCRV) pool
3. **Repay Debt**: Return the required crvUSD amount to complete the flash liquidation
4. **Collect Profit**: Withdraw the remaining CRV profit from your contract to your wallet