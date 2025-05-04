# Understanding Decimals in Blockchain and Token Systems

## Introduction
Decimals are a fundamental concept in blockchain token systems that determine how tokens are divided and represented. They play a crucial role in ensuring accurate token transfers, especially in cross-chain operations.

## What are Decimals?
Decimals represent the divisibility of a token - essentially, they define how many smaller units make up one whole token. Think of it like currency denominations:

- If decimals = 2, then 100 pieces = 1 token (like cents in a dollar)
- If decimals = 9, then 1,000,000,000 pieces = 1 token (like in Solana)
- If decimals = 18, then 1,000,000,000,000,000,000 pieces = 1 token (like in Ethereum)

## Types of Decimals

### 1. Local Decimals
Local decimals refer to the native decimal precision used by a token on its original blockchain. Different blockchains have different standard decimal places:

- **Ethereum (ERC-20)**: Typically 18 decimals
- **Solana (SPL)**: Typically 9 decimals
- **Bitcoin**: 8 decimals (satoshi)
- **Binance Smart Chain**: 18 decimals
- **Polygon**: 18 decimals

### 2. Shared Decimals
Shared decimals are a standardized decimal precision used across multiple blockchains to facilitate consistent token representation and prevent precision loss during cross-chain transfers. This value is often set to a lower number (commonly 6 or 8) to accommodate blockchains with lower native decimal support.

## Why Decimals Matter

### 1. Precision and Accuracy
Decimals ensure that tokens can be divided into smaller units, allowing for precise transactions. Without proper decimal handling:

- Small transactions might become impossible
- Rounding errors could occur
- Value could be lost in transfers

### 2. Cross-Chain Compatibility
When tokens move between different blockchains, their decimal representations must be aligned to prevent:

- Loss of precision
- Incorrect token amounts
- Failed transactions

## Mathematical Formulas and Calculations

### 1. Basic Token Unit Calculation
The number of smallest units in one token is calculated as:

```
Smallest Units = 10^decimals
```

Examples:
- For 2 decimals: 10² = 100 units
- For 9 decimals: 10⁹ = 1,000,000,000 units
- For 18 decimals: 10¹⁸ = 1,000,000,000,000,000,000 units

### 2. Conversion Between Different Decimal Systems

#### Forward Conversion (Higher to Lower Decimals)
When converting from a higher decimal system to a lower one:

```
Converted Amount = Original Amount / 10^(source_decimals - target_decimals)
```

Example: Converting 1 ETH (18 decimals) to 6 decimals:
```
1 ETH = 1 * 10^18 units
Converted Amount = 1 * 10^18 / 10^(18-6) = 1 * 10^12 units
```

#### Backward Conversion (Lower to Higher Decimals)
When converting from a lower decimal system to a higher one:

```
Converted Amount = Original Amount * 10^(target_decimals - source_decimals)
```

Example: Converting 1 SOL (9 decimals) to 18 decimals:
```
1 SOL = 1 * 10^9 units
Converted Amount = 1 * 10^9 * 10^(18-9) = 1 * 10^18 units
```

### 3. Cross-Chain Transfer Calculations

#### Using Shared Decimals
When transferring between chains with different local decimals through shared decimals:

1. First conversion (Source to Shared):
```
Shared Amount = Source Amount / 10^(source_decimals - shared_decimals)
```

2. Second conversion (Shared to Target):
```
Target Amount = Shared Amount * 10^(target_decimals - shared_decimals)
```

Example: Transferring 1 ETH (18 decimals) to Solana (9 decimals) with shared decimals = 6:
```
1. ETH to Shared: 1 * 10^18 / 10^(18-6) = 1 * 10^12 shared units
2. Shared to SOL: 1 * 10^12 * 10^(9-6) = 1 * 10^15 SOL units
```

### 4. Precision Loss Calculation
The maximum precision loss when converting between decimals can be calculated as:

```
Precision Loss = 1 / 10^min(source_decimals, target_decimals)
```

Example: Converting between 18 and 9 decimals:
```
Precision Loss = 1 / 10^9 = 0.000000001
```

## Common Issues with Decimals

### 1. Unvalidated Decimal Assignments
Example: [Insufficient check on asset decimals input](https://solodit.cyfrin.io/issues/m-05-insufficient-check-on-asset-decimals-input-in-create_pool-allows-malicious-pool-to-be-created-with-invalid-swap-results-code4rena-mantra-mantra-git)

In this vulnerability, the protocol allows any user to create a new pool and specify the asset_decimals manually during creation. These decimals are not validated against the actual token metadata (e.g., via decimals() on a CW20/ERC20), and are instead trusted blindly and used in critical arithmetic within the StableSwap AMM logic.

Because of this:

- If the user provides incorrect decimals (e.g., claiming a 6-decimal token has 18), then:
  - Swaps get scaled incorrectly, leading to users receiving much less than expected
  - Liquidity provision is mispriced, breaking slippage assumptions
  - The pool becomes permanently broken, with no way to correct decimals post-creation

This opens the door to malicious pool creators setting traps for unsuspecting users, or manipulating pool behavior for MEV.

### 2. Improper Scaling with Different Mint Values
Example: [Stable swap pools don't properly handle assets with different decimals](https://solodit.cyfrin.io/issues/h-06-stable-swap-pools-dont-properly-handle-assets-with-different-decimals-forcing-lps-to-receive-wrong-shares-code4rena-mantra-mantra-git)

When you deposit tokens to mint LP shares in the Mantra stableswap pool, the contract forgets to scale tokens by their decimals. That's a big deal.

#### Example:
- USDC has 6 decimals → 1 USDC = 1_000_000
- WETH has 18 decimals → 1 WETH = 1_000_000_000_000_000_000

If you give 1 WETH and 1 USDC, the code thinks you gave:
- WETH: 1e18
- USDC: 1e6

Even though they're both worth about the same in dollars.

Because of this, the pool thinks you added way more value than you really did when using 18-decimal tokens like WETH. That means:

- You get more LP tokens than you should → you can drain value from the pool
- Curve-style pools are supposed to normalize all token amounts to the same scale before doing math (like computing the invariant D), but Mantra skips this step during LP minting

More references 
- [https://solodit.cyfrin.io/issues/h-01-sale-token-amount-is-not-adjusted-per-its-decimals-pashov-audit-group-none-defiapp_2025-01-08-markdown]
### 3. Hardcoded Decimal Values
Example of problematic code:[https://solodit.cyfrin.io/issues/h-06-omooracle-incorrect-token-decimals-handling-in-getusdvalue-and-convertusdtotoken-pashov-audit-group-none-omo_2025-01-25-markdown]

```solidity
function getUSDValue(address token, uint256 amount) public view returns (uint256) {
    uint8 decimals = priceFeed.decimals();
    uint256 normalizedPrice = uint256(price) * 1e18 / 10**decimals;
    return (amount * normalizedPrice) / 1e18;
}
```

The decimals are hardcoded here, which can lead to issues when dealing with tokens that have different decimal places.
