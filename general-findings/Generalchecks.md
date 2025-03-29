# General Smart Contract Security Checklist

## Security Checklist

- [ ] [Parameter Mismatch](#parameter-mismatch) - Function parameters don't match expected values or types
- [ ] [Missing Input Validation](#missing-input-validation) - Function inputs are not properly validated
- [ ] [Integer Overflow/Underflow](#integer-overflowunderflow) - Operations that could cause numeric overflow/underflow
- [ ] [Rounding Issues](#rounding-issues) - Loss of precision leading to calculation errors
- [ ] [Event Emission Issues](#event-emission-issues) - Events emitted with incorrect parameters or missing entirely
- [ ] [State Update Failures](#state-update-failures) - State variables not properly updated after operations
- [ ] [Hardcoded Gas Parameters](#hardcoded-gas-parameters) - Static gas values causing failed transactions during network congestion
- [ ] [Gas Optimization Issues](#gas-optimization-issues) - Inefficient code consuming excessive gas
- [ ] [Missing Access Controls](#missing-access-controls) - Functions accessible by unauthorized users
- [ ] [Centralization Risks](#centralization-risks) - Critical functions controlled by a single address
- [ ] [Unprotected Initializers](#unprotected-initializers) - Initialization functions without proper access control
- [ ] [Authority Access Issues](#authority-access-issues) - Incorrect authority assignment or missing privileges
- [ ] [Logic Errors](#logic-errors) - Incorrect implementation of business rules
- [ ] [Oracle Manipulation](#oracle-manipulation) - Price feeds or oracles that can be manipulated
- [ ] [Calculation Errors](#calculation-errors) - Mathematical errors in formulas or algorithms
- [ ] [Redundant Functions](#redundant-functions) - Empty or unnecessary functions creating misleading security expectations
- [ ] [Front-running Vulnerabilities](#front-running-vulnerabilities) - Transactions vulnerable to front-running
- [ ] [Timestamp Dependence](#timestamp-dependence) - Reliance on block.timestamp for critical operations
- [ ] [Signature Replay](#signature-replay) - Lack of nonce or other protection against signature replay
- [ ] [Off by one issue](#off-by-one-issue) - Loop iteration or array index errors that miss or process an extra element
- [ ] [Incomplete State Updates](#incomplete-state-updates) - Missing or incorrect state variable updates causing inconsistencies
- [ ] [Improper Pause Mechanisms](#improper-pause-mechanisms) - Pause functionality that blocks critical operations or leads to locked funds
- [ ] [Make sure all the important states are intialized in the delpoyment itself] -> This does not leave space for contract to be default state for that state 
## Detailed Security Measures

### Parameter Mismatch

**Impact**: High  
**Likelihood**: Medium  
**Description**: Mismatched parameters between function calls and expectations can lead to incorrect behavior or vulnerabilities.

**Vulnerable Code**:
```solidity
// ❌ Bad: Parameter order mismatch
function swap(address tokenIn, address tokenOut, uint256 amountIn) external {
    // Internal call with reversed parameters
    _executeSwap(tokenOut, tokenIn, amountIn);
}
```

**Secure Code**:
```solidity
// ✅ Good: Correct parameter ordering
function swap(address tokenIn, address tokenOut, uint256 amountIn) external {
    _executeSwap(tokenIn, tokenOut, amountIn);
}
```

**Prevention**:
- Use descriptive parameter names
- Add parameter validation checks
- Create helper functions for complex parameter handling
- Add thorough tests to verify parameter handling

### Missing Input Validation

**Impact**: High  
**Likelihood**: High  
**Description**: Lack of input validation can lead to unexpected behaviors, security vulnerabilities, and economic exploits.

**Vulnerable Code**:
```solidity
// ❌ Bad: No input validation
function deposit(uint256 amount, address token) external {
    transferFrom(msg.sender, address(this), amount);
}
```

**Secure Code**:
```solidity
// ✅ Good: With input validation
function deposit(uint256 amount, address token) external {
    require(amount > 0, "Amount must be positive");
    require(token != address(0), "Invalid token address");
    require(supportedTokens[token], "Unsupported token");
    transferFrom(msg.sender, address(this), amount);
}
```

**Prevention**:
- Validate all function inputs
- Check for zero values and zero addresses
- Verify bounds and ranges
- Confirm permissions and access control

### Integer Overflow/Underflow

**Impact**: Critical  
**Likelihood**: High  
**Description**: Unchecked arithmetic operations can lead to integer overflow or underflow, resulting in unexpected behaviors and economic exploits.

**Vulnerable Code**:
```solidity
// ❌ Bad: Unchecked arithmetic
function transfer(uint256 amount) external {
    balances[msg.sender] -= amount;
    balances[recipient] += amount;
}
```

**Secure Code**:
```solidity
// ✅ Good: Using SafeMath or unchecked (Solidity 0.8+)
function transfer(uint256 amount) external {
    require(balances[msg.sender] >= amount, "Insufficient balance");
    balances[msg.sender] -= amount;
    balances[recipient] += amount;
}
```

**Prevention**:
- Use SafeMath library for Solidity < 0.8.0
- Use Solidity 0.8.0+ for built-in overflow checking
- Add explicit checks for potential overflow/underflow cases
- Consider using uint256 for large values

### Rounding Issues

**Impact**: Medium  
**Likelihood**: High  
**Description**: Improper handling of decimal calculations can lead to precision loss, rounding errors, and economic exploits.

**Vulnerable Code**:
```solidity
// ❌ Bad: Rounding errors
function calculateFee(uint256 amount) internal returns (uint256) {
    // 0.5% fee but might round down to 0 for small amounts
    return amount * 5 / 1000;
}
```

**Secure Code**:
```solidity
// ✅ Good: Higher precision to avoid rounding issues
function calculateFee(uint256 amount) internal returns (uint256) {
    // Calculate with higher precision first
    return amount * 5 / 1000;
}

// ✅ Alternative: Fixed-point library usage
using FixedPoint for uint256;
function calculateFee(uint256 amount) internal returns (uint256) {
    return amount.mulDiv(feeRate, FEE_DENOMINATOR);
}
```

**Prevention**:
- Use fixed-point arithmetic libraries
- Perform multiplication before division
- Consider order of operations to minimize precision loss
- Add safety margins for economic calculations

### Event Emission Issues

**Impact**: Medium  
**Likelihood**: High  
**Description**: Missing or incorrect event emissions make off-chain tracking difficult and can hide critical state changes.

**Vulnerable Code**:
```solidity
// ❌ Bad: Missing event emission for critical operation
function lock(uint256 tokenId) external {
    require(ownerOf(tokenId) == msg.sender, "Not owner");
    lockStatus[tokenId] = true;
    // No event emitted
}
```

**Secure Code**:
```solidity
// ✅ Good: Proper event emission
event TokenLocked(uint256 indexed tokenId, address indexed locker);

function lock(uint256 tokenId) external {
    require(ownerOf(tokenId) == msg.sender, "Not owner");
    lockStatus[tokenId] = true;
    emit TokenLocked(tokenId, msg.sender);
}
```

**Prevention**:
- Emit events for all state-changing operations
- Include appropriate indexed parameters
- Document event structures
- Test event emissions in test suites

### State Update Failures

**Impact**: Critical  
**Likelihood**: Medium  
**Description**: Failures to properly update state variables can lead to inconsistent contract state and security vulnerabilities.

**Vulnerable Code**:
```solidity
// ❌ Bad: Inconsistent state update
function withdraw(uint256 amount) external {
    require(balances[msg.sender] >= amount, "Insufficient balance");
    token.transfer(msg.sender, amount);
    // Missing balance update
}
```

**Secure Code**:
```solidity
// ✅ Good: Proper state update
function withdraw(uint256 amount) external {
    require(balances[msg.sender] >= amount, "Insufficient balance");
    balances[msg.sender] -= amount;
    token.transfer(msg.sender, amount);
}
```

**Prevention**:
- Ensure all state changes are completed before external calls
- Follow checks-effects-interactions pattern
- Use reentrancy guards
- Add thorough tests for state consistency

### Hardcoded Gas Parameters

**Impact**: Medium  
**Likelihood**: Medium  
**Description**: Hardcoded gas values can cause transactions to fail during network congestion or after protocol upgrades.

**Vulnerable Code**:
```solidity
// ❌ Bad: Hardcoded gas value
function transferWithCallback(address to, uint256 amount) external {
    token.transfer(to, amount);
    IReceiver(to).onTokenReceived{gas: 50000}(msg.sender, amount);
}
```

**Secure Code**:
```solidity
// ✅ Good: Configurable gas parameter
uint256 public callbackGasLimit = 50000;

function setCallbackGasLimit(uint256 _limit) external onlyGovernance {
    callbackGasLimit = _limit;
}

function transferWithCallback(address to, uint256 amount) external {
    token.transfer(to, amount);
    IReceiver(to).onTokenReceived{gas: callbackGasLimit}(msg.sender, amount);
}
```

**Prevention**:
- Use configurable gas parameters
- Implement governance controls for gas parameters
- Consider gas price variations in different networks
- Test under different gas price scenarios

### Gas Optimization Issues

**Impact**: Low  
**Likelihood**: High  
**Description**: Inefficient code can lead to excessive gas consumption, making contract interactions expensive or impossible.

**Vulnerable Code**:
```solidity
// ❌ Bad: Inefficient storage access in loop
function batchProcess(uint256[] calldata ids) external {
    for (uint i = 0; i < ids.length; i++) {
        require(itemStatus[ids[i]] == 0, "Already processed");
        itemStatus[ids[i]] = 1;
        processItem(ids[i]);
    }
}
```

**Secure Code**:
```solidity
// ✅ Good: Optimized storage access
function batchProcess(uint256[] calldata ids) external {
    uint256 length = ids.length;
    for (uint i = 0; i < length; i++) {
        uint256 id = ids[i];
        require(itemStatus[id] == 0, "Already processed");
        itemStatus[id] = 1;
        processItem(id);
    }
}
```

**Prevention**:
- Use storage efficiently
- Optimize loops and array operations
- Cache frequently accessed storage variables in memory
- Use events instead of storage for historical data
- Implement gas-efficient patterns

### Missing Access Controls

**Impact**: Critical  
**Likelihood**: High  
**Description**: Functions without proper access controls can be called by unauthorized users, leading to security breaches.

**Vulnerable Code**:
```solidity
// ❌ Bad: No access control
function withdraw(uint256 amount) external {
    payable(msg.sender).transfer(amount);
}
```

**Secure Code**:
```solidity
// ✅ Good: With access control
function withdraw(uint256 amount) external onlyOwner {
    payable(msg.sender).transfer(amount);
}
```

**Prevention**:
- Add modifiers for access control
- Use OpenZeppelin's Access Control contracts
- Implement role-based access control for complex systems
- Document access control assumptions

### Centralization Risks

**Impact**: High  
**Likelihood**: Medium  
**Description**: Critical functions controlled by a single address create points of failure and centralization risks.

**Vulnerable Code**:
```solidity
// ❌ Bad: Centralized control
address public admin;

function setFee(uint256 newFee) external {
    require(msg.sender == admin, "Not admin");
    fee = newFee;
}
```

**Secure Code**:
```solidity
// ✅ Good: Distributed control
function setFee(uint256 newFee) external {
    require(governance.hasVoted(newFee), "Not approved");
    require(timelock.isReady(FEE_CHANGE_TIMELOCK_ID), "Timelock not ready");
    fee = newFee;
}
```

**Prevention**:
- Implement multi-signature schemes
- Use timelocks for sensitive operations
- Create governance mechanisms
- Add limits and bounds for parameter changes

### Unprotected Initializers

**Impact**: Critical  
**Likelihood**: Medium  
**Description**: Initialization functions without proper access control can lead to contract hijacking.

**Vulnerable Code**:
```solidity
// ❌ Bad: Unprotected initializer
function initialize(address _admin) external {
    admin = _admin;
}
```

**Secure Code**:
```solidity
// ✅ Good: Protected initializer
bool private initialized;

function initialize(address _admin) external {
    require(!initialized, "Already initialized");
    initialized = true;
    admin = _admin;
}
```

**Prevention**:
- Add initialization guards
- Use OpenZeppelin's Initializable contract
- Implement one-time setup patterns
- Consider using constructors when possible

### Authority Access Issues

**Impact**: High  
**Likelihood**: Medium  
**Description**: Incorrect authority assignment or missing privileges can prevent legitimate operations or create vulnerabilities.

**Vulnerable Code**:
```solidity
// ❌ Bad: Missing authority assignment
function delegateVault(address newVaultManager) external onlyOwner {
    vaultManager = newVaultManager;
    // Missing authority transfer in the vault
}
```

**Secure Code**:
```solidity
// ✅ Good: Complete authority transfer
function delegateVault(address newVaultManager) external onlyOwner {
    vaultManager = newVaultManager;
    vault.setAuthority(newVaultManager);
}
```

**Prevention**:
- Track all authority relationships
- Implement proper authority transfer functions
- Test authority transitions thoroughly
- Document authority requirements

### Logic Errors

**Impact**: High  
**Likelihood**: High  
**Description**: Incorrect implementation of business rules can lead to unexpected behavior and economic vulnerabilities.

**Vulnerable Code**:
```solidity
// ❌ Bad: Logic error in condition
function rewardQualified(uint256 stakeDuration) internal pure returns (bool) {
    // Intended to check if duration is at least 30 days
    return stakeDuration < 30 days;
}
```

**Secure Code**:
```solidity
// ✅ Good: Corrected logic
function rewardQualified(uint256 stakeDuration) internal pure returns (bool) {
    return stakeDuration >= 30 days;
}
```

**Prevention**:
- Implement extensive test coverage
- Create formal verification specs for complex logic
- Use clear variable naming
- Add detailed comments for complex logic

### Oracle Manipulation

**Impact**: Critical  
**Likelihood**: Medium  
**Description**: Price feeds or oracles that can be manipulated may lead to economic exploits and fund theft.

**Vulnerable Code**:
```solidity
// ❌ Bad: Single oracle price source
function getTokenPrice(address token) external view returns (uint256) {
    return oracle.getPrice(token);
}
```

**Secure Code**:
```solidity
// ✅ Good: Multiple oracle sources with deviation check
function getTokenPrice(address token) external view returns (uint256) {
    uint256 price1 = oracle1.getPrice(token);
    uint256 price2 = oracle2.getPrice(token);
    uint256 price3 = oracle3.getPrice(token);
    
    require(isWithinDeviation(price1, price2, maxDeviation), "Price deviation too high");
    require(isWithinDeviation(price2, price3, maxDeviation), "Price deviation too high");
    
    return (price1 + price2 + price3) / 3;
}
```

**Prevention**:
- Use multiple oracle sources
- Implement price deviation checks
- Consider time-weighted average prices (TWAPs)
- Add circuit breakers for extreme price movements

### Calculation Errors

**Impact**: High  
**Likelihood**: Medium  
**Description**: Mathematical errors in formulas or algorithms can lead to incorrect results and economic losses.

**Vulnerable Code**:
```solidity
// ❌ Bad: Calculation error
function calculateInterest(uint256 principal, uint256 rate, uint256 time) internal pure returns (uint256) {
    // Wrong formula: should be principal * rate * time / 10000
    return principal * rate / time / 10000;
}
```

**Secure Code**:
```solidity
// ✅ Good: Correct calculation
function calculateInterest(uint256 principal, uint256 rate, uint256 time) internal pure returns (uint256) {
    return principal * rate * time / 10000;
}
```

**Prevention**:
- Verify formulas against mathematical specifications
- Use established libraries for complex calculations
- Create unit tests with known expected results
- Consider fixed-point libraries for precise calculations

### Redundant Functions

**Impact**: Low  
**Likelihood**: Medium  
**Description**: Empty or unnecessary functions create misleading security expectations and confusion.

**Vulnerable Code**:
```solidity
// ❌ Bad: Empty function with misleading name
function removeFromWhitelist(address user) external onlyOwner {
    // Function appears to remove from whitelist but doesn't actually do anything
}
```

**Secure Code**:
```solidity
// ✅ Good: Complete implementation
function removeFromWhitelist(address user) external onlyOwner {
    whitelist[user] = false;
    emit WhitelistRemoved(user);
}
```

**Prevention**:
- Remove unused functions
- Implement functionality as suggested by function names
- Document intentionally empty functions
- Add test coverage for all functions

### Front-running Vulnerabilities

**Impact**: High  
**Likelihood**: Medium  
**Description**: Transactions vulnerable to front-running can be exploited to extract value or manipulate outcomes.

**Vulnerable Code**:
```solidity
// ❌ Bad: Vulnerable to front-running
function swapTokens(address tokenIn, address tokenOut, uint256 minAmountOut) external {
    uint256 amountOut = doSwap(tokenIn, tokenOut, msg.value);
    require(amountOut >= minAmountOut, "Slippage too high");
}
```

**Secure Code**:
```solidity
// ✅ Good: With front-running protection
function swapTokens(
    address tokenIn, 
    address tokenOut, 
    uint256 minAmountOut,
    uint256 deadline
) external {
    require(block.timestamp <= deadline, "Transaction expired");
    uint256 amountOut = doSwap(tokenIn, tokenOut, msg.value);
    require(amountOut >= minAmountOut, "Slippage too high");
}
```

**Prevention**:
- Add transaction deadlines
- Implement commit-reveal schemes for sensitive operations
- Consider batch auctions for price-sensitive operations
- Use private mempools or flashbots for critical transactions

### Timestamp Dependence

**Impact**: Medium  
**Likelihood**: Medium  
**Description**: Heavy reliance on block.timestamp for critical operations can lead to miner manipulation and timing issues.

**Vulnerable Code**:
```solidity
// ❌ Bad: Direct timestamp comparison
function isEligibleForDiscount() public view returns (bool) {
    return block.timestamp % 3600 < 300; // First 5 minutes of every hour
}
```

**Secure Code**:
```solidity
// ✅ Good: Reduced timestamp dependence
function isEligibleForDiscount(uint256 blockNumber) public view returns (bool) {
    // Use block numbers for timing-sensitive operations
    return blockNumber % 240 < 20; // Assuming 15s blocks, first 5 minutes
}
```

**Prevention**:
- Use block numbers instead of timestamps when possible
- Allow for timestamp variance (±15 seconds)
- Avoid precise timing requirements
- Consider oracle-provided timestamps for critical operations

### Signature Replay

**Impact**: Critical  
**Likelihood**: Medium  
**Description**: Lack of nonce or other protection can allow signatures to be reused in multiple transactions.

**Vulnerable Code**:
```solidity
// ❌ Bad: No replay protection
function executeWithSignature(bytes32 hash, bytes memory signature) external {
    address signer = recoverSigner(hash, signature);
    require(isAuthorized[signer], "Unauthorized");
    
    // Execute operation
}
```

**Secure Code**:
```solidity
// ✅ Good: With nonce-based replay protection
mapping(address => uint256) public nonces;

function executeWithSignature(
    bytes32 hash,
    bytes memory signature,
    uint256 nonce
) external {
    require(nonce == nonces[msg.sender], "Invalid nonce");
    nonces[msg.sender]++;
    
    address signer = recoverSigner(hash, signature);
    require(isAuthorized[signer], "Unauthorized");
    
    // Execute operation
}
```

**Prevention**:
- Implement nonce tracking
- Include unique identifiers in signed data
- Add expiration timestamps to signatures
- Consider EIP-712 for structured signing

### Off by One Issue

**Impact**: Medium  
**Likelihood**: High  
**Description**: Off-by-one errors occur when loops or array operations miscalculate the valid range of indices, often accessing memory positions that are out of intended bounds.

**Vulnerable Code**:
```solidity
// ❌ Bad: Off-by-one in loop boundary
function processItems(uint256[] memory items) external {
    // Should be i < items.length
    for (uint256 i = 0; i <= items.length; i++) {
        processItem(items[i]); // Will access out of bounds at i = items.length
    }
}
```

**Secure Code**:
```solidity
// ✅ Good: Correct loop boundary
function processItems(uint256[] memory items) external {
    for (uint256 i = 0; i < items.length; i++) {
        processItem(items[i]);
    }
}
```

**Prevention**:
- Double-check loop boundaries, especially with <= vs < conditions
- Be cautious with zero-based vs one-based indexing
- Review array access logic carefully
- Use strict boundary checks even when accessing enumerables
- Add thorough tests including edge cases (empty arrays, single item arrays)

### Incomplete State Updates

**Impact**: Critical  
**Likelihood**: High  
**Description**: Missing or incorrect state updates can lead to inconsistent contract states, fund loss, or broken functionality.

**Vulnerable Code**:
```solidity
// ❌ Bad: Incomplete state update
function transferOwnership(address newOwner) external onlyOwner {
    owner = newOwner;
    // Missing state update for related permissions
    // Missing event emission
}
```

**Secure Code**:
```solidity
// ✅ Good: Complete state update
function transferOwnership(address newOwner) external onlyOwner {
    require(newOwner != address(0), "New owner cannot be zero address");
    address oldOwner = owner;
    owner = newOwner;
    
    // Update related permissions
    isAdmin[oldOwner] = false;
    isAdmin[newOwner] = true;
    
    emit OwnershipTransferred(oldOwner, newOwner);
}
```

**Prevention**:
- Ensure all related state variables are updated atomically
- Use comprehensive test cases that verify state consistency
- Create state invariants and check them in tests
- Document state relationships between variables

### Improper Pause Mechanisms

**Impact**: High  
**Likelihood**: Medium  
**Description**: Improper implementation of pause/disable mechanisms can lead to locked funds, blocked critical operations, or unusable contracts.

**Vulnerable Code**:
```solidity
// ❌ Bad: Pause mechanism that locks user funds
function setPoolEnabled(uint256 poolId, bool enabled) external onlyAdmin {
    pools[poolId].enabled = enabled;
    // No mechanism to allow users to withdraw funds if disabled
}

function bid(uint256 poolId, uint256 amount) external {
    require(pools[poolId].enabled, "Pool disabled");
    // Process bid...
}

// No withdrawal function that works when pool is disabled
```

**Secure Code**:
```solidity
// ✅ Good: Pause mechanism with emergency withdrawal
function setPoolEnabled(uint256 poolId, bool enabled) external onlyAdmin {
    pools[poolId].enabled = enabled;
    emit PoolStatusChanged(poolId, enabled);
}

function bid(uint256 poolId, uint256 amount) external {
    require(pools[poolId].enabled, "Pool disabled");
    // Process bid...
}

// Critical withdrawal function that works even when paused
function emergencyWithdraw(uint256 poolId) external {
    require(hasBid[msg.sender][poolId], "No bids to withdraw");
    uint256 amount = userBids[msg.sender][poolId];
    userBids[msg.sender][poolId] = 0;
    hasBid[msg.sender][poolId] = false;
    
    token.transfer(msg.sender, amount);
    emit EmergencyWithdraw(msg.sender, poolId, amount);
}
```

**Prevention**:
- Implement emergency withdrawal mechanisms that work when paused
- Test both pause and unpause functionality thoroughly
- Document which operations should still work when paused
- Consider tiered pause mechanisms (partial vs. full system pause)
- Ensure critical user operations like withdrawals remain available
- Reference: [Pashov Audit Group - Bunni](https://solodit.cyfrin.io/issues/m-03-funds-from-bids-can-get-locked-if-amamm-is-disabled-for-a-pool-pashov-audit-group-none-bunni-august-markdown)

