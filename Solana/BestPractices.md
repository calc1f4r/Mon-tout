# Solana Security Best Practices

## General Security Guidelines

- [ ] Always use checked arithmetic operations
- [ ] Validate all account permissions
- [ ] Implement proper error handling
- [ ] Use typed accounts when possible
- [ ] Validate program IDs
- [ ] Protect against reentrancy
- [ ] Implement proper access controls
- [ ] Do not use hardcoded values (see [example](https://code4rena.com/reports/2025-01-pump-science#11-hardcoded-program-ids-in-constants-create-deployment-inflexibility-and-testing-challenges))

## Code Examples

### Checked Arithmetic

```rust
// ✅ Use checked operations
let balance = account.balance.checked_add(amount)
    .ok_or(ProgramError::Overflow)?;
let result = total.checked_mul(rate)
    .ok_or(ProgramError::Overflow)?
    .checked_div(RATE_DENOMINATOR)
    .ok_or(ProgramError::Overflow)?;
```

### Error Handling

```rust
// ✅ Custom error types
#[error_code]
pub enum MyError {
    #[msg("Invalid authority provided")]
    InvalidAuthority,
    #[msg("Account not initialized")]
    NotInitialized,
    #[msg("Insufficient balance")]
    InsufficientBalance,
}

// ✅ Proper error handling
fn process_transaction(ctx: Context<Transaction>) -> Result<()> {
    if ctx.accounts.balance < ctx.accounts.amount {
        return Err(MyError::InsufficientBalance.into());
    }
    Ok(())
}
```

### Account Type Safety

```rust
// ✅ Use typed accounts
#[derive(Accounts)]
pub struct Transaction<'info> {
    #[account(mut)]
    pub from: Account<'info, TokenAccount>,
    #[account(mut)]
    pub to: Account<'info, TokenAccount>,
    pub authority: Signer<'info>,
}
```

### Program ID Validation

```rust
// ✅ Validate program IDs
#[account(constraint = token_program.key == &spl_token::ID)]
pub token_program: Program<'info, Token>
```

### Access Control

```rust
// ✅ Implement proper access controls
#[account(
    mut,
    has_one = authority,
    constraint = !account.is_frozen
)]
pub account: Account<'info, MyAccount>,
pub authority: Signer<'info>
```

## Security Checklist

### Account Validation
- [ ] Validate all account owners
- [ ] Check account permissions
- [ ] Verify account relationships
- [ ] Validate program IDs

### Data Safety
- [ ] Use checked arithmetic
- [ ] Validate all inputs
- [ ] Handle edge cases
- [ ] Implement proper error types

### Access Control
- [ ] Validate signers
- [ ] Check authorities
- [ ] Implement proper constraints
- [ ] Handle permissions correctly

### Program Interaction
- [ ] Validate CPIs
- [ ] Check program IDs
- [ ] Handle cross-program results
- [ ] Protect against reentrancy

### State Management
- [ ] Validate state transitions
- [ ] Handle initialization properly
- [ ] Implement atomic updates
- [ ] Maintain data consistency

## Common Pitfalls to Avoid

- [ ] Unchecked Arithmetic
```rust
// ❌ Bad
let balance = account.balance + amount;

// ✅ Good
let balance = account.balance.checked_add(amount)
    .ok_or(ProgramError::Overflow)?;
```

- [ ] Missing Signer Checks
```rust
// ❌ Bad
fn process(ctx: Context<Tx>) -> Result<()> {
    // No signer check
    Ok(())
}

// ✅ Good
fn process(ctx: Context<Tx>) -> Result<()> {
    if !ctx.accounts.authority.is_signer {
        return Err(ProgramError::MissingRequiredSignature);
    }
    Ok(())
}
```

- [ ] Improper Error Handling
```rust
// ❌ Bad
if error_condition {
    return Ok(()); // Silently failing
}

// ✅ Good
if error_condition {
    return Err(MyError::CustomError.into());
}
```

- [ ] Unvalidated Account Types
```rust
// ❌ Bad
pub account: AccountInfo<'info>

// ✅ Good
pub account: Account<'info, MyAccount>
```

## Testing Recommendations

- [ ] Test Edge Cases
```rust
#[test]
fn test_overflow() {
    let result = calculate_amount(u64::MAX, 2);
    assert!(result.is_err());
}
```

- [ ] Test Access Control
```rust
#[test]
fn test_unauthorized_access() {
    let result = process_instruction(wrong_signer);
    assert_eq!(result, Err(MyError::InvalidAuthority));
}
```

- [ ] Test State Transitions
```rust
#[test]
fn test_invalid_state_transition() {
    let result = transition_state(State::Uninitialized, State::Active);
    assert!(result.is_err());
}
```