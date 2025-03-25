# Solana Event Emission Issues

## Problem Statement
Use of `emit!` is not recommended as Solana nodes truncate logs larger than 10 KB by default, making regular events emitted via the `emit!` macro unreliable for large data sets.

## Impact
- Potential loss of critical event data
- Inconsistent off-chain data processing
- Reduced transparency and auditability of on-chain actions

## Recommended Solution
Use the Cross-Program Invocation (CPI) event emission pattern instead:
```rust
emit_cpi!(buy_event);
```

### Benefits of CPI Events
- Bypasses the log size limitations
- Ensures reliable event data recording
- Better compatibility with large data sets
- Improves off-chain data consistency

### Implementation Note
When using `emit_cpi!`, make sure to import the necessary dependencies and configure your event structures properly for CPI compatibility.
