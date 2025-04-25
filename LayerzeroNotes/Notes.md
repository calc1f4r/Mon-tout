# LayerZero OFT Mechanics
## 1. Cross‑chain transfer via send()
- `send()` initiates a cross‑chain token move 
- On the **source** chain, `_debit()` burns the local tokens.
- On the **destination** chain, `_credit()` mints the same amount.

## 2. Dust removal
LayerZero’s OFT contract may adjust small remainders ("dust"):

```solidity
function _removeDust(uint256 _amountLD) internal view virtual returns (uint256) {
    return (_amountLD / decimalConversionRate) * decimalConversionRate;
}
``` 
Any amount not aligned to `decimalConversionRate` is rounded down, which can cause exact‑amount transfers to fail.

## 3. [Fixed‑amount guard example](https://code4rena.com/reports/2025-02-thorwallet#qa-01-dust-amount-loss-in-cross-chain-titn-token-transfers)
If your protocol expects one specific mint amount, you might see a check like:

```solidity
uint256 public constant TITN_ARB = 173_700_000 * 10**18;

if (amount != TITN_ARB) {
    revert InvalidAmountReceived();
}
```

Such a guard will reject any bridged transfer whose post‑dust amount doesn’t match the constant.

4. To transfer a cross-chain message you call the send() function always.
