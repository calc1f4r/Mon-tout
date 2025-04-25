# LayerZero Transfer Restriction Bypass Report

## Summary
- ❌ Checked: Ensure on-chain transfer restrictions cannot be bypassed via cross-chain functions.

## Background
ThorWallet integrated LayerZero’s `send()` to handle cross-chain calls. The `Titn` contract enforces a same‑chain transfer lock in `_validateTransfer()`:

```solidity
function _validateTransfer(address from, address to) internal view {
    uint256 arbitrumChainId = 42161;
    if (
        from != owner() &&
        from != transferAllowedContract &&
        to   != transferAllowedContract &&
        isBridgedTokensTransferLocked &&
        (isBridgedTokenHolder[from] || block.chainid == arbitrumChainId) &&
        to   != lzEndpoint
    ) {
        revert BridgedTokensTransferLocked();
    }
}
```

When `isBridgedTokensTransferLocked == true`, regular `transfer` and `transferFrom` are blocked for bridged holders, allowing only:
- `transferAllowedContract`
- `lzEndpoint`

## Bypass via `send()`
LayerZero’s `send()` does not invoke `_validateTransfer()`. Instead it:
1. Calls `_debit()` on the **source** chain → burns tokens.
2. Calls `_credit()` on the **destination** chain → mints tokens.

A user can:
1. Lock transfers on Chain A.
2. Use `send()` A→B to burn tokens on A.
3. Immediately `send()` B→A with `to = victim address`.
4. Receive minted tokens on A at any address, bypassing the same-chain lock.

## Impact
- **Severity**: High — bypass defeats intended on-chain lock.
- **Affected**: All bridged token holders under lock.

## Reproduction Steps
1. Owner sets `isBridgedTokensTransferLocked = true`.
2. User holds bridged tokens on Chain A.
3. User calls `send()` to Chain B (tokens burned on A).
4. User calls `send()` back to Chain A with arbitrary `to`.
5. Tokens are minted on A without running `_validateTransfer()`.

## Mitigation
- Enforce `_validateTransfer` (or equivalent) inside `_debit()`/`send()`.
- Restrict calls to the LayerZero endpoint or whitelist relayers.
- Add a hook in the cross-chain burn/mint path to reapply the same lock.