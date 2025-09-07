function func_0x9b9(_549) -> ret_val_0 {
    // Get free memory pointer
    let _550 := mload(0x40)
    let _551 := add(0x20, _550)
    
    // Store first constant byte (0xd2)
    mstore(add(_551, 0x0), 0xd200000000000000000000000000000000000000000000000000000000000000)
    
    // Move pointer forward by 1 byte
    let _552 := add(_551, 0x1)
    
    // Store second constant (31 bytes starting with 0xa1110e34...)
    mstore(add(_552, 0x0), 0xa1110e34c4248ccfec2d3d08ccb14e1daa3c3c6b98578b7aa5139e85179b1200)
    
    // Move pointer forward by 31 bytes (0x1f)
    let _553 := add(_552, 0x1f)
    
    // Create a memory structure with length prefix
    let _554 := mload(0x40)
    mstore(_554, sub(sub(_553, _554), 0x20))  // Store length (32 bytes total)
    mstore(0x40, _553)  // Update free memory pointer
    
    // Load the constructed 32-byte value
    let _555 := mload(_554)  // Length (should be 32)
    let _556 := mload(add(_554, 0x20))  // The actual 32-byte value
    
    // Apply masking if length < 32 (but length should be 32 here)
    let _557 := _556
    let _558 := iszero(lt(_555, 0x20))
    if not(_558) {
        // This branch shouldn't execute since length = 32
        _557 := and(_556, shl(mul(0x8, sub(0x20, _555)), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff))
    }
    
    // Now construct origin address for hashing
    let _559 := mload(0x40)
    let _560 := add(0x20, _559)
    
    // Store origin address (tx.origin) as 20 bytes, left-padded to 32 bytes
    mstore(_560, shl(0x60, and(origin(), 0xffffffffffffffffffffffffffffffffffffffff)))
    
    // Move pointer forward by 20 bytes (0x14)
    let _561 := add(_560, 0x14)
    
    // Create memory structure with length prefix for origin
    let _562 := mload(0x40)
    mstore(_562, sub(sub(_561, _562), 0x20))  // Store length (20 bytes)
    mstore(0x40, _561)  // Update free memory pointer
    
    // Calculate keccak256 hash of origin address
    let _563 := mload(_562)  // Length (20)
    let _564 := mload(0x40)
    let _565 := add(0x20, _564)
    
    // Store the hash result
    mstore(_565, keccak256(add(0x20, _562), _563))
    
    // Move pointer forward by 32 bytes
    let _566 := add(_565, 0x20)
    
    // Create final memory structure
    let _567 := mload(0x40)
    mstore(_567, sub(sub(_566, _567), 0x20))  // Store length (32 bytes)
    mstore(0x40, _566)  // Update free memory pointer
    
    // Calculate final hash and compare
    let _568 := mload(_567)  // Length (32)
    
    // Return true if keccak256(keccak256(origin)) equals the constructed constant
    // The constant is: 0xd2a1110e34c4248ccfec2d3d08ccb14e1daa3c3c6b98578b7aa5139e85179b12
    ret_val_0 := eq(keccak256(add(0x20, _567), _568), _557)
    
    leave
}

/*
Summary:
This function checks if keccak256(keccak256(tx.origin)) equals a specific hardcoded value.

The hardcoded value is constructed from two parts:
- First byte: 0xd2
- Next 31 bytes: 0xa1110e34c4248ccfec2d3d08ccb14e1daa3c3c6b98578b7aa5139e85179b12

How the parts are combined in memory:
1. First mstore at _551 writes 0xd2 followed by 31 zeros (big-endian format)
   Memory: [0xd2 00 00 00 ... (31 zeros)]
   
2. Second mstore at _552 (which is _551 + 1) overwrites the last 31 bytes
   This writes 32 bytes starting from position _551 + 1
   Memory becomes: [0xd2] + [0xa1110e34c4248ccfec2d3d08ccb14e1daa3c3c6b98578b7aa5139e85179b12]
   
3. The final 32-byte value after combining:
   0xd2a1110e34c4248ccfec2d3d08ccb14e1daa3c3c6b98578b7aa5139e85179b12
   
   This is achieved by:
   - Byte 0: 0xd2 (from first mstore)
   - Bytes 1-31: 0xa1110e34...9b12 (from second mstore)

The function:
1. Constructs the expected hash value in memory (0xd2a1110e34...)
2. Computes keccak256(tx.origin)
3. Computes keccak256(keccak256(tx.origin))
4. Compares it with the expected value
5. Returns true if they match, false otherwise

This is likely an access control mechanism that only allows specific addresses
whose double-hash matches the hardcoded value.
*/