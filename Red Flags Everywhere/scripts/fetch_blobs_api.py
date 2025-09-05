#!/usr/bin/env python3
import requests
import json
import time

API_BASE = "https://api-mocha-4.celenium.io/v1"
NAMESPACE = "0000000000000000000000000000000000000000000065636c74330a"
LIMIT = 100
RESULT_FILE = "result.json"

def load_progress():
    try:
        with open(RESULT_FILE, 'r') as f:
            data = json.load(f)
            return data.get('blobs', []), data.get('last_offset', 0)
    except:
        return [], 0

def save_progress(blobs, offset):
    data = {
        'namespace': NAMESPACE,
        'total_blobs': len(blobs),
        'last_offset': offset,
        'blobs': blobs
    }
    with open(RESULT_FILE, 'w') as f:
        json.dump(data, f, indent=2)

def fetch_batch(offset):
    url = f"{API_BASE}/namespace/{NAMESPACE}/0/blobs"
    params = {'sort_by': 'time', 'limit': LIMIT, 'offset': offset}
    
    try:
        response = requests.get(url, params=params, timeout=30)
        if response.status_code == 200:
            return response.json()
        else:
            print(f"Error {response.status_code} at offset {offset}")
            return None
    except Exception as e:
        print(f"Request failed at offset {offset}: {e}")
        return None

def main():
    blobs, offset = load_progress()
    print(f"Starting from offset {offset}, current total: {len(blobs)}")
    
    while True:
        batch = fetch_batch(offset)
        
        if batch is None:
            print(f"Stopped at offset {offset}")
            break
            
        if not batch or len(batch) == 0:
            print(f"No more data at offset {offset}")
            break
            
        blobs.extend(batch)
        offset += LIMIT
        
        save_progress(blobs, offset)
        print(f"Offset {offset}: +{len(batch)} blobs (total: {len(blobs)})")
        
        if len(batch) < LIMIT:
            print("Reached end of data")
            break
            
        time.sleep(0.1)
    
    print(f"Complete. Total blobs: {len(blobs)}")

if __name__ == "__main__":
    main()