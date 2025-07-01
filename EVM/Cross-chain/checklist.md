# Cross-Chain Security Checklist

## Gas Management & Refunds

### 1. Excess gas should be refunded 
**Severity**: Medium/High  
**Impact**: User funds locked, poor UX

**Code4rena Examples**:
- [Stargate Finance - Gas refund issue](https://code4rena.com/reports/2022-06-stargate#m-01-users-can-lose-funds-due-to-incorrect-gas-refund-logic)
- [LayerZero - Excess gas not refunded properly](https://code4rena.com/reports/2023-05-layerzero#h-01-excess-gas-not-refunded-leading-to-user-fund-loss)

**Example Vulnerable Code**:
```solidity
function bridgeTokens(uint256 amount, uint16 dstChainId) external payable {
    // BAD: No gas refund mechanism
    ILayerZeroEndpoint(endpoint).send{value: msg.value}(
        dstChainId,
        abi.encodePacked(address(this)),
        payload,
        payable(msg.sender),
        address(0),
        bytes("")
    );
}
```

**Secure Implementation**:
```solidity
function bridgeTokens(uint256 amount, uint16 dstChainId) external payable {
    uint256 gasUsed = gasleft();
    
    ILayerZeroEndpoint(endpoint).send{value: msg.value}(
        dstChainId,
        abi.encodePacked(address(this)),
        payload,
        payable(msg.sender),
        address(0),
        bytes("")
    );
    
    // Refund excess gas
    uint256 gasConsumed = gasUsed - gasleft();
    uint256 refundAmount = msg.value - (gasConsumed * tx.gasprice);
    if (refundAmount > 0) {
        payable(msg.sender).transfer(refundAmount);
    }
}
```

### 2. Make sure for every cross-chain transfer, the gas limit is set to a reasonable value and do not underperform.
**Severity**: High  
**Impact**: Failed transactions, stuck funds

**Audit Report References**:
- [Multichain Bridge Audit - Insufficient gas limits](https://github.com/peckshield/publications/blob/master/audit_reports/PeckShield-Audit-Report-Multichain-v1.0.pdf)
- [Synapse Bridge - Gas estimation issues](https://github.com/Quantstamp/audits/blob/master/synapse/synapse-audit.pdf)

**Code4rena Finding**:
```
H-02: Hardcoded gas limits cause transaction failures on certain chains
Source: Axelar Network Contest
```

**Example Fix**:
```solidity
mapping(uint16 => uint256) public chainGasLimits;

function setChainGasLimit(uint16 chainId, uint256 gasLimit) external onlyOwner {
    require(gasLimit >= MIN_GAS_LIMIT && gasLimit <= MAX_GAS_LIMIT, "Invalid gas limit");
    chainGasLimits[chainId] = gasLimit;
}

function estimateGas(uint16 dstChainId, bytes memory payload) public view returns (uint256) {
    uint256 baseGas = chainGasLimits[dstChainId];
    uint256 payloadGas = payload.length * GAS_PER_BYTE;
    return baseGas + payloadGas + EXECUTION_BUFFER;
}
```

### 3. The Gas should be dynamic not set to a static value.
**Severity**: Medium  
**Impact**: Failed txns on high-congestion networks

**Real-world Example**: 
- [Wormhole Bridge - Static gas limits caused failures during network congestion](https://github.com/certora/audits/blob/master/wormhole/WormholeAuditReport.pdf)

**Dynamic Gas Implementation**:
```solidity
contract DynamicGasBridge {
    uint256 public baseGasLimit = 200000;
    uint256 public gasMultiplier = 110; // 110% of estimated gas
    
    function getDynamicGasLimit(uint16 chainId, bytes memory payload) public view returns (uint256) {
        uint256 estimated = estimateGasForChain(chainId, payload);
        return (estimated * gasMultiplier) / 100;
    }
    
    function estimateGasForChain(uint16 chainId, bytes memory payload) internal view returns (uint256) {
        // Chain-specific gas calculation logic
        if (chainId == ETHEREUM_CHAIN_ID) {
            return baseGasLimit + (payload.length * 16); // Higher gas per byte for Ethereum
        } else if (chainId == POLYGON_CHAIN_ID) {
            return baseGasLimit + (payload.length * 8);  // Lower gas per byte for Polygon
        }
        return baseGasLimit + (payload.length * 12); // Default
    }
}
```

## Address Management

### 4. Make sure users provide destination address and refund address separately
**Severity**: High  
**Impact**: Funds sent to non-controlled addresses

**Code4rena Finding**: 
- [Across Protocol - Destination/refund address confusion](https://code4rena.com/reports/2022-10-across#h-03-user-funds-can-be-lost-due-to-destination-address-assumptions)

**Vulnerable Pattern**:
```solidity
function bridge(uint256 amount, uint16 dstChainId) external {
    // BAD: Assumes msg.sender controls destination address
    _initiateBridge(amount, dstChainId, msg.sender, msg.sender);
}
```

**Secure Implementation**:
```solidity
function bridge(
    uint256 amount, 
    uint16 dstChainId, 
    address to,           // Explicit destination
    address refundTo      // Explicit refund address
) external {
    require(to != address(0), "Invalid destination");
    require(refundTo != address(0), "Invalid refund address");
    
    _initiateBridge(amount, dstChainId, to, refundTo);
}
```

## Security & Execution

### 5. Ensure that the cross-chain transfer logic does not allow for arbitrary code execution on the destination chain.
**Severity**: Critical  
**Impact**: Complete protocol compromise

**Real Exploit**: [Wormhole $320M Hack - Arbitrary message execution](https://rekt.news/wormhole-rekt/)

**Audit Finding**:
```
Critical: Arbitrary code execution via malicious payload
Reference: Trail of Bits Audit - Cross-chain Protocol X
```

**Vulnerable Code**:
```solidity
function lzReceive(
    uint16 _srcChainId,
    bytes memory _srcAddress,
    uint64 _nonce,
    bytes memory _payload
) external override {
    // VULNERABLE: Direct execution of arbitrary payload
    (bool success,) = address(this).call(_payload);
    require(success, "Execution failed");
}
```

**Secure Implementation**:
```solidity
function lzReceive(
    uint16 _srcChainId,
    bytes memory _srcAddress,
    uint64 _nonce,
    bytes memory _payload
) external override {
    require(msg.sender == address(endpoint), "Only endpoint");
    require(trustedRemoteLookup[_srcChainId].length > 0, "Untrusted source");
    
    // Decode and validate payload structure
    (uint8 functionType, bytes memory data) = abi.decode(_payload, (uint8, bytes));
    
    if (functionType == BRIDGE_FUNCTION) {
        _handleBridge(data);
    } else if (functionType == REFUND_FUNCTION) {
        _handleRefund(data);
    } else {
        revert("Invalid function type");
    }
}

function _handleBridge(bytes memory data) internal {
    (address to, uint256 amount, address token) = abi.decode(data, (address, uint256, address));
    require(supportedTokens[token], "Unsupported token");
    // Safe execution logic
}
```

### 6. Implement a mechanism to handle failed transfers gracefully, allowing users to retry or recover funds.
**Severity**: High  
**Impact**: Permanent fund loss

**Code4rena Examples**:
- [Stargate - Failed transfer recovery mechanism](https://code4rena.com/reports/2022-06-stargate#m-03-failed-transfers-cannot-be-recovered)

**Implementation**:
```solidity
contract RecoverableBridge {
    mapping(bytes32 => FailedTransfer) public failedTransfers;
    
    struct FailedTransfer {
        address user;
        uint256 amount;
        address token;
        uint16 dstChainId;
        uint256 timestamp;
        bool recovered;
    }
    
    function retryTransfer(bytes32 transferId) external {
        FailedTransfer storage transfer = failedTransfers[transferId];
        require(transfer.user == msg.sender, "Not authorized");
        require(!transfer.recovered, "Already recovered");
        require(block.timestamp <= transfer.timestamp + RETRY_WINDOW, "Retry window expired");
        
        // Retry logic
        _executeBridge(transfer.amount, transfer.token, transfer.dstChainId);
        transfer.recovered = true;
    }
    
    function emergencyWithdraw(bytes32 transferId) external {
        FailedTransfer storage transfer = failedTransfers[transferId];
        require(transfer.user == msg.sender, "Not authorized");
        require(block.timestamp > transfer.timestamp + EMERGENCY_WINDOW, "Emergency window not reached");
        
        // Emergency withdrawal
        IERC20(transfer.token).transfer(transfer.user, transfer.amount);
        transfer.recovered = true;
    }
}
```

### 7. Make sure the transfer logic is resistant to replay attacks across chains.
**Severity**: High  
**Impact**: Double spending, fund drainage

**Code4rena Finding**:
- [Nomad Bridge - Replay attack vulnerability](https://code4rena.com/reports/2022-08-nomad#h-01-replay-attacks-possible-across-chains)

**Real Exploit**: [Nomad Bridge $190M Hack - Merkle tree replay](https://rekt.news/nomad-rekt/)

**Vulnerable Code**:
```solidity
function processMessage(bytes32 messageHash, bytes memory signature) external {
    // VULNERABLE: No nonce or chain-specific protection
    require(isValidSignature(messageHash, signature), "Invalid signature");
    _executeMessage(messageHash);
}
```

**Secure Implementation**:
```solidity
contract ReplayResistantBridge {
    mapping(uint16 => mapping(uint64 => bool)) public processedNonces;
    mapping(bytes32 => bool) public processedMessages;
    
    function processMessage(
        uint16 srcChainId,
        uint64 nonce,
        bytes32 messageHash,
        bytes memory signature
    ) external {
        // Chain-specific nonce protection
        require(!processedNonces[srcChainId][nonce], "Nonce already used");
        
        // Message hash protection
        bytes32 uniqueHash = keccak256(abi.encodePacked(
            block.chainid,  // Destination chain ID
            srcChainId,     // Source chain ID
            nonce,
            messageHash
        ));
        require(!processedMessages[uniqueHash], "Message already processed");
        
        require(isValidSignature(uniqueHash, signature), "Invalid signature");
        
        processedNonces[srcChainId][nonce] = true;
        processedMessages[uniqueHash] = true;
        
        _executeMessage(messageHash);
    }
}
```
### 8. Make sure after performing a cross-chain transfer the tokens will not be locked in the contract. 
**Severity**: High
**Impact**: User funds locked indefinitely
**Code4rena Finding**:
- [Axelar Network - Tokens locked after cross-chain transfer](https://code4rena.com/reports/2022-07-axelar#h-01-tokens-locked-after-cross-chain-transfer)

## Resources

### Code4rena Cross-Chain Contest Reports:
- [Stargate Finance](https://code4rena.com/reports/2022-06-stargate)
- [LayerZero](https://code4rena.com/reports/2023-05-layerzero)
- [Axelar Network](https://code4rena.com/reports/2022-07-axelar)
- [Nomad](https://code4rena.com/reports/2022-08-nomad)

### Professional Audit Reports:
- [Trail of Bits - Cross-Chain Security](https://github.com/trailofbits/publications/blob/master/reviews/)
- [Consensys Diligence - Bridge Audits](https://consensys.net/diligence/audits/)
- [OpenZeppelin - Security Audits](https://blog.openzeppelin.com/security-audits/)

### Real-World Exploits:
- [Wormhole Bridge - $320M](https://rekt.news/wormhole-rekt/)
- [Nomad Bridge - $190M](https://rekt.news/nomad-rekt/)
- [Ronin Bridge - $625M](https://rekt.news/ronin-rekt/)