- [ ] Always cache the timestamp from a single `Clock::get()` call and validate it before using in multiple places
https://code4rena.com/reports/2025-01-pump-science#07-trade-event-emission-uses-redundant-clock-calls-and-lacks-block-time-validation

### Context: Pump Science Protocol Clock Issues

The Pump Science protocol emits trade events for indexing purposes in the `handler()` function of the swap instruction. The event emission has two issues:

#### 1. Redundant Clock Calls:

```rust
emit_cpi!(TradeEvent {
    // ... other fields ...
    timestamp: Clock::get()?.unix_timestamp,  // First Clock::get() call
    // ... other fields ...
});

if bondingcurve.complete { 
    emitcpi!(CompleteEvent { 
        // … other fields … 
        timestamp: Clock::get()?.unix_timestamp, // Second Clock::get() call 
        // … other fields … 
    }); 
}
```

#### 2. No Validation of Block Time:

The timestamp is used directly from `Clock::get()` without any validation that the block time is reasonable or hasn't been manipulated by the validator.

### Potential Issues:

1. Unnecessary computational overhead from redundant syscalls
2. Inconsistent timestamps between `TradeEvent` and `CompleteEvent` if they're emitted in the same transaction
3. Potential for incorrect historical data if validators manipulate block times

For example:
```rust
// Current implementation might result in:
TradeEvent.timestamp = 1000
CompleteEvent.timestamp = 1001  // Different timestamp from same tx
```

### Recommendation:
Cache the timestamp and add basic validation to ensure consistent and reliable timestamp data.