1. **Reentrancy Protection**:
   - Implement reentrancy guards on functions like `safeMint`, `safeTransferFrom`, and `safeTransfer`.
   - Use OpenZeppelin's `ReentrancyGuard` to prevent reentrancy attacks.

2. **Function Implementation**:
   - Ensure recipient contracts implement the `onERC721Received` function to accept NFTs.
   - Use `transferFrom` instead of `safeTransferFrom` when dealing with contracts that might not handle `onERC721Received`.

3. **Function Signatures**:
   - Verify that all function signatures are correct, especially for metadata functions like `baseURI` and `tokenURI`.
   - Double-check function calls to ensure they match the ERC721 standard.

4. **Royalty Compliance**:
   - Implement EIP-2981 to ensure proper royalty distribution.
   - Set royalties correctly for each token ID and ensure the correct recipient is designated.

5. **Limit Enforcement**:
   - Strictly enforce limits on token holdings and transfers to prevent off-by-one errors.
   - Regularly audit limit checks to ensure they are correctly implemented.

6. **Pausing Features**:
   - Evaluate the necessity of pausing features in your contract.
   - Ensure pausing does not interfere with critical operations like withdrawals.

7. **Whitelisting**:
   - Implement whitelisting checks for cross-chain transfers on both L1 and L2.
   - Ensure whitelisting is verified during both deposit and withdrawal operations.

8. **Cross-Chain Transfers**:
   - Verify that all necessary checks are in place for bridging NFTs between chains.
   - Ensure that NFTs can be transferred back and forth without getting stuck.


References : https://hashnode.com/draft/6595bf9064f9520e7dcc7b99