# Rent-Related Security Issues in Solana Programs - Checklist

> Reference: Both items below are from Pumpscience contest https://code4rena.com/audits/2025-01-pump-science/

## ✓ [M-1] Verify Rent-Exempt Status Before Lamport Transfers

### Why This Matters
- [ ] Prevents account data loss when balance falls below rent-exempt minimum
- [ ] Protects against program state corruption
- [ ] Avoids potential denial of service conditions
- [ ] Prevents unexpected program failures

### Implementation Checklist
- [ ] Calculate the minimum rent-exempt balance for each account
  ```rust
  let rent = Rent::get()?;
  let minimum_balance = rent.minimum_balance(account.data_len());
  ```
- [ ] Verify post-transfer balance will remain above rent-exempt threshold
  ```rust
  if account.lamports() - amount < minimum_balance {
      return Err(ProgramError::InsufficientFunds);
  }
  ```
- [ ] Re-verify rent exemption if transfer amount changes after initial checks
  ```rust
  // After calculating final_amount
  if from.lamports() - final_amount < minimum_balance {
      return Err(ProgramError::InsufficientFunds);
  }
  ```
- [ ] Include safety checks in all lamport transfer functions
  ```rust
  // AVOID THIS (unsafe - no rent check)
  fn unsafe_transfer(from: &AccountInfo, to: &AccountInfo, amount: u64) -> Result<()> {
      **from.try_borrow_mut_lamports()? -= amount;
      **to.try_borrow_mut_lamports()? += amount;
      Ok(())
  }
  
  // DO THIS INSTEAD (safe - with rent check)
  fn safe_transfer(from: &AccountInfo, to: &AccountInfo, amount: u64) -> Result<()> {
      let rent = Rent::get()?;
      let minimum_balance = rent.minimum_balance(from.data_len());
      
      if from.lamports() - amount < minimum_balance {
          return Err(ProgramError::InsufficientFunds);
      }
      
      **from.try_borrow_mut_lamports()? -= amount;
      **to.try_borrow_mut_lamports()? += amount;
      Ok(())
  }
  ```

## ✓ [M-2] Exclude Rent-Exempt Lamports from Asset Calculations

### Why This Matters
- [ ] Ensures accurate validation of protocol invariants
- [ ] Prevents economic vulnerabilities
- [ ] Maintains correct accounting of available assets

### Implementation Checklist
- [ ] When comparing SOL balances, subtract rent-exempt amounts
  ```rust
  // AVOID THIS (incorrect - includes rent in balance check)
  let sol_escrow_lamports = sol_escrow.lamports();
  if sol_escrow_lamports < bonding_curve.real_sol_reserves {
      return Err(ContractError::BondingCurveInvariant.into());
  }
  
  // DO THIS INSTEAD (correct - excludes rent from balance check)
  let rent = Rent::get()?;
  let rent_exempt_minimum = rent.minimum_balance(sol_escrow.data_len());
  let available_lamports = sol_escrow.lamports() - rent_exempt_minimum;
  if available_lamports < bonding_curve.real_sol_reserves {
      return Err(ContractError::BondingCurveInvariant.into());
  }
  ```
- [ ] Subtract rent-exempt minimums from total balances in protocol invariants
- [ ] Treat only non-rent lamports as available assets in economic calculations
- [ ] Be aware of potential issues shown by this example scenario:
  - Required reserves: 100 SOL (100,000,000,000 lamports)
  - Rent-exempt minimum: 0.00204928 SOL (2,039,280 lamports)  
  - Total account balance: 100 SOL (100,000,000,000 lamports)
  - Actual available SOL: 99.99795072 SOL (99,997,960,720 lamports)
  - Result: Incorrect check passes (100 SOL ≥ 100 SOL) even though the actual available balance is insufficient!

