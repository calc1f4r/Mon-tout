# Bonding Curve Implementation Security Checklist

- [ ] For mint to be there on raydium, there should be no mint authority on that mint 
- [ ] For mint to be usable with Raydium pools, freeze authority must be disabled

## Critical Security Considerations

### 1. Mint Authority Management

- **Revoke mint authority** after minting tokens to the bonding curve
  - Once you've minted the necessary amount of tokens to the AMM/bonding curve, immediately revoke the mint authority
  - This prevents additional tokens from being created later, protecting the tokenomics
  - Failure to do this could allow unauthorized inflation of token supply

### 2. Bonding Curve Implementation

- Ensure mathematical formula is correctly implemented
- Verify price slippage protection mechanisms
- Test edge cases (very small purchases, very large purchases)
- Implement circuit breakers for unexpected market conditions

### 3. Token Configuration

- Set appropriate decimals for your token
- **Do not enable freeze authority** 
  - Raydium liquidity pools require tokens with freeze authority disabled
  - Enabling freeze authority will permanently block migration to Raydium
  - This will render the protocol unusable and lock collected funds
- Document token distribution approach

### 4. Testing Requirements

- Test mint authority revocation process
- Verify no further minting is possible after revocation
- Simulate various trading scenarios to ensure curve behavior
- Verify freeze authority is not set during token initialization

### 5. AMM Configuration Validation

// if you are takin quote deimals and base_Decimals as the amount then it should be validated
- **Validate all AMM configuration parameters carefully**
  - Ensure `quote_decimals` and `base_decimals` match the actual token decimals
  - Verify `market_id` corresponds correctly to the specified trading pair
  - Failure to validate these parameters can lead to critical failures
  - This validation should happen during contract instantiation

#### Potential Vulnerabilities:

- **Incorrect Market ID**: If the `market_id` doesn't match the intended trading pair, the IDO won't finalize as the underlying market doesn't exist or is inactive
- **Decimal Mismatch**: Incorrect decimals lead to calculation errors:
  - Too small: Results in insufficient initial capital commitment, causing imbalances and reduced liquidity
  - Too large: May cause subscription amounts to exceed available funds, resulting in IDO failure

#### Example Vulnerability:

```rust
// INCORRECT IMPLEMENTATION - No validation of AMM configuration
#[cfg_attr(not(feature = "library"), entry_point)]
pub fn instantiate(
    deps: DepsMut<InjectiveQueryWrapper>,
    env: Env,
    info: MessageInfo,
    msg: InstantiateMsg,
) -> Result<Response<InjectiveMsgWrapper>, ContractError> {
    // ...
    let config = Config {
        // ...
        amm_launch_config: msg.amm_launch_config, // No validation performed!
        // ...
    }
    // ...
}
```

#### Recommended Implementation:

```rust
// CORRECT IMPLEMENTATION - With validation
#[cfg_attr(not(feature = "library"), entry_point)]
pub fn instantiate(
    deps: DepsMut<InjectiveQueryWrapper>,
    env: Env,
    info: MessageInfo,
    msg: InstantiateMsg,
) -> Result<Response<InjectiveMsgWrapper>, ContractError> {
    // Validate AMM configuration
    validate_market_id(&deps, &msg.amm_launch_config.market_id, 
                      &msg.amm_launch_config.quote_denom, 
                      &msg.amm_launch_config.project_token_denom)?;
    validate_token_decimals(&deps, &msg.amm_launch_config.quote_denom, 
                           msg.amm_launch_config.quote_decimals)?;
    validate_token_decimals(&deps, &msg.amm_launch_config.project_token_denom, 
                           msg.amm_launch_config.base_decimals)?;
    
    let config = Config {
        // ...
        amm_launch_config: msg.amm_launch_config,
        // ...
    }
    // ...
}
```

## Implementation Notes

When implementing a bonding curve on Solana:
1. Initialize token with appropriate supply
2. Transfer tokens to the bonding curve/AMM contract
3. **Call `set_authority` with authority type `MintTokens` and set new authority to `None`**
4. Verify authority has been properly revoked before launching

## Resources

- [Solana Token Program Documentation](https://spl.solana.com/token)
- [Bonding Curve Design Patterns](https://medium.com/linum-labs/bonding-curves-in-depth-intuition-parametrization-d3905a681e0a)

## Sample Code for Revoking Mint Authority

```rust
// After minting tokens to the bonding curve:
let revoke_ix = spl_token::instruction::set_authority(
    &token_program.key(),
    &mint.key(),
    None,
    spl_token::instruction::AuthorityType::MintTokens,
    &mint_authority.key(),
    &[&mint_authority.key()],
)?;

invoke_signed(
    &revoke_ix,
    // Accounts...
    // Seeds...
)?;
```

## AMM Fee Logic Invariants

### Critical Invariant: Fees Must Be Applied to Quote Assets

One invariant of bonding curve implementations is that fees should always be applied to the quote asset, not the base asset. Violations of this invariant can lead to significant calculation errors:

#### Common Implementation Issues:

- **Incorrect Fee Application Point**: Applying fees after converting quote to base assets
- **Early Limit Order Termination**: Stopping orders early to account for fees, preventing users from benefiting from potential price improvements
- **Post-Swap Price Mechanism Issues**: After consuming limit orders, the pricing mechanism may not reset properly

#### Example Vulnerability:

```rust
// INCORRECT IMPLEMENTATION - Fee applied to base asset after conversion
let size_in_base = self.post_fee_adjust_rounded_down(
    size_in_quote * base_snapshot / quote_snapshot,
);
let fee_in_quote = self.fee_rounded_down(size_in_quote);
```

The correct approach is to:
1. Calculate and apply fees to the quote asset first
2. Then convert the post-fee quote amount to the base asset
3. Ensure limit orders fully execute at the actual limit price
4. Reset price mechanisms properly after swaps

This ensures accurate price calculations and prevents unfair order executions across the bonding curve.



After the real_token_reserves are zero , then set the bonding curve to complete