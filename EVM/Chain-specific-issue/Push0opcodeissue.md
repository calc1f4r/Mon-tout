# PUSH0 Opcode Issue on Arbitrum Chain with Solidity 0.8.23

## Problem Description

The PUSH0 opcode does not work on Solidity version 0.8.23 when deploying to the Arbitrum chain. This can cause deployment failures or unexpected behavior in contracts compiled with this Solidity version.

## Background on PUSH0

The PUSH0 opcode (0x5F) was introduced in the Shanghai upgrade (EIP-3855) for Ethereum. It pushes the constant value 0 onto the stack. This opcode was added to improve gas efficiency, as it's cheaper than the alternative of using PUSH1 0x00.

- PUSH0: 2 gas
- PUSH1 0x00: 3 gas

## Why It Doesn't Work on Arbitrum

Arbitrum is an L2 (Layer 2) scaling solution that uses optimistic rollups. While Arbitrum aims to be EVM-compatible, it doesn't always immediately support new EVM features:

1. Arbitrum may not have implemented support for the PUSH0 opcode in its current version
2. The Arbitrum Nitro execution environment has its own versioning for EVM compatibility
3. Unlike the main Ethereum network, which implemented PUSH0 with the Shanghai upgrade, Arbitrum's upgrade path is independent

## Impact on Developers


When deploying contracts compiled with Solidity 0.8.23 (which uses PUSH0 by default) to Arbitrum:
- Contract deployments may fail with errors related to invalid opcodes
- Transactions interacting with these contracts might revert unexpectedly
- Gas estimates could be incorrect

## Solutions and Workarounds

There are several ways to address this issue:

1. **Use an earlier Solidity version**: Compile your contracts with Solidity 0.8.22 or earlier which doesn't use the PUSH0 opcode.
   ```solidity
   pragma solidity 0.8.22; // Instead of 0.8.23
   ```

2. **Disable the PUSH0 opcode**: When using Solidity 0.8.23+, you can disable PUSH0 in your compiler settings:
   ```json
   {
     "compilerOptions": {
       "evmVersion": "paris" // Use Paris instead of Shanghai
     }
   }
   ```

3. **If using Hardhat**, modify your configuration:
   ```javascript
   module.exports = {
     solidity: {
       version: "0.8.23",
       settings: {
         evmVersion: "paris"
       }
     }
   };
   ```

4. **If using Foundry**, update your `foundry.toml`:
   ```toml
   [profile.default]
   evm_version = "paris"
   ```

## Update Status

As of this writing, Arbitrum has not yet implemented support for the PUSH0 opcode. Check the official Arbitrum documentation or announcements for updates on when this feature will be supported.

## References

- [EIP-3855: PUSH0 Instruction](https://eips.ethereum.org/EIPS/eip-3855)
- [Arbitrum Documentation](https://docs.arbitrum.io/)
- [Solidity 0.8.23 Release Notes](https://blog.soliditylang.org/2023/08/30/solidity-0.8.23-release-announcement/)


[Remediation]
Use solididy less than 0.8.20