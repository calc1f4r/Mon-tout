### Best Practices 
- [ ] Use SafeERC20 from OpenZeppelin for all ERC20 interactions

- [ ] **Fee on Transfer Tokens**: If the protocol relies too heavily on the assertion that a specific amount of tokens must be transferred, fee-on-transfer tokens might break the invariant.

- [ ] **Insufficient ERC20 Balance**: The contract might not have sufficient ERC20 token balance to fulfill transfer operations. If the protocol does not want the transaction to revert, which is a protocol invariant, then the protocol should transfer as many tokens as it currently has. Read more [at](#erc20-balance-issue).

- [ ] **Protocol relying on the ERC20 `transfer` bool return value**: Some tokens don't properly implement the boolean return value. Use SafeERC20 wrapper instead of relying on the raw interfaces.
https://solodit.cyfrin.io/issues/m-01-improper-handling-of-erc20-transfer-return-value-pashov-audit-group-none-gacha_2025-01-27-markdown

- [ ] **Verify transfer vs transferFrom usage**: Make sure you check whether to use transfer or transferFrom based on token ownership context. When using transfer, the contract is the one making the call.

### Issues in detail 

#### [ERC20 Balance Issue]

Issue found at 1inch

On the option `fee on transfer` tokens, the protocol was sending a amount which the protocol might not even have. 

Remediation 
```diff
+ uint256 balance = IERC20(order.takerAsset.get()).balanceOf(address
+ (this));
+ if (balance < takingAmount) takingAmount = balance;
```


