# Program Derived Address (PDA) Security

## Security Checklist

- [ ] Validate PDA derivation and bump seeds
- [ ] Implement PDA sharing protection with unique seeds
- [ ] Use safe lamport transfers with proper signing
- [ ] Prevent seed collisions with unique prefixes
- [ ] Protect against PDA reinitialization
- [ ] Validate and store bump seeds properly
- [ ] Calculate PDA space requirements accurately
- [ ] Verify program ownership of PDAs
- [ ] Handle PDA authority checks correctly

## Detailed Security Measures

### PDA Validation

- Always validate PDA derivation
- Check bump seeds
- Verify program ownership

```rust
// ✅ Good: PDA validation
let (pda, bump) = Pubkey::find_program_address(
    &[b"seed", authority.key.as_ref()],
    program_id
);
if pda != *pda_account.key {
    return Err(ProgramError::InvalidSeeds);
}
```

### PDA Sharing Protection

- Prevent unauthorized PDA access
- Use unique seeds to prevent collisions
- Implement proper ownership checks

```rust
// ✅ Good: PDA ownership and access control
#[account(
    init,
    payer = payer,
    space = 8 + 32,
    seeds = [b"vault", owner.key.as_ref()],
    bump
)]
pub vault: Account<'info, Vault>,
#[account(constraint = authority.key == vault.owner)]
pub authority: Signer<'info>
```

### Safe Lamport Transfers

- Use proper signing for PDA transfers
- Include all necessary seeds
- Validate transfer amounts

```rust
// ✅ Good: Safe PDA lamport transfer
invoke_signed(
    &system_instruction::transfer(
        pda_account.key,
        recipient.key,
        lamports,
    ),
    &[pda_account.clone(), recipient.clone(), system_program.clone()],
    &[&[b"vault", owner.key.as_ref(), &[bump]]]
)?;
```

### Seed Collision Prevention

- Use unique prefixes for seeds
- Include sufficient entropy in seeds
- Validate seed uniqueness

```rust
// ✅ Good: Unique PDA seeds
let (pda, bump) = Pubkey::find_program_address(
    &[
        b"unique_prefix",
        owner.key.as_ref(),
        token_mint.key.as_ref()
    ],
    program_id
);
```

### PDA Reinitialization Protection

- Prevent unauthorized reinitialization
- Check initialization state
- Implement proper access controls

```rust
// ✅ Good: PDA initialization protection
#[account(
    init,
    payer = payer,
    space = 8 + 32,
    seeds = [b"vault", owner.key.as_ref()],
    bump,
    constraint = !vault.is_initialized
)]
pub vault: Account<'info, Vault>
```

### Bump Seed Validation

- Always validate bump seeds
- Use find_program_address instead of create_program_address
- Store bump seed for future validation

```rust
// ❌ Bad: Using create_program_address
let pda = Pubkey::create_program_address(&seeds, program_id)?;

// ✅ Good: Using find_program_address with bump validation
let (pda, bump) = Pubkey::find_program_address(&seeds, program_id);
vault.bump = bump;  // Store for future validation
```

### PDA Account Space Management

- Calculate space requirements accurately
- Include discriminator in space calculation
- Account for future data growth

```rust
// ✅ Good: Proper PDA space allocation
#[account(
    init,
    payer = payer,
    space = 8 +  // Discriminator
            32 + // Pubkey
            8 +  // u64
            1,   // bump
    seeds = [b"vault", owner.key.as_ref()],
    bump
)]
pub vault: Account<'info, Vault>
``` 