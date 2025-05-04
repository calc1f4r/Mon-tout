# Solana Security Checks

1.  **Signer Check:** Ensure appropriate accounts have signed the transaction.
    ```rust
    // Example: Check if the authority signed
    if !ctx.accounts.authority.is_signer {
        return err!(ErrorCode::MissingAuthoritySignature);
    }
    ```
2.  **Writer Check:** Verify that accounts being written to are correctly specified and authorized.
    ```rust
    // Example: Check if the target account is marked as writable
    if !ctx.accounts.target_account.to_account_info().is_writable {
        return err!(ErrorCode::AccountNotWritable);
    }
    // Example: Check if the writer has permission (e.g., is the owner)
    if ctx.accounts.target_account.owner != *ctx.accounts.authority.key {
        return err!(ErrorCode::UnauthorizedWrite);
    }
    ```
3.  **Improper Closing of Token Account:**
    *   A non-WSOL account should not be closable if it still holds SOL (lamports).
        ```rust
        // Example: Check lamport balance before closing
        if !ctx.accounts.token_account_to_close.is_native() && ctx.accounts.token_account_to_close.lamports() > 0 {
             // Check if it's the system program trying to close, allow if so (rent collection)
             if *ctx.program_id != system_program::ID {
                 return err!(ErrorCode::AccountStillHasLamports);
             }
        }
        ```
    *   **Token Program (Standard):** A token account can generally be closed if its token balance is zero.
        ```rust
        // Example: Check token balance (using Account<'info, TokenAccount>)
        if ctx.accounts.token_account_to_close.amount > 0 {
            return err!(ErrorCode::AccountStillHasTokens);
        }
        ```
    *   **Token-2022 Program:** Additional conditions apply for closing a Token Account:
        *   `account.amount == 0` (Same check as standard Token Program)
        *   **CPI Guard Extension:** If enabled and closing via CPI, the lamport destination must be the token account owner.
            ```rust
            // Conceptual check within the Token-2022 program itself (not typically done in user programs)
            // This logic is enforced by the Token-2022 program when processing CloseAccount via CPI
            // if cpi_guard_enabled && is_cpi_call && destination_account.key() != token_account_owner.key() {
            //     return ProgramError::InvalidAccountData; // Or a specific CPI guard error
            // }
            ```
        *   **Confidential Transfer Extension:** `pending_balance == 0` and `available_balance == 0` must be true.
            ```rust
            // Example: Accessing Confidential Transfer state (requires correct account deserialization)
            use spl_token_2022::extension::confidential_transfer::ConfidentialTransferAccount;
            // ... deserialize account_data into ConfidentialTransferAccount state ...
            // let ct_state = ConfidentialTransferAccount::unpack(&account_data)?;
            // if ct_state.pending_balance_lo != 0 || ct_state.pending_balance_hi != 0 || ct_state.available_balance != 0 {
            //     return err!(ErrorCode::ConfidentialTransferAccountNotEmpty);
            // }
            // Note: Direct unpacking like this is complex; usually handled via Anchor account types if possible.
            ```
        *   **Confidential Transfer Fee Extension:** `withheld_amount == 0` must be true.
            ```rust
            // Example: Accessing Confidential Transfer Fee state
            use spl_token_2022::extension::confidential_transfer_fee::ConfidentialTransferFeeAccount;
            // ... deserialize account_data into ConfidentialTransferFeeAccount state ...
            // let ctf_state = ConfidentialTransferFeeAccount::unpack(&account_data)?;
            // if ctf_state.withheld_amount != 0 {
            //     return err!(ErrorCode::ConfidentialTransferFeeWithheld);
            // }
            ```
        *   **Transfer Fee Extension:** `withheld_amount == 0` must be true.
            ```rust
            // Example: Accessing Transfer Fee state
            use spl_token_2022::extension::transfer_fee::TransferFeeAccount;
            // ... deserialize account_data into TransferFeeAccount state ...
            // let tf_state = TransferFeeAccount::unpack(&account_data)?;
            // if tf_state.withheld_amount != 0 {
            //     return err!(ErrorCode::TransferFeeWithheld);
            // }
            ```
4.  **Mint Account Closure:** A Mint account can only be closed by its designated `close_authority`.
    ```rust
    // Example: Check close_authority on the Mint account
    use spl_token_2022::state::Mint;
    // ... deserialize mint_account data ...
    // let mint_data = Mint::unpack(&mint_account.data.borrow())?;
    // if mint_data.close_authority.is_none() {
    //     return err!(ErrorCode::MintNotClosable);
    // }
    // if mint_data.close_authority.unwrap() != *ctx.accounts.close_authority_signer.key {
    //     return err!(ErrorCode::IncorrectCloseAuthority);
    // }
    // if !ctx.accounts.close_authority_signer.is_signer {
    //     return err!(ErrorCode::MissingCloseAuthoritySignature);
    // }
    ```

5. **Token-2022 Extension Whitelist:** When using Token-2022, maintain a whitelist of allowed extensions.
    ```rust
    // Example: Check if an extension is allowed
    let allowed_extensions = [
        ExtensionType::TransferFeeConfig,
        ExtensionType::TransferFeeAmount,
        ExtensionType::MintCloseAuthority,
    ];
    
    for extension in mint.extensions.iter() {
        if !allowed_extensions.contains(&extension.extension_type) {
            return err!(ErrorCode::UnauthorizedExtension);
        }
    }
    ```

6. **Integer Truncation Issues:** Prevent integer overflow/underflow and truncation.
    ```rust
    // Example: Safe arithmetic operations
    pub fn safe_divide(numerator: u64, denominator: u64) -> Result<u64, ProgramError> {
        if denominator == 0 {
            return Err(ProgramError::InvalidArgument);
        }
        Ok(numerator / denominator)
    }

    // Example: Safe casting
    pub fn convert_token_amount(amount: u64) -> Result<u32, ProgramError> {
        u32::try_from(amount).map_err(|_| ProgramError::InvalidArgument)
    }
    ```

7. **Associated Token Account (ATA) Creation:** Handle idempotent ATA creation.
    ```rust
    // Example: Using create_associated_token_account_idempotent
    let ata = get_associated_token_address(&wallet_address, &mint_address);
    if !ata_exists(&ata) {
        create_associated_token_account_idempotent(
            &payer,
            &wallet_address,
            &mint_address,
            &spl_token::id(),
        )?;
    }
    ```

8. **Account Creation with Lamports:** Handle account creation when lamports exist.
    ```rust
    // Example: Safe account creation
    if account.lamports() > 0 {
        // Use allocate and assign instead of create_account
        allocate(&account, size)?;
        assign(&account, program_id)?;
    } else {
        create_account(
            &payer,
            &account,
            rent.minimum_balance(size),
            size,
            program_id,
        )?;
    }
    ```

9. **PDA Creation Safety:** Handle potential duplicate PDA creation.
    ```rust
    // Example: Safe PDA creation
    let (pda, bump) = Pubkey::find_program_address(&[b"unique_seed", user.key().as_ref()], program_id);
    if !pda_exists(&pda) {
        create_pda_account(
            &payer,
            &pda,
            rent.minimum_balance(size),
            size,
            program_id,
            &[b"unique_seed", user.key().as_ref(), &[bump]],
        )?;
    }
    ```

10. **Secure Randomness:** Avoid using insecure sources of randomness.
    ```rust
    // Example: Using a secure source of randomness
    let clock = Clock::get()?;
    let slot = clock.slot;
    let timestamp = clock.unix_timestamp;
    let hash = hash(&[slot.to_le_bytes(), timestamp.to_le_bytes()].concat());
    ```

11. **Fee Transfer Verification:** Ensure fees are properly transferred.
    ```rust
    // Example: Fee transfer verification
    let fee_amount = calculate_fee(amount);
    if fee_amount > 0 {
        let fee_account = get_fee_account();
        transfer_tokens(
            &source_account,
            &fee_account,
            &authority,
            fee_amount,
        )?;
    }
    ```

12. **Pause/Unpause Functionality:** Implement emergency pause mechanism.
    ```rust
    // Example: Pause functionality
    #[account]
    pub struct ProgramState {
        pub is_paused: bool,
        pub pause_authority: Pubkey,
    }

    pub fn pause(ctx: Context<Pause>) -> Result<()> {
        require!(
            ctx.accounts.pause_authority.key() == ctx.accounts.state.pause_authority,
            ErrorCode::Unauthorized
        );
        ctx.accounts.state.is_paused = true;
        Ok(())
    }
    ```

13. **Remaining Accounts Validation:** Always validate remaining accounts.
    ```rust
    // Example: Remaining accounts validation
    pub fn process(ctx: Context<SomeInstruction>) -> Result<()> {
        for account in ctx.remaining_accounts.iter() {
            require!(
                account.owner == EXPECTED_OWNER_PUBKEY,
                ErrorCode::InvalidAccountOwner
            );
            require!(
                account.is_signer == false,
                ErrorCode::UnexpectedSigner
            );
        }
        Ok(())
    }
    ```

14. **CPI Callback Protection:** Prevent reentrancy in CPI calls.
    ```rust
    // Example: CPI callback protection
    #[account]
    pub struct State {
        pub is_processing: bool,
    }

    pub fn process(ctx: Context<Process>) -> Result<()> {
        require!(!ctx.accounts.state.is_processing, ErrorCode::ReentrancyDetected);
        ctx.accounts.state.is_processing = true;
        
        // Perform CPI call
        // ...
        
        ctx.accounts.state.is_processing = false;
        Ok(())
    }
    ```

15. **Account Ownership Verification:** Verify account ownership.
    ```rust
    // Example: Account ownership verification
    pub fn verify_ownership(account: &AccountInfo, expected_owner: &Pubkey) -> Result<()> {
        require!(
            account.owner == expected_owner,
            ErrorCode::IncorrectOwner
        );
        Ok(())
    }
    ```

16. **Duplicate Mutable Accounts Check:** Prevent duplicate mutable accounts.
    ```rust
    // Example: Duplicate mutable accounts check
    pub fn check_duplicate_mutable_accounts(accounts: &[AccountInfo]) -> Result<()> {
        let mut seen = std::collections::HashSet::new();
        for account in accounts {
            if account.is_writable {
                if !seen.insert(account.key) {
                    return err!(ErrorCode::DuplicateMutableAccount);
                }
            }
        }
        Ok(())
    }
    ```

17. **CPI Order Verification:** Ensure correct CPI call order.
    ```rust
    // Example: CPI order verification
    pub fn process(ctx: Context<Process>) -> Result<()> {
        // First CPI call
        let cpi_accounts = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            // ... other accounts
        );
        token::transfer(cpi_accounts, amount)?;

        // Second CPI call
        let cpi_accounts = CpiContext::new(
            ctx.accounts.token_program.to_account_info(),
            // ... other accounts
        );
        token::burn(cpi_accounts, amount)?;

        Ok(())
    }
    ```

18. **Bump Seed Verification:** Include bump seed in PDA derivation.
    ```rust
    // Example: Bump seed verification
    let (pda, bump) = Pubkey::find_program_address(
        &[b"seed", user.key().as_ref()],
        program_id
    );
    require!(
        bump == ctx.accounts.pda.bump,
        ErrorCode::InvalidBump
    );
    ```

19. **Safe Account Reallocation:** Handle account reallocation safely.
    ```rust
    // Example: Safe account reallocation
    pub fn reallocate(ctx: Context<Reallocate>, new_size: usize) -> Result<()> {
        let account = &ctx.accounts.account;
        let current_size = account.data_len();
        
        if new_size > current_size {
            account.realloc(new_size, false)?;
        }
        Ok(())
    }
    ```

20. **PDA Sharing Prevention:** Prevent PDA sharing between different functionalities.
    ```rust
    // Example: Unique PDA seeds for different functionalities
    #[derive(Accounts)]
    pub struct StakeTokens<'info> {
        #[account(
            mut,
            seeds = [b"staking_pool", &staking_pool.key().as_ref()],
            bump
        )]
        pub staking_pool: AccountInfo<'info>,
    }

    #[derive(Accounts)]
    pub struct WithdrawRewards<'info> {
        #[account(
            mut,
            seeds = [b"rewards_pool", &rewards_pool.key().as_ref()],
            bump
        )]
        pub rewards_pool: AccountInfo<'info>,
    }
    ```

21. Account Closure Safety  Ensure proper account closure. , use the close constraint 
22. lamports transfer out of pda using the pda signer seeds use the try_borrow_lamports method instead
23. wrong seeds used 
24. Arbitary cpi 
25. incorrect validations around the token accounts 
26. Usinng lamports check only before creating a account is vulnerbale to donation attacks
27. unvalidated system accounts
28. Token account not reloaded after a transfer 
29. missing close authority check 
30. Missing freeze authority check
31. Wrong event emission 
32. hardcoded gas values
33. Precision loss 
34. Seed collison 
35. Emit_cpi is vulnerable to truncation use the emit only thing 
36. Mintcloseauthority being closed and created with new token decimals value can create issues 
37. Mint account derived using the original token 2022 program derived using the token program or its vice-versa
38. Init_if_needed is not available before 0.30.0 anchor version on token 2022 mint accounts 
39. anchor version related issue
40. Solana related issues
41. Incorrect size calculation
42. Using non cannical bump or usage of create_program_address instead of find_program_address
43. Varibale size issue, is the size of that variable correct to ensure it can hold that data. 

44. While using an oracle always ensure you follow all the best security practises 
in solana pyth is mostly used
- people forget to valdiate the confidence level to validate the staleness correclty
https://docs.pyth.network/price-feeds/best-practices

45. Not handling decimals properly across transfers
46. always before withdrawing valdiate the amount after withdrawm is greater then the rent exempt amount for the pda 

47. When counting the lamports inside a account don't count the rent exmpt lamports as the account balance 

48. Use invoke if the there is system owned account like wallet signing the tx and use invoke_signed only when there is a pda signing that tx. 
49. make sure when using the init_if_needed there is no reinitialzation vulnerability 
50. Use of transfer funtion on a token 2022 program mint's token accunt 
51. While using wsol account there are actually two mint address now one for teh legacy spl token program and one for the new token program 