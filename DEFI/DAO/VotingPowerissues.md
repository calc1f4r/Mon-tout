# Voting Power Configuration Issues

## Incorrect Quorum Percentage Configuration
Read more at : https://code4rena.com/audits/2025-01-iq-ai/submissions/F-3
- [x] **Issue Identified**: The `GovernorVotesQuorumFraction` parameter in the constructor was set to 4, which means 4% of the total supply (4/100)
- [x] **Expected Behavior**: According to the comment, the quorum should be 25% (1/4th) of the total supply, requiring a parameter value of 25

The default quorum denominator is 100, so 4/100
```solidity
    function quorumDenominator() public view virtual returns (uint256) {
        return 100;
    }

    /**
     * @dev Returns the quorum for a timepoint, in terms of number of votes: `supply * numerator / denominator`.
     */
    function quorum(uint256 timepoint) public view virtual override returns (uint256) {
        return (token().getPastTotalSupply(timepoint) * quorumNumerator(timepoint)) / quorumDenominator();
    }

```
- [x] **Root Cause**: Parameter value mismatch with intended percentage (4% instead of 25%)
- [ ] **Fix Implementation**: Change parameter from 4 to 25 in the Governor constructor to properly represent 25% quorum

### Code Change
```solidity
constructor(
    string memory _name,
    IVotes _token,
    Agent _agent
)
    Governor(_name)
    GovernorVotes(_token)
    GovernorVotesQuorumFraction(25) // quorum is 25% (1/4th) of supply
{
    agent = _agent;
}
```

## Security Researcher Checklist: How to Identify This Issue

### Pre-requisite Knowledge
- [ ] Understand OpenZeppelin's Governor contracts implementation
- [ ] Know how the quorum mechanism works in DAO governance systems
- [ ] Understand the relationship between parameters and their effects on governance

### Investigation Steps
1. [ ] **Review Contract Initialization**
   - [ ] Examine constructor parameters and their documentation
   - [ ] Compare parameter values with comments to identify mismatches
   - [ ] Check imported libraries and their expected parameter formats

2. [ ] **Trace Parameter Usage**
   - [ ] Identify how the `GovernorVotesQuorumFraction` parameter is used
   - [ ] Review the quorum calculation function
   - [ ] Determine the denominator used (typically 100 in OpenZeppelin implementation)
   - [ ] Calculate the actual percentage represented by the parameter

3. [ ] **Verify Business Requirements**
   - [ ] Confirm intended quorum threshold from documentation/comments
   - [ ] Calculate what parameter value would correctly represent this threshold
   - [ ] Identify the discrepancy between intended and actual values

4. [ ] **Impact Assessment**
   - [ ] Determine how this affects the governance process
   - [ ] Calculate the difference in voting power required (4% vs 25%)
   - [ ] Assess if this creates potential centralization or security risks

5. [ ] **Documentation Review**
   - [ ] Check if the issue exists in documentation as well
   - [ ] Verify if tests incorrectly assume the quorum percentage

### Common Detection Methods
- Code vs. comment inconsistency analysis
- Parameter value validation against intended behavior
- Cross-referencing imported library documentation with usage
- Manual calculation of governance thresholds based on parameters