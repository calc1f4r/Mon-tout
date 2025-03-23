# General Smart Contract Security Checklist

## Input Validation
- [ ] **Parameter mismatch** - Function parameters don't match expected values or types
- [ ] **Missing input validation** - Function inputs are not properly validated
- [ ] **Integer overflow/underflow** - Operations that could cause numeric overflow/underflow
- [ ] **Rounding issues** - 
## Event & State Management
- [ ] **Wrong event emission** - Events emitted with incorrect parameters or missing entirely ([example](https://code4rena.com/reports/2025-01-pump-science#09-bonding-curve-token-account-lockunlock-operations-lack-event-emission-for-critical-state-changes))
- [ ] **Missing or incorrect state updates** - State variables not properly updated after operations

## Gas & Network Concerns
- [ ] **Hardcoded gas fees** - Can lead to failed transactions during network congestion ([example](https://code4rena.com/reports/2025-01-pump-science#05-hardcoded-gas-fee-in-pool-migration-could-lead-to-failed-transactions-in-network-congestion))
- [ ] **Gas optimization issues** - Inefficient code consuming excessive gas

## Access Control & Security
- [ ] **Missing access controls** - Functions accessible by unauthorized users
- [ ] **Centralization risks** - Critical functions controlled by a single address
- [ ] **Unprotected initializers** - Initialization functions without proper access control

## Logic & Business Rules
- [ ] **Logic errors** - Incorrect implementation of business rules ([example](https://code4rena.com/audits/2025-01-pump-science/submissions/F-583))
- [ ] **Oracle manipulation** - Price feeds or oracles that can be manipulated
- [ ] **Incorrect calculations** - Mathematical errors in formulas or algorithms
- [ ] **Redundant functions** - Empty or unnecessary functions creating misleading security expectations ([example](https://code4rena.com/reports/2025-01-pump-science#10-empty-remove_wl-function-implementation-creates-misleading-security-expectation))

## Other Vulnerabilities
- [ ] **Front-running opportunities** - Transactions vulnerable to front-running
- [ ] **Timestamp dependence** - Reliance on block.timestamp for critical operations
- [ ] **Signature replay** - Lack of nonce or other protection against signature replay