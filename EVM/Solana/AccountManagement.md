# Account Management Security Checks

## Security Checklist

- [ ] Properly close accounts and collect rent
- [ ] Protect against account reinitialization
- [ ] Validate account space calculations
- [ ] Handle ATA creation and existence checks
- [ ] Consider rent-exempt minimum in transfers
- [ ] Maintain atomic operations and data consistency
- [ ] Implement proper error handling for updates
- [ ] Validate account state transitions

## Detailed Security Measures

### Account Closing

- Always properly close accounts to prevent resource leaks
- Ensure rent collection during account closure

```rust
// ❌ Bad: No proper account closing
#[account(mut)]
pub account_to_close: Account<'info, MyAccount>

// ✅ Good: Proper account closing with rent collection
#[account(mut, close = recipient)]
pub account_to_close: Account<'info, MyAccount>
```

### Reinitialization Protection

- Avoid using `init_if_needed` without proper checks
- Always validate account initialization state

```rust
// ❌ Bad: Unsafe reinitialization
#[account(init_if_needed, ...)]

// ✅ Good: Safe initialization with checks
#[account(
    init,  // Requires explicit initialization
    payer = payer,
    space = 8 + 32,
    constraint = !account.is_initialized
)]
pub account: Account<'info, MyData>,
#[account(constraint = signer.key == account.owner)]
pub signer: Signer<'info>
```

### Account Space Validation

- Use `#[derive(InitSpace)]` for accurate account space calculation
- Always validate account space before operations

```rust
// ❌ Bad: Manual space calculation
#[account(init, payer = payer, space = 8 + 32)]

// ✅ Good: Using InitSpace derive macro
#[derive(InitSpace)]
#[account(init, payer = payer)]
pub struct MyAccount {
    data: u64,
    authority: Pubkey,
}
```

### Associated Token Account (ATA) Management

- Handle ATA creation carefully
- Check ATA existence before operations
- Use proper error handling for ATA operations

```rust
// ❌ Bad: No ATA existence check
#[account(init)]
pub ata: Account<'info, TokenAccount>;

// ✅ Good: Safe ATA handling
#[account(
    init_if_needed,
    payer = payer,
    associated_token::mint = mint,
    associated_token::authority = authority
)]
pub ata: Account<'info, TokenAccount>;
```

### Rent Consideration

- Always consider rent-exempt minimum when transferring lamports
- Account for rent in asset calculations

```rust
// ❌ Bad: Not considering rent
let transfer_amount = account.lamports();

// ✅ Good: Consider rent-exempt minimum
let rent = Rent::get()?;
let rent_exempt_min = rent.minimum_balance(account.data_len());
let transfer_amount = account.lamports().checked_sub(rent_exempt_min)
    .ok_or(ProgramError::InsufficientFunds)?;
```

## Account Data Consistency

- Maintain data consistency across account updates
- Use atomic operations when possible
- Implement proper error handling for failed updates

```rust
// ❌ Bad: No atomic updates
account.balance = new_balance;
account.last_update = clock.unix_timestamp;

// ✅ Good: Atomic updates with error handling
account.balance = account.balance.checked_add(amount)
    .ok_or(ProgramError::Overflow)?;
account.last_update = Clock::get()?.unix_timestamp;
``` 