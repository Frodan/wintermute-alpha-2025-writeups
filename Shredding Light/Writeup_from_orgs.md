# Writeup from @bpavlov_wm
Link: https://t.me/c/2356733254/999

As there wasn't a 75/75 solution for "Shedding Light", we wanted to clarify what were the common mistakes and what we expected as the 'right' solution:


1) For the volume estimation, most common mistake was to use jupiter_solana.aggregator_swaps, which, according to the Dune Spellbook, wasn't updated for a few months and didn't have HumidiFi, which was top-2 by volume. 
To overcome it, the right approach was to use jupiter_v6_solana.jupiter_evt_swapevent (ref: https://dune.com/queries/5683337) or solana.instruction_calls (ref: https://dune.com/queries/5353226). 
Before the challenge start, we also checked if queries could be run without using Dune paid sub, so it wasn't an obstacle here.


2) For this section we were looking for following core ideas:

a) PNL = sum of markouts (with e.g. 0s, 30s, 60s to factor in hedge cost/time) - sum of update txns. For this part many submissions didn't account that PNL != revenue.
b) Trade directly against dark pool and try to be ahead of their price update.
c) Ban list/wider pricing. For this one we were expecting approaches focused on how can dark amm differentiate toxic vs retail flow, e.g. wider pricing for txns with Jito in account list or "rejecting any taker transaction that consumes fewer than 100,000 CUs, on the basis that a cheaper swap attempt is more likely to be an exploitative one" from Helius article about dark amms.

For the section #2, we weren't looking for the exact match, but rather how sound and viable the approaches were.


3) To estimate the lower bound, assuming that PNL >= 0, we could set PNL = 0, then revenue would equal costs of dark amm. The easiest approach to quantify the costs was to look at the cost of all update txns (i.e. fees + jito tips). 
They could've been calculated by checking inflows to the relevant account via solscan or by using solana.account_activity on Dune, which has partition by address and won't timeout.

There was also an article released by Helius with good coverage midst the challenge https://www.helius.dev/blog/solanas-proprietary-amm-revolution, which could provide additional insights into the topic.