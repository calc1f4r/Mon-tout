1. [Fee on Transfer Tokens] If the protocol relies too heavily on the assertion that a specific amount of tokens must be transferred, fee-on-transfer tokens might break the invariant.

2. [Insufficient ERC20 Balance] The contract might not have sufficient ERC20 token balance to fulfill transfer operations. If the protocol does not want the transaction to revert, which is a protocol invariant, then the protocol should transfer as many tokens as it currently has. Read more [at](#erc20-balance-issue).



### Issues in detail 

#### [ERC20 Balance Issue]

Issue found at 1inch

On the option `fee on transfer` tokens, the protocol was sending a amount which the portocol might not even have. 

Remediation 
```diff
+ uint256 balance = IERC20(order.takerAsset.get()).balanceOf(address
+ (this));
+ if (balance < takingAmount) takingAmount = balance;
```