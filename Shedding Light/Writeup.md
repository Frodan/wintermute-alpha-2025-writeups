# Shedding Light
## Task
Throughout this year, liquidity provision on Solana has shifted towards so-called "dark AMMs", which are proprietary programs run by market makers. In contrast to usual AMMs, dark AMMs are actively managed and can be updated as frequently as every slot. They are frontend-less; instead, they adhere to interfaces defined by popular aggregators such as Jupiter, allowing users to access this liquidity implicitly. SolFi is one of the originals and a good example to understand how they work better.

Briefly describe the methodology that was used to achieve the result, and provide a link to a private Dune query if necessary.

Focusing only on the SOL/USDC market during July 2025 and for only flow via Jupiter, find:
The top 3 dark AMMs by volume.
For each of the top 3, the top taker by volume. Note, if you find it difficult to get accurate prices at trade time, you can fix SOL to $150 and USDC to $1.
Short written answers are enough for this part.
Explain how you would estimate PNL for dark AMMs.
How can sophisticated actors take advantage of dark AMMs?
How can dark AMMs manage the threats from sophisticated actors?
Assume actors are rational and would only operate a dark AMM if pnl >= 0. Calculate the lower bound for revenue for SolFi since the start of 2025.

## My Solution (42/75)

## Question #1
### Top 3 AMMs
Dune has a great table `jupiter_solana.aggregator_swaps`, but sadly it doesn't contain info about Humidifi. Dune also has a table with clean jup events `jupiter_v6_solana.jupiter_evt_swapevent` and I found an already existing query perfect for that task made by [stepanalytics_team](https://dune.com/queries/5683337) 

I changed it a bit, adding filters for month and token pair: [Query](https://dune.com/queries/5719988/9284737/4eb1a3b2-e27e-40ac-aae3-f66bff73bed9)

#### Results
Top 3 AMMs:
- SolFi
- Humidifi  
- ZeroFi

Dashboard from [Blockworks Solana DEX Activity](https://blockworks.com/analytics/solana/solana-dex-activity) also gives the same results.

### Top takers
For searching the top takers, I modified the same query and used the evt_tx_signer as the taker identifier: [Query](https://dune.com/queries/5720105/9284922/ce12ed4e-3b13-4c78-a814-5ac3c8dac347)

### Results:
- **Humidifi** - `7PTnZawFu5sdJhPdSRem9JwfZPc3fSac8ZKwbfgq5RUm`
- **SolFi** - `7PTnZawFu5sdJhPdSRem9JwfZPc3fSac8ZKwbfgq5RUm`  
- **ZeroFi** - `6P9MZSdHnFaboMunfDfcfDHC6DFtMwPVNp9THpSkgJWY`

---

## Question #2

### Explain how you would estimate PNL for dark AMMs

For the simplest revenue estimation, we can take AMM volume and multiply it by an empirical fee percentage, like 0.01% per trade. Based on this [tweet](https://x.com/bqbrady/status/1959514938981912999), this might not be far from the truth.


For a more precise estimation, we should calculate the revenue for every swap. Dark AMMs earn through bid-ask spreads, therefore:
```
swap_revenue = swap_size × (amm_sell_price − taker_buy_price)
```
```
AMM_PNL = Sum(swap_revenues) - operational_costs + inventory_value_change
```

Where:
- **Sum(swap_revenues)** = Total spread captured across all trades
- **operational_costs** = Oracle fees, infrastructure, etc. (see Question #3)
- **inventory_value_change** = Mark-to-market adjustment for assets held in the pool  

The operational costs calculation methodology is described in the answer to Question #3.

### How can sophisticated actors take advantage of dark AMMs?

Sophisticated actors could:
- Arbitrage slow oracles
- Arbitrage stale/incorrect quotes
- Manipulate the pool liquidity, creating imbalances


### How can dark AMMs manage the threats from sophisticated actors?

The primary defense for dark AMMs lies in **speed and precision** - they need the fastest oracles with the most recent market prices.

Beyond speed, **information asymmetry** becomes crucial. Dark AMMs benefit from maintaining complete opacity about their internal mechanics, obfuscating all interactions to make it harder for sophisticated actors to find and exploit inefficiencies.

---

## Question #3

### Assume actors are rational and would only operate a dark AMM if pnl >= 0. Calculate the lower bound for revenue for SolFi since the start of 2025.

Revenue lower bound should equal all expenses that need to be covered by income for the operation to remain profitable.

Since information about SolFi is limited, I cannot calculate certain expenses such as infrastructure maintenance costs, employee salaries, and other operational overhead. Therefore, I will calculate the lower bound based solely on observable on-chain data.

### Observable Costs:

**1. Oracle Maintenance Fees**  
Based on statistics from this [post](https://x.com/bqbrady/status/1953875311227236611/photo/1), I can calculate their operational oracle expenses.  

If oracle maintenance requires **$1,785 per day** in gas fees, for 246 days it would be **$439,110**.

**2. Opportunity Cost of Capital**  
Furthermore, knowing their AUM (from the same post), I can calculate the minimum opportunity cost on deployed capital. As a lower bound, I'll use the 5% APR of US Treasuries. It wouldn't make sense to hold capital in SolFi if it generates less income than risk-free alternatives. 

With an AUM of $8M, over 246 days of the year, the required profit would be equal to **$8,000,000 × 0.05 × (246/365) = ~$270,000**.

### Conclusion:
Based only on public data at this moment, total lower bound for revenue = **~$710,000**.

