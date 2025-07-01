# Restaking Protocol Security Guidelines

## 1. Rebase Token Risks in Restaking Protocols

### What are Rebase Tokens?
Rebase tokens are cryptocurrencies with elastic supply mechanisms that automatically adjust the total supply of tokens in circulation. Unlike traditional tokens where your balance remains constant, rebase tokens can increase or decrease your wallet balance based on predetermined algorithms.

**Examples of Rebase Tokens:**
- AMPL (Ampleforth)
- YAM (Yam Finance)
- RMPL (RMPL Token)
- DIGG (Badger DAO)

### Why Rebase Tokens Should NOT Be Used as Collateral

#### 1. **Supply Volatility Risk**
- Rebase tokens adjust supply based on price targets
- Positive rebase: Token supply increases, diluting value
- Negative rebase: Token supply decreases, concentrating value
- This creates unpredictable collateral value fluctuations

#### 2. **Smart Contract Integration Issues**
- Most DeFi protocols assume static token balances
- Rebase mechanisms can break accounting systems
- Balance changes occur outside of normal transfer events
- Can lead to incorrect collateralization ratios

#### 3. **Liquidation Complications**
- Rapid supply changes can trigger unexpected liquidations
- Liquidation bots may not account for rebase adjustments
- Risk of cascading liquidations during negative rebases

#### 4. **Oracle Price Feed Problems**
- Price oracles may not properly track rebased supply
- Stale price data during rebase events
- Difficulty in determining true market value

### Technical Implementation Risks

```solidity
// DANGEROUS: Direct balance checks with rebase tokens
function checkCollateral(address token, address user) public view {
    uint256 balance = IERC20(token).balanceOf(user);
    // Balance can change between transactions due to rebase!
}
```

#### Safe Alternatives:
- Use wrapped versions of rebase tokens
- Implement snapshot-based accounting
- Use non-rebasing stablecoins or established tokens

## 2. Additional Restaking Protocol Security Considerations

### Liquid Staking Token (LST) Risks

#### **Slashing Risk Propagation**
- Validators can be slashed for malicious behavior
- LST holders inherit slashing risks
- Restaking amplifies potential losses across multiple protocols

#### **Validator Centralization**
- Large validator sets may create centralization risks
- Single points of failure in validator infrastructure
- Governance capture risks

### Smart Contract Risks

#### **Upgrade Risks**
- Proxy contracts can be upgraded maliciously
- Timelock mechanisms may be insufficient
- Admin key management vulnerabilities

#### **Integration Complexity**
- Multiple protocol interactions increase attack surface
- Composability risks with other DeFi protocols
- Flash loan attack vectors

### Economic Attack Vectors

#### **MEV (Maximal Extractable Value) Risks**
- Restaking rewards can be extracted by MEV searchers
- Sandwich attacks on large restaking transactions
- Front-running of withdrawal requests

#### **Liquidity Risks**
- Exit liquidity may be insufficient during market stress
- Withdrawal delays in underlying staking protocols
- Secondary market price depegging

## 3. Best Practices for Restaking Protocols

### Collateral Asset Selection
✅ **Recommended:**
- ETH and major LSTs (stETH, rETH, cbETH)
- Blue-chip tokens with proven track records
- Tokens with robust oracle infrastructure

❌ **Avoid:**
- Rebase tokens (AMPL, YAM, etc.)
- Experimental or new tokens
- Tokens with known oracle issues
- Governance tokens with high volatility

### Risk Management
- Implement conservative collateralization ratios (>150%)
- Use multiple price oracle sources
- Implement circuit breakers for extreme market conditions
- Regular security audits and bug bounty programs

### Monitoring and Alerts
- Real-time monitoring of validator performance
- Automated alerts for slashing events
- Track restaking reward distribution
- Monitor for unusual contract interactions

## 4. Resources and References

### Documentation
- [Rebase Tokens Explained](https://www.coindesk.com/learn/what-are-rebase-tokens/)
- [Ethereum DeFi Guide](https://ethereum.org/en/defi/)
- [Aave Risk Assessment](https://docs.aave.com/risk/asset-risk/methodology)
- [Compound Protocol Documentation](https://compound.finance/docs)

### Security Resources
- [Smart Contract Security Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [DeFi Pulse - Industry Analytics](https://defipulse.com/)
- [OpenZeppelin Security Guidelines](https://docs.openzeppelin.com/contracts/4.x/security)

### Audit Reports
- Review audit reports from reputable firms (OpenZeppelin, ConsenSys Diligence, Trail of Bits)
- Check for specific rebase token handling in audit scope
- Verify oracle security assessments

---

**Last Updated:** June 2025  
**Status:** Active monitoring required for all rebase token proposals
