# Too Old For Optimizing - Solution
## Task
It's November 10, 2022, and you see ["Twitter threads"](https://x.com/DeFiyst/status/1590679489905729537) about how USDT is becoming the dominant asset in the 3CRV Curve pool. You're confident that USDT will be fine, so you already ported all stablecoins to it ($7M). The question is, could you get even more USDT exposure?

You think that lending is a good option, but there is almost no USDC supply for borrowing on Aave v2, so you need to be creative. Although Aave v1 was deprecated (we rolled this back for the sake of the challenge), you see that there are still funds there. You also remember that some yield optimizers have integrations with Aave v1, so maybe there is a way to utilise the optimizers to increase v1 USDC reserve by 700k?

You should finish the challenge with 7M USDT lent to Aave v1 and 3.5M+ USDT balance on the registered wallet. You should borrow ~3.5M USDC from Aave v1 after using optimizers to solve this case study.


## Solution
The strategy exploits Yearn's automated rebalancing mechanism. When Aave V1 reaches 100% utilization, its supply APR becomes the highest among integrated protocols in Yearn. Calling `rebalance()` triggers Yearn to deposit its USDC reserves into Aave V1, so we can borrow more.

### Attack Steps

1. **Deposit Collateral**: Deposit 7M USDT into Aave V1 as collateral
2. **Maximize Utilization**: Borrow all available USDC liquidity, pushing utilization to 100% and maximizing the supply APR
3. **Trigger Yearn Rebalance**: Call `rebalance()` on yUSDC2 (0xa2609B2b43AC0F5EbE27deB944d2a399C201E3dA) to deposit Yearn's USDC into Aave
4. **Borrow Additional USDC**: Borrow the newly deposited USDC from Yearn's rebalance
5. **Convert to USDT**: Swap borrowed USDC to USDT via Curve 3pool