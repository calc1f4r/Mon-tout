# Solana Token Mint Security Checklist

## 1. [MintCloseAuthority Extension Check](#1-mintcloseauthority-extension-check)
## 2. [No freeze authority check for Mint](#)

### MintCloseAuthority issue
- A malicious actor with MintCloseAuthority can close and reinitialize the mint with different decimals
- Impact: Protocol's value calculations can be manipulated if they depend on token decimals
- Attack Vector: Token mint can be closed and reinitialized with different decimal places

### Attack Scenarios
1. Decimal Manipulation Attack:
   - Attacker closes mint with 6 decimals
   - Reinitializes with 9 decimals
   - Results in 1000x value inflation
   
2. Flash Loan Attack Vector:
   - Combine decimal manipulation with flash loans
   - Exploit price calculations during the attack window
   - Drain protocol funds through price discrepancies

### Impact
- Complete disruption of protocol economics
- Potential price manipulation
- Incorrect value calculations leading to financial losses
- Possible permanent loss of user funds
- Protocol reputation damage
- Market manipulation opportunities

### Mitigation
1. Primary Defense: Reject mints with MintCloseAuthority extension:

```rust
use spl_token_2022::extension::ExtensionType;
use spl_token_2022::state::{Mint, StateWithExtensions};

pub fn is_supported_mint(mint_account: &InterfaceAccount<Mint>) -> bool {
    let mint_info = mint_account.to_account_info();
    let mint_data = mint_info.data.borrow();
    let mint = StateWithExtensions::<spl_token_2022::state::Mint>::unpack(&mint_data).unwrap();
    
    // Additional safety: Check if mint data is valid
    if mint_data.len() == 0 {
        return false;
    }
    
    match mint.get_extension_types() {
        Ok(extensions) => {
            for e in extensions {
                if e == ExtensionType::MintCloseAuthority {
                    return false;
                }
            }
            true
        },
        Err(_) => false  // Fail closed on error
    }
}
```



### Additional Security Measures
1. On-chain Verification:
   ```rust
   // Add to your validation logic
   require!(is_supported_mint(&token_mint), ErrorCode::UnsupportedMint);
   ```


### References
- [Arjuna Security Alert](https://x.com/arjuna_sec/status/1900606397232148683)
- [SPL Token 2022 Documentation](https://spl.solana.com/token-2022)
- [Solana Security Best Practices](https://docs.solana.com/security)



### No freeze authority check for Mint 

[account(
 mint::freeze_authority = COption::None, // Ensure no freeze
 authority exists
 mint::token_program = token_program,
 )]
 input_token_mint: Box<InterfaceAccount<'info, Mint>>,


 ### POC 
 ```rust
  #[cfg(test)]
 mod tests {
 use solana_program::pubkey::Pubkey;
 use solana_program_test::*;
 use solana_sdk::{
 signature::{Keypair, Signer},
 transaction::Transaction,
 system_instruction,
 };
 use spl_token_2022::{
 instruction::{initialize_mint2, close_account, set_authority,
 initialize_mint_close_authority},
 extension::ExtensionType,
 state::Mint,
 };
 use solana_program::program_pack::Pack; // Import the Pack trait for
 Mint::LEN
 async fn create_mint(
 banks_client: &mut BanksClient,
 payer: &Keypair,
 mint_keypair: &Keypair,
 mint_authority: &Keypair,
 freeze_authority: Option<&Pubkey>,
 decimals: u8,
 )-> Result<(), Box<dyn std::error::Error>> {
 // Calculate the space required using the ExtensionType
 let space = ExtensionType::try_calculate_account_len::<Mint>(&[
 ExtensionType::MintCloseAuthority]).unwrap();
 // Use Mint::LEN from the Pack trait
 let mint_account_rent = banks_client
 .get_rent()
 .await?
 .minimum_balance(space);
 let recent_blockhash = banks_client.get_latest_blockhash().await
 ?;
 // Step 1: Create the account for the mint with the required size
 and rent-exempt balance
 let create_account_tx = Transaction::new_signed_with_payer(
 &[system_instruction::create_account(
 &payer.pubkey(),
 &mint_keypair.pubkey(),
 mint_account_rent,
 space as u64,
 &spl_token_2022::id(),
 )],
 Some(&payer.pubkey()),
 &[payer, mint_keypair],
 recent_blockhash,
 );
 banks_client.process_transaction(create_account_tx).await?;
 // Step 2: Initialize the mint with initialize_mint2
 let recent_blockhash = banks_client.get_latest_blockhash().await
 ?;
 let initialize_mint_tx = Transaction::new_signed_with_payer(
 &[
 initialize_mint_close_authority(
 &spl_token_2022::id(),
 &mint_keypair.pubkey(),
 Some(&mint_authority.pubkey()),
 )?,
 initialize_mint2(
 &spl_token_2022::id(),
 &mint_keypair.pubkey(),
 &mint_authority.pubkey(),
 freeze_authority,
 decimals,
 )?
 ],
 Some(&payer.pubkey()),
 &[payer],
 recent_blockhash,
 );
 banks_client.process_transaction(initialize_mint_tx).await?;
 Ok(())
 }
 async fn close_mint_account(
 banks_client: &mut BanksClient,
 payer: &Keypair,
 mint_keypair: &Keypair,
 receiver: &Pubkey,
 mint_authority: &Keypair,
 )-> Result<(), Box<dyn std::error::Error>> {
 let recent_blockhash = banks_client.get_latest_blockhash().await
 ?;
 let tx = Transaction::new_signed_with_payer(
 &[close_account(
 &spl_token_2022::id(),
 &mint_keypair.pubkey(),
 receiver,
 &mint_authority.pubkey(),
 &[&mint_authority.pubkey()],
 )?],
 Some(&payer.pubkey()),
 &[payer, mint_authority],
 recent_blockhash,
 );
 banks_client.process_transaction(tx).await?;
 Ok(())
 }
 #[tokio::test]
 async fn test_initialize_mint_and_close() {
 // Register the spl_token_2022 program processor
 let program_test = ProgramTest::new(
 "spl_token_2022",
 spl_token_2022::id(),
 processor!(spl_token_2022::processor::Processor::process)
 );
 // Start the test environment
 let (mut banks_client, payer, _recent_blockhash) = program_test.
 start().await;
 // Create keypairs for the mint and the mint authority
 let mint_keypair = Keypair::new();
 let mint_authority = Keypair::new();
 let receiver_account = Keypair::new(); // Account that will
 receive the remaining rent
 // Step 1: Initialize the mint using spl_token_2022
 create_mint(
 &mut banks_client,
 &payer,
 &mint_keypair,
 &mint_authority, // Correctly use the public key of
 mint_authority
 Some(&mint_authority.pubkey()), // Freeze authority
 0, // Token decimals
 )
 .await
 .unwrap();
 // // Fetch and print the current decimals value
 // let mint_data = get_mint_data(&mut banks_client, &mint_keypair
 .pubkey()).await.unwrap();
 // println!("Old Mint Decimals: {}", mint_data.decimals);
 // Step 2: Close the mint account
 close_mint_account(
 &mut banks_client,
 &payer,
 &mint_keypair,
 &receiver_account.pubkey(), // Receiver of the rent remains
 &mint_authority, // Correct mint authority keypair is used
 here
 )
 .await
 .unwrap();
 // Step 3: re-initialize the mint account with different decimal
 create_mint(
 &mut banks_client,
 &payer,
 &mint_keypair,
 &mint_authority, // Correctly use the public key of
 mint_authority
 Some(&mint_authority.pubkey()), // Freeze authority
 6, // Token decimals
 )
 .await
 .unwrap();
 }
 }
 ```