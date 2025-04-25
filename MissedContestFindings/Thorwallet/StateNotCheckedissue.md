
### My summary of The issue 
There was a threshold of what numbers of tokens should have been deposited and what number of tokens should have been withdrawn, but the protocol was not keeping track of that.


### Questions to be asked ?

- Why I missed it ?
I didn't even took a look at the codebase. MY issue. 


The MergeTgt contract has a critical vulnerability that could lead to loss of user funds due to improper tracking of token deposits. The contract allows users to deposit more tokens than it was designed to handle, which can result in some users being unable to claim their tokens.

## What is MergeTgt?
MergeTgt is a smart contract that functions like a token exchange machine:
- Users deposit TGT tokens
- In return, they receive TITN tokens
- The exchange has specific limits on how many tokens it can handle

## The Problem Explained

### 1. The Contract's Design Limits
The contract has two important fixed numbers:
- Maximum TGT tokens it should accept: 579,000,000
- Total TITN tokens available for exchange: 173,700,000

### 2. The Missing Safety Check
The contract has a critical flaw:
- It doesn't keep track of how many TGT tokens have been deposited in total
- It's like a vending machine that doesn't know how many coins have been put in

### 3. What Can Go Wrong
Let's look at a real-world example:

**Scenario:**
1. User A deposits 578,999,999 TGT tokens (almost all the limit)
2. User B deposits 100 TGT tokens
3. The contract accepts both deposits because it doesn't track the total
4. Now there are more TGT tokens deposited than the contract was designed to handle

**Result:**
- User B can successfully claim their TITN tokens
- When User A tries to claim their TITN tokens, the contract doesn't have enough TITN left
- User A loses their TGT tokens with no way to get them back

### 4. The Technical Details
The contract has several tracking variables:
```solidity
uint256 public totalTitnClaimed;      // How many TITN tokens have been claimed
uint256 public totalTitnClaimable;    // How many TITN tokens can be claimed
uint256 public remainingTitnAfter1Year; // TITN tokens left after one year
uint256 public initialTotalClaimable;  // Initial amount of claimable TITN
```

But it's missing the crucial variable:
```solidity
uint256 public totalTgtDeposited;     // This variable doesn't exist but should
```

### 5. The Impact
- **Financial Loss**: Users who deposit tokens after the limit is exceeded may lose their tokens
- **Contract Failure**: The contract may fail to process legitimate claims
- **Trust Issues**: Users may lose trust in the contract and the project

### 6. Real-World Comparison
Think of it like a concert ticket system:
- The venue has 1000 seats (TITN tokens)
- The system should stop selling tickets after 1000 (TGT tokens)
- But if the system doesn't track total tickets sold, it might sell 1200 tickets
- The last 200 people won't get seats, but they've already paid

## The Solution

### 1. Add Tracking
Add a new variable to track total TGT deposits:
```solidity
uint256 public totalTgtDeposited;
```

### 2. Add Safety Checks
Before accepting new deposits, check if it would exceed the limit:
```solidity
if (totalTgtDeposited + newDeposit > TGT_TO_EXCHANGE) {
    revert("Cannot accept more deposits - limit reached");
}
```

### 3. Update the Total
After accepting a deposit, update the total:
```solidity
totalTgtDeposited += newDeposit;
```

## Recommendations
1. Implement the tracking system for total TGT deposits
2. Add clear error messages when the limit is reached
3. Consider adding a function to return remaining capacity
4. Add events to log when the limit is reached
5. Consider implementing a refund mechanism for rejected deposits

## Conclusion
This vulnerability is serious because it can lead to direct financial loss for users. The fix is relatively simple but crucial for the contract's proper functioning. Without this fix, the contract cannot guarantee that all users will be able to claim their tokens, which undermines the entire purpose of the exchange mechanism.
