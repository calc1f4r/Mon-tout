# Program Derived Address (PDA) Security

## Table of Contents
- [Security Checklist](#security-checklist)
- [Detailed Security Measures](#detailed-security-measures)
  - [PDA Validation](#pda-validation)
  - [PDA Sharing Protection](#pda-sharing-protection)
  - [Safe Lamport Transfers](#safe-lamport-transfers)
  - [Seed Collision Prevention](#seed-collision-prevention)
  - [PDA Reinitialization Protection](#pda-reinitialization-protection)
  - [Bump Seed Validation](#bump-seed-validation)
  - [PDA Account Space Management](#pda-account-space-management)

## Security Checklist

- [ ] [Validate PDA derivation and bump seeds](#pda-validation)
- [ ] [Implement PDA sharing protection with unique seeds](#pda-sharing-protection)
- [ ] [Use safe lamport transfers with proper signing](#safe-lamport-transfers)
- [ ] [Prevent seed collisions with unique prefixes](#seed-collision-prevention)
- [ ] [Protect against PDA reinitialization](#pda-reinitialization-protection)
- [ ] [Validate and store bump seeds properly](#bump-seed-validation)
- [ ] [Calculate PDA space requirements accurately](#pda-account-space-management)
- [ ] [Verify program ownership of PDAs](#pda-validation)
- [ ] [Handle PDA authority checks correctly](#pda-sharing-protection)

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

[Back to Top](#program-derived-address-pda-security)

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

[Back to Top](#program-derived-address-pda-security)

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

[Back to Top](#program-derived-address-pda-security)

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

[Back to Top](#program-derived-address-pda-security)

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

[Back to Top](#program-derived-address-pda-security)

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

[Back to Top](#program-derived-address-pda-security)

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

[Back to Top](#program-derived-address-pda-security)