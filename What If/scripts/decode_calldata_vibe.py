#!/usr/bin/env python3
"""
Final decoder for the exploiter's swap transaction calldata
"""

import json

def decode_multicall():
    # Read clean calldata
    with open('calldata_raw.txt', 'r') as f:
        calldata = f.read().strip()
    
    if calldata.startswith('0x'):
        calldata = calldata[2:]
    
    # Known contract addresses for reference
    known_addresses = {
        'ae7ab96520de3a18e5e111b5eaab095312d7fe84': 'stETH',
        '7f39c581f595b53c5cb19bd0b3f8da6c935e2ca0': 'wstETH', 
        'dc24316b9ae028f1497c275eb9192a3ea0f67022': 'Curve stETH/ETH Pool',
        '21e27a5e5513d6e65c4f830167390997aa84843a': 'Curve ETH/stETH Pool (NG)',
        '4028daac072e492d34a3afdbef0ba7e35d8b55c4': 'Curve stETH/USDC Pool',
        'e592427a0aece92de3edee1f18e0157c05861564': 'Uniswap V3 Router',
        '2889302a794da87fbf1d6db415c1492194663d13': 'Pool (unknown)',
        'c02aaa39b223fe8d0a0e5c4f27ead9083c756cc2': 'WETH',
        'a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48': 'USDC',
    }
    
    # Function selectors
    selectors = {
        '095ea7b3': 'approve',
        'a9059cbb': 'transfer',
        '3df02124': 'exchange (Curve)',
        '022c0d9f': 'swap (Uniswap V2)',
        'ea598cb0': 'unwrap (wstETH)',
        'c04b8d59': 'exactInput (Uniswap V3)',
        '5b41b908': 'swap (unknown pool)',
    }
    
    print("="*80)
    print("EXPLOITER MULTICALL TRANSACTION DECODE")
    print("="*80)
    
    # Verify selector
    selector = calldata[:8]
    print(f"Function selector: 0x{selector} (aggregate)")
    
    # Parse based on actual data structure
    # Looking for contract addresses directly in the data
    import re
    
    # Find all contract interactions
    calls = []
    call_num = 1
    
    # Search for known function selectors in the calldata
    for selector_hex, func_name in selectors.items():
        pattern = selector_hex
        matches = list(re.finditer(pattern, calldata))
        for match in matches:
            pos = match.start()
            # Try to find the target contract (usually appears before the selector)
            # Look back ~100 chars for a known address
            context_start = max(0, pos - 200)
            context = calldata[context_start:pos]
            
            target = None
            for addr, name in known_addresses.items():
                if addr in context:
                    target = (addr, name)
                    break
            
            if target:
                calls.append({
                    'position': pos,
                    'function': func_name,
                    'selector': selector_hex,
                    'target': target
                })
    
    # Sort by position in calldata
    calls.sort(key=lambda x: x['position'])
    
    print(f"\\nFound {len(calls)} function calls:\\n")
    
    for i, call in enumerate(calls, 1):
        print(f"Call #{i}:")
        print(f"  Position: {call['position']}")
        print(f"  Target: 0x{call['target'][0]} ({call['target'][1]})")
        print(f"  Function: {call['function']} (0x{call['selector']})")
        
        # Decode specific parameters based on function
        pos = call['position']
        if call['function'] == 'approve':
            # Next 32 bytes after selector is the spender address
            spender = calldata[pos+8+24:pos+8+64]
            amount = calldata[pos+8+64:pos+8+128]
            if amount == 'f' * 64:
                print(f"  Spender: 0x{spender}")
                print(f"  Amount: MAX_UINT256 (infinite approval)")
            else:
                amount_val = int(amount, 16) / 10**18
                print(f"  Spender: 0x{spender}")
                print(f"  Amount: {amount_val:,.2f} tokens")
                
        elif call['function'] == 'transfer':
            recipient = calldata[pos+8+24:pos+8+64]
            amount = calldata[pos+8+64:pos+8+128]
            amount_val = int(amount, 16) / 10**18
            print(f"  Recipient: 0x{recipient}")
            print(f"  Amount: {amount_val:,.2f} tokens")
            
        elif call['function'] == 'exchange (Curve)':
            i_val = int(calldata[pos+8:pos+8+64], 16)
            j_val = int(calldata[pos+8+64:pos+8+128], 16)
            dx = int(calldata[pos+8+128:pos+8+192], 16) / 10**18
            min_dy = int(calldata[pos+8+192:pos+8+256], 16) / 10**18
            print(f"  From index: {i_val}")
            print(f"  To index: {j_val}")
            print(f"  Amount in: {dx:,.2f}")
            print(f"  Min out: {min_dy:,.2f}")
            
        elif call['function'] == 'unwrap (wstETH)':
            amount = calldata[pos+8:pos+8+64]
            amount_val = int(amount, 16) / 10**18
            print(f"  Amount: {amount_val:,.2f} wstETH")
            
        print()
    
    print("="*80)

if __name__ == "__main__":
    decode_multicall()