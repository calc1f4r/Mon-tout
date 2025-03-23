# Bump Seed Security Issues

## Security Checklist

- [ ] [Missing Bump in Signer Seeds](#missing-bump-in-signer-seeds) - Bump seed not included in PDA signer seeds
- [ ] [Invalid Seeds Structure](#invalid-seeds-structure) - Incorrect structure of seeds for PDA derivation 
- [ ] [Inconsistent Bump Usage](#inconsistent-bump-usage) - Inconsistent bump usage across program functions
- [ ] [Unvalidated PDA Derivation](#unvalidated-pda-derivation) - PDA derivation not properly validated
- [ ] [Bump Not Stored](#bump-not-stored) - Bump seed not stored for future reference
- [ ] [Missing CPI Bump](#missing-cpi-bump) - Bump not included in seeds during cross-program invocation

## Detailed Security Measures

### Missing Bump in Signer Seeds

**Impact**: Critical  
**Likelihood**: High  
**Description**: When a PDA signs transactions, the bump seed must be included in the signer seeds array. Missing bump seeds cause transactions to fail due to invalid signatures, potentially resulting in loss of funds when tokens are stuck in accounts that require PDA signatures.

**Vulnerable Code**:
```rust
// ❌ Bad: Bump seed missing from seeds array
pub fn seeds(&self) -> [&[u8]; 2] {
    [
        REBATEMANAGER_SEED.as_bytes(),
        self.quote_token_mint.as_ref(),
    ]
}

// When used for signing:
invoke_signed(
    &instruction,
    accounts,
    &[&rebate_manager.seeds()]  // Missing bump!
)?;
```

**Secure Code**:
```rust
// ✅ Good: Include bump in seeds array
pub fn seeds(&self) -> [&[u8]; 3] {
    [
        REBATEMANAGER_SEED.as_bytes(),
        self.quote_token_mint.as_ref(),
        &[self.bump],
    ]
}

// Or with seeds_with_bump method:
pub fn seeds(&self) -> [&[u8]; 2] {
    [
        REBATEMANAGER_SEED.as_bytes(),
        self.quote_token_mint.as_ref(),
    ]
}

pub fn seeds_with_bump(&self) -> [&[u8]; 3] {
    let mut seeds = self.seeds().to_vec();
    seeds.push(&[self.bump]);
    seeds.try_into().unwrap()
}
```

**Prevention**:
- Always include bump seed when signing transactions with PDAs
- Create helper functions that consistently include bump seeds
- Store bump seed when initializing PDAs
- Test PDA signatures with proper bump inclusion

**Real-World Example**:
The Rebate Manager in WooFi Solana has a token vault owned by a PDA. Transfer functions fail because the bump is not included in signing:

```rust
// Transfer failing due to missing bump in seeds
fn transfer_from_vault_to_owner(&self, amount: u64) -> Result<()> {
    let cpi_accounts = Transfer {
        from: self.token_vault.to_account_info(),
        to: self.owner_token_account.to_account_info(),
        authority: self.rebate_manager.to_account_info(),
    };

    let cpi_program = self.token_program.to_account_info();
    let seeds = self.rebate_manager.seeds();
    let signer_seeds = &[&seeds[..]]; // Missing bump!

    transfer(
        CpiContext::new_with_signer(cpi_program, cpi_accounts, signer_seeds),
        amount,
    )?;
    Ok(())
}
```

### Invalid Seeds Structure

**Impact**: Critical  
**Likelihood**: Medium  
**Description**: Incorrect structure of seeds when deriving PDAs or signing with PDAs can lead to unexpected addresses or failed transactions.

**Vulnerable Code**:
```rust
// ❌ Bad: Inconsistent seed structure
let seeds = &[b"seed", &[bump]]; // Seeds structure doesn't match original derivation
```

**Secure Code**:
```rust
// ✅ Good: Consistent seed structure
let seeds = &[b"seed", authority.key.as_ref(), &[bump]];
```

### Inconsistent Bump Usage

**Impact**: High  
**Likelihood**: Medium  
**Description**: Using different bump values across program functions can cause address mismatches and failed transactions.

**Secure Code**:
```rust
// ✅ Good: Store and use consistent bump
#[account(
    init,
    payer = payer,
    space = 8 + 32 + 1, // Include space for bump
    seeds = [b"vault", authority.key.as_ref()],
    bump
)]
pub vault: Account<'info, Vault>,

// In the Vault struct:
pub struct Vault {
    pub authority: Pubkey,
    pub bump: u8,
}

// Later, using the stored bump
let signer_seeds = &[
    b"vault".as_ref(),
    authority.key.as_ref(),
    &[vault.bump],
];
```

### Unvalidated PDA Derivation

**Impact**: High  
**Likelihood**: Medium  
**Description**: Not validating PDA derivation can lead to security vulnerabilities where incorrect PDAs are accepted.

**Secure Code**:
```rust
// ✅ Good: Validate PDA derivation
let (expected_pda, _bump) = Pubkey::find_program_address(
    &[b"seed", authority.key.as_ref()],
    program_id
);
require!(
    expected_pda == *pda_account.key,
    ErrorCode::InvalidPDA
);
```

### Bump Not Stored

**Impact**: Medium  
**Likelihood**: High  
**Description**: Not storing the bump seed can make it difficult to consistently use the correct bump in future operations.

**Secure Code**:
```rust
// ✅ Good: Store bump during initialization
#[account(
    init,
    payer = payer,
    space = 8 + 32 + 1, // Include space for bump
    seeds = [b"vault", authority.key.as_ref()],
    bump,
)]
pub vault: Account<'info, Vault>,

// In the Vault struct:
pub struct Vault {
    pub authority: Pubkey,
    pub bump: u8,
}
```

### Missing CPI Bump

**Impact**: Critical  
**Likelihood**: High  
**Description**: Not including bump when performing cross-program invocations that require PDA signing will cause transactions to fail.

**Vulnerable Code**:
```rust
// ❌ Bad: CPI without bump seed
let cpi_accounts = Transfer {
    from: token_vault.to_account_info(),
    to: recipient.to_account_info(),
    authority: pda.to_account_info(),
};
let signer_seeds = &[&[b"vault", owner.key.as_ref()][..]];  // Missing bump!
transfer(CpiContext::new_with_signer(token_program, cpi_accounts, signer_seeds), amount)?;
```

**Secure Code**:
```rust
// ✅ Good: CPI with bump seed
let cpi_accounts = Transfer {
    from: token_vault.to_account_info(),
    to: recipient.to_account_info(),
    authority: pda.to_account_info(),
};
let signer_seeds = &[&[b"vault", owner.key.as_ref(), &[bump]][..]];
transfer(CpiContext::new_with_signer(token_program, cpi_accounts, signer_seeds), amount)?;
```

## Best Practices for Bump Seed Management

1. Always store bump seeds in PDA accounts when initializing them
2. Create consistent helper methods for generating seed arrays with bumps
3. Validate PDA derivation before important operations
4. Use proper seed structures that match the original PDA derivation
5. Include bump seeds in all signing operations
6. Test PDA signing operations thoroughly
7. Create reusable utility functions for common PDA operations

