# AMM Security Checklist

## Core Security Considerations

1. **Use DEX aggregators to ensure that you don't drain one LP pool.** Aggregators like 1inch solve these issues by routing through multiple pools.
   - [1inch Aggregation Protocol Documentation](https://docs.1inch.io/docs/aggregation-protocol/introduction)
   - [Uniswap V3 Concentrated Liquidity](https://docs.uniswap.org/concepts/protocol/concentrated-liquidity)

2. **Do not hardcode the swap paths** - use dynamic routing based on liquidity and price impact.
   - [OpenZeppelin Access Control Best Practices](https://docs.openzeppelin.com/contracts/4.x/access-control)
   - [Solidity Security Considerations](https://docs.soliditylang.org/en/latest/security-considerations.html)

3. **Maintain a constant `x * y = k` invariant** in your swap logic (where x and y are token reserves).
   - [Uniswap V2 Core Whitepaper](https://uniswap.org/whitepaper.pdf)
   - [Balancer Protocol Documentation](https://docs.balancer.fi/concepts/pools/weighted.html)

4. **Implement slippage checks** to prevent excessive price impact during swaps.
   - [MEV Protection Strategies](https://ethereum.org/en/developers/docs/mev/)
   - [Flashbots MEV Documentation](https://docs.flashbots.net/)

5. **Do not allow zero address as a recipient** in swap functions.
   - [ERC-20 Token Standard](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/)
   - [OpenZeppelin ERC20 Implementation](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol)

6. **Validate token addresses** and ensure they are not malicious or deprecated contracts.
   - [Token Security Best Practices](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/#known-issues)
   - [Smart Contract Security Verification](https://consensys.net/diligence/blog/)

7. **Fees-on-transfer tokens might break the code functionality** - account for actual received amounts.
   - [Consensys: Stop Using Solidity's transfer() Now](https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/)
   - [Not So Smart Contracts: Common Vulnerabilities](https://github.com/crytic/not-so-smart-contracts)

8. **Prevent price oracle manipulation** by using v2 TWAP and v3 TWAP, and do not read values from the reserves.
   - [Uniswap V3 Oracle Documentation](https://docs.uniswap.org/concepts/protocol/oracle)
   - [Chainlink Oracle Problem](https://chain.link/education-hub/oracle-problem)
   - [Flash Loan Attack Prevention](https://blog.openzeppelin.com/on-the-complexity-of-public-goods-funding/)

9. **Allow retrieval of admin fees** through proper access-controlled functions.
   - [OpenZeppelin AccessControl](https://docs.openzeppelin.com/contracts/4.x/api/access#AccessControl)
   - [Ethereum Access Control Patterns](https://ethereum.org/en/developers/docs/smart-contracts/security/)

10. **Avoid hardcoded on-chain slippage** - make it configurable or dynamic based on market conditions.
    - [DeFi Security Best Practices](https://ethereum.org/en/developers/docs/smart-contracts/security/)
    - [Automated Market Maker Security Considerations](https://ethereum.org/en/defi/)

11. **In multi-hop swaps, ensure that intermediary tokens are not subject to slippage or price manipulation attacks.**
    - [Cross-Chain Bridge Security](https://ethereum.org/en/developers/docs/bridges/)
    - [MEV Research and Protection](https://www.paradigm.xyz/2020/11/ethereum-reorgs-after-the-merge)

12. Use of deadline parameter in a wrong way.

## Additional Resources

### Security Auditing Tools
- [Trail of Bits Security Tools](https://github.com/crytic)
- [MythX Security Analysis](https://mythx.io/)
- [Slither Static Analyzer](https://github.com/crytic/slither)

### Known Attack Vectors
- [Rekt.news - DeFi Exploit Database](https://rekt.news/)
- [DeFiSafety Security Ratings](https://defisafety.com/)
- [Immunefi Bug Bounty Platform](https://immunefi.com/)

### Oracle Security
- [Chainlink Decentralized Oracle Networks](https://chain.link/education/blockchain-oracles)
- [Oracle Manipulation Attack Examples](https://chain.link/education-hub/market-manipulation-vs-oracle-exploits)
- [Time-Weighted Average Price (TWAP) Implementation](https://docs.uniswap.org/concepts/protocol/oracle)

### ERC-20 Token Considerations  
- [Weird ERC-20 Tokens Repository](https://github.com/d-xo/weird-erc20)
- [Token Integration Checklist](https://ethereum.org/en/developers/docs/standards/tokens/erc-20/#known-issues)
12. Implement proper access control for admin functions to prevent unauthorized access.
13. Consider decimal scaling precision .