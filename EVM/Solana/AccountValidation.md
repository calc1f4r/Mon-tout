# Account Validation Security Checks

## Security Checklist

- [ ] [Signer not validated](#signer-validation) - Missing validation of transaction signers
- [ ] [Writer not validated](#writer-validation) - Account writability not checked before modification
- [ ] [Owner not validated](#owner-validation) - Missing account ownership verification
- [ ] [Account not initialized](#account-initialization-checks) - Account initialization status not verified
- [ ] [Missing authority check](#authority-checks) - Authority validation not implemented
- [ ] [Sysvar not validated](#system-account-validation) - System program accounts not validated
- [ ] [Account existence check](#lamports-validation) - Lamports not checked before operations
- [ ] [Missing permission check](#authority-checks) - Account permissions not verified


## Detailed Security Measures

### Signer Validation

**Impact**: High  
**Likelihood**: High  
**Description**: Missing signer validation allows unauthorized users to execute privileged operations.

**Vulnerable Code**:
```rust
// ❌ Bad: No signer validation
pub fn handler(ctx: Context<Handler>) -> Result<()> {
    // Missing signer check
    Ok(())
}
```

**Secure Code**:
```rust
// ✅ Good: Validate signer
if !payer_account.is_signer {
    return Err(ProgramError::MissingRequiredSignature);
}
```

**Prevention**:
- Always validate signers before executing privileged operations
- Use Anchor's `Signer` type when possible
- Implement proper authority checks

### Writer Validation

- Always validate if an account is writable before modification
- Prevents unauthorized account modifications

```rust
// ❌ Bad: No writable check
let state_account = next_account_info(accounts_iter)?;

// ✅ Good: Check if account is writable
let state_account = next_account_info(accounts_iter)?;
if !state_account.is_writable {
    return Err(ProgramError::InvalidAccountData);
}
```

### Owner Validation

- Always validate account ownership
- Use typed accounts when possible
- Check program ownership for security-critical operations

```rust
// ❌ Bad: Using AccountInfo without owner check
pub mint: AccountInfo<'info>

// ✅ Good: Use typed account with ownership check
pub mint: Account<'info, Mint>

// ✅ Good: Explicit owner check
#[account(constraint = authority.owner == token_program::ID)]
```

### Account Initialization Checks

- Always verify if accounts are properly initialized
- Include proper initialization constraints

```rust
// ❌ Bad: No initialization check
#[account]
pub struct StateAccount {
    data: u64,
}

// ✅ Good: Check initialization
#[account(init, payer = user, space = 8 + 8)]
pub struct StateAccount {
    data: u64,
}
```

### Authority Checks

- Validate caller permissions
- Implement proper authority validation

```rust
// ❌ Bad: No authority check
fn init_market(accounts: &[AccountInfo]) -> ProgramResult {
    Ok(())
}

// ✅ Good: Validate authority
fn init_market(accounts: &[AccountInfo]) -> ProgramResult {
    let authority = next_account_info(accounts_iter)?;
    if *authority.key != AUTHORIZED_KEY {
        return Err(ProgramError::InvalidAuthority);
    }
    Ok(())
}
```

### System Account Validation

- Always validate system program accounts
- Check for correct program IDs

```rust
// ❌ Bad: No system account validation
let token_program_id = next_account_info(account_info_iter)?;

// ✅ Good: Validate system account
if *token_program_id.key != spl_token::ID {
    return Err(ProgramError::IncorrectProgramId);
}
```

### Lamports Validation

- Check lamports before account operations
- Ensure sufficient balance for operations

```rust
// ❌ Bad: Reading account data without lamports check
let data = account.try_borrow_data()?;

// ✅ Good: Check lamports before reading
if account.try_borrow_lamports()? > 0 {
    let data = account.try_borrow_data()?;
}
``` 