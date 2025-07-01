1. When unstaking, user should receive the same amount of tokens they staked, minus any fees or penalties and all the claim if you delete its user data.
2. There should be a minimum limit 
3. No dust amount being stuck in the contract.
4. If there is some pausing mechanism, it should not affect the withdrawal of staked tokens.
5. Ensure that the contract does not allow reentrancy attacks during the unstaking process.
6. Implement a cooldown period for unstaking to prevent immediate withdrawals after staking.
7. Ensure that the contract correctly handles edge cases, such as when a user tries to unstake more tokens than they have staked.
[LS-03] - Can rewards be delayed in payout or claimed too early?

