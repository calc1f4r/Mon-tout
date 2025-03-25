# Metaplex Security Checklist

## URI Validation Issues
- [ ] No URI validation for metaplex metadata - can lead to malformed token information
  
  This could lead to:
  - Malformed metadata that breaks token explorers
  - URIs that are too long and waste on-chain storage
  - URIs pointing to invalid or malicious resources
  - Encoding issues causing display problems

  Reference: [Code4rena report](https://code4rena.com/reports/2025-01-pump-science#04-bonding-curve-creation-lacks-uri-validation-in-metadata-leading-to-potential-malformed-token-information)

### No validation for metadata length
The issue is that these metadata fields (name, symbol, uri) lack length restrictions. This presents several problems:

- [ ] Token names and symbols could be unreasonably long, making them impractical for display
- [ ] Long URIs could waste on-chain storage
- [ ] Malicious creators could create tokens with extremely long metadata to increase storage costs
- [ ] No validation for minimum lengths, allowing empty strings

This could lead to:

- Excessive storage costs for the protocol
- Poor UX in wallets and explorers
- Potential for spam tokens with unnecessarily large metadata

### Impact
- [ ] Excessive storage costs and poor UX due to unbounded metadata string lengths


## When creating a bonding curve give a name to the creator as well 
```rust
  let data = DataV2 {
            name,
            symbol,
            uri,
            seller_fee_basis_points: 0,
            creators: Some(vec![Creator {
                address: creator,
                verified: false,
                share: 100,
            }]),
            collection: None,
            uses: None,
        };
```