📋 Signature Security Checklist

1. Nonce Implementation

- [ ] Implement a nonce tracking system
- [ ] Store nonces in contract storage
- [ ] Validate signatures using current nonce
- [ ] Mark used nonces as consumed

Example implementation (from OpenZeppelin):

```solidity
function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) public virtual {
    bytes32 structHash = keccak256(
        abi.encode(
            _PERMIT_TYPEHASH,
            owner,
            spender,
            value,
            _useNonce(owner), // Using nonce
            deadline
        )
    );
    // ... signature verification
}

function _useNonce(address owner) internal virtual returns (uint256 current) {
    Counters.Counter storage nonce = _nonces[owner];
    current = nonce.current();
    nonce.increment();
}
```

2. Cross-Chain Protection

- [ ] Include chain_id in signature verification
- [ ] Validate chain_id in message hash
- [ ] Use domain separators with chain_id

Example of what NOT to do:

```solidity
// Bad - Missing chain_id
function getHash(UserOperation calldata userOp) public pure returns (bytes32) {
    return keccak256(abi.encode(
        userOp.getSender(),
        userOp.nonce,
        // ... other parameters
    ));
}
```

3. Parameter Validation

- [ ] Include ALL relevant parameters in signature
- [ ] Verify no critical parameters are missing
- [ ] Include amount/value parameters in signature hash

Example of proper parameter inclusion:

```solidity
bytes32 safeTxHash = keccak256(
    abi.encode(
        ACCOUNT_TX_TYPEHASH,
        _tx.to,
        _tx.value,
        keccak256(_tx.data),
        _tx.operation,
        _tx.targetTxGas,
        refundInfo.baseGas,
        refundInfo.gasPrice,
        refundInfo.gasToken,
        refundInfo.refundReceiver,
        _nonce
    )
);
```

4. Expiration Mechanism

- [ ] Implement signature expiration/deadline
- [ ] Include timestamp in signature parameters
- [ ] Validate expiration before processing

Example implementation:

```solidity
function _hash(RequestMetadata calldata metadata) internal pure returns (bytes32) {
    return keccak256(
        abi.encode(
            _REQUEST_METADATA_TYPEHASH,
            metadata.caller,
            metadata.expiration // Including expiration timestamp
        )
    );
}
```

5. ecrecover() Safety

- [ ] Check for zero address return
- [ ] Validate signature components (v, r, s)
- [ ] Use OpenZeppelin's ECDSA library (v4.7.3+)

Example of what to avoid:

```solidity
// Bad - Unchecked ecrecover
function recover(bytes32 h, Components calldata c) internal pure returns (address) {
    return ecrecover(h, c.v, c.r, c.s); // Missing zero address check
}
```

6. Signature Malleability Protection

- [ ] Use OpenZeppelin's ECDSA.sol library
- [ ] Validate signature components
- [ ] Implement proper v, r, s checks

Proper implementation example:

```solidity
function verify(address signer, bytes32 hash, bytes memory signature) internal pure returns (bool) {
    require(signature.length == 65);
    bytes32 r;
    bytes32 s;
    uint8 v;

    assembly {
        r := mload(add(signature, 32))
        s := mload(add(signature, 64))
        v := byte(0, mload(add(signature, 96)))
    }

    if (v < 27) {
        v += 27;
    }

    require(v == 27 || v == 28);
    return signer == ecrecover(hash, v, r, s);
}
```

7. Additional Best Practices

- [ ] Implement EIP-712 standard
- [ ] Use domain separators
- [ ] Follow OpenZeppelin's implementation patterns
- [ ] Keep signature verification code simple and audited

Reference: https://dacian.me/signature-replay-attacks
