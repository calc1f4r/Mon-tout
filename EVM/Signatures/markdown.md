# Signature Replay Attacks Database

## Overview
Signature replay attacks allow an attacker to replay a previous transaction by copying its signature and passing the validation check. Signatures are primarily used to authorize transactions on behalf of the signer and to prove that a signer signed a specific message.

## Common Vulnerabilities & Attack Types


A signature should have all the data neccessary in the signature. 
### 1. Missing Nonce Replay

**Description**: When smart contracts don't implement proper nonce tracking, signatures can be replayed multiple times.

**Example Case**: Ondo Finance KYC Registry
```solidity
function addKYCAddressViaSignature( 
    uint256 kycRequirementGroup,
    address user,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s 
) external {
    bytes32 structHash = keccak256(
      abi.encode(_APPROVAL_TYPEHASH, kycRequirementGroup, user, deadline)
    );
    bytes32 expectedMessage = _hashTypedDataV4(structHash);
    address signer = ECDSA.recover(expectedMessage, v, r, s);
    // Missing nonce validation allows signature replay
}
```

**Prevention**:
- Keep track of a nonce for each user
- Make the current nonce available to signers
- Validate the signature using the current nonce
- Mark used nonces in storage to prevent reuse

**Secure Implementation Example** (OpenZeppelin ERC20Permit):
```solidity
function permit(
    address owner,
    address spender,
    uint256 value,
    uint256 deadline,
    uint8 v,
    bytes32 r,
    bytes32 s
) public virtual override {
    bytes32 structHash = keccak256(abi.encode(
        _PERMIT_TYPEHASH, 
        owner, 
        spender, 
        value, 
        _useNonce(owner), // Proper nonce usage
        deadline
    ));
    bytes32 hash = _hashTypedDataV4(structHash);
    // ...
}

function _useNonce(address owner) internal virtual returns (uint256 current) {
    Counters.Counter storage nonce = _nonces[owner];
    current = nonce.current();
    nonce.increment(); // Increment after use
}
```

**Real Examples**:
- [Ondo Finance KYC Registry](https://code4rena.com/reports/2023-01-ondo/#m-04-kycregistry-is-susceptible-to-signature-replay-attack)
- [Rigor Builder Escrow](https://code4rena.com/reports/2022-08-rigor/#h-03-builder-can-call-communityescrow-again-to-reduce-debt-further-using-same-signatures)
- [Foundation Private Sales](https://code4rena.com/reports/2022-02-foundation/#m-01-eip-712-signatures-can-be-re-used-in-private-sales)

### 2. Cross Chain Replay

**Description**: Signatures valid on one chain can be replayed on another chain if chain ID is not included in the signature.

**Vulnerable Example** (Biconomy):
```solidity
function getHash(UserOperation calldata userOp) public pure returns (bytes32) {
    return keccak256(abi.encode(
        userOp.getSender(),
        userOp.nonce,
        keccak256(userOp.initCode),
        keccak256(userOp.callData),
        userOp.callGasLimit,
        userOp.verificationGasLimit,
        userOp.preVerificationGas,
        userOp.maxFeePerGas,
        userOp.maxPriorityFeePerGas
        // Missing: chain ID
    ));
}
```

**Prevention**:
- Include `block.chainid` in signature validation
- Use EIP-712 which incorporates chain ID in domain separator
- Ensure users sign messages with chain ID included

**Real Examples**:
- [Biconomy Cross-chain Replay](https://code4rena.com/reports/2023-01-biconomy#m-03-cross-chain-signature-replay-attack)
- [Harpie Cross-chain Attack](https://github.com/sherlock-audit/2022-09-harpie-judging/blob/main/004-M/1-report.md)

### 3. Missing Parameter

**Description**: Critical parameters used in function execution are not included in the signature, allowing attackers to manipulate them.

**Vulnerable Example** (Biconomy Gas Refund):
```solidity
// Signature encoding - missing tokenGasPriceFactor
function encodeTransactionData(
    Transaction memory _tx,
    FeeRefund memory refundInfo,
    uint256 _nonce
) public view returns (bytes memory) {
    bytes32 safeTxHash = keccak256(abi.encode(
        ACCOUNT_TX_TYPEHASH,
        _tx.to,
        _tx.value,
        keccak256(_tx.data),
        _tx.operation,
        _tx.targetTxGas,
        refundInfo.baseGas,
        refundInfo.gasPrice,
        refundInfo.gasToken,
        refundInfo.refundReceiver,
        _nonce
        // Missing: tokenGasPriceFactor used in payment calculation
    ));
    return abi.encodePacked(bytes1(0x19), bytes1(0x01), domainSeparator(), safeTxHash);
}

// Payment calculation uses unsigned parameter
function handlePaymentRevert(
    uint256 gasUsed,
    uint256 baseGas,
    uint256 gasPrice,
    uint256 tokenGasPriceFactor, // Not in signature!
    address gasToken,
    address payable refundReceiver
) external returns (uint256 payment) {
    payment = (gasUsed + baseGas) * (gasPrice) / (tokenGasPriceFactor);
}
```

**Prevention**:
- Include ALL parameters that affect function behavior in signatures
- Carefully audit signature parameters vs function parameters
- Use comprehensive parameter encoding in EIP-712 structs

**Real Examples**:
- [Biconomy Fee Refund](https://code4rena.com/reports/2023-01-biconomy/#h-06-feerefundtokengaspricefactor-is-not-included-in-signed-transaction-data-allowing-the-submitter-to-steal-funds)
- [Sparkn Missing Parameters](https://github.com/Cyfrin/2023-08-sparkn/issues/306)

### 4. No Expiration

**Description**: Signatures without expiration timestamps create "lifetime licenses" that can be replayed indefinitely.

**Vulnerable Example** (NFTPort):
```solidity
function call(
    address instance,
    bytes calldata data,
    bytes calldata signature
) external payable 
  operatorOnly(instance)
  signedOnly(abi.encodePacked(msg.sender, instance, data), signature) 
{
    _call(instance, data, msg.value);
    // No expiration check - signature valid forever
}
```

**Secure Implementation**:
```solidity
function call(CallRequest calldata request, bytes calldata signature)
    external payable
    operatorOnly(request.instance)
    validRequestOnly(request.metadata) // Checks expiration
    signedOnly(_hash(request), signature)
{
    _call(request.instance, request.callData, msg.value);
}

function _hash(RequestMetadata calldata metadata) internal pure returns (bytes32) {
    return keccak256(abi.encode(
        _REQUEST_METADATA_TYPEHASH,
        metadata.caller,
        metadata.expiration // Include expiration in signature
    ));
}
```

**Prevention**:
- Always include expiration/deadline timestamps
- Validate timestamps before signature verification
- Use reasonable expiration windows
- Follow EIP-712 standards for timestamp handling

**Real Examples**:
- [NFTPort Missing Expiration](https://github.com/sherlock-audit/2022-10-nftport-judging/issues/46)

### 5. Unchecked ecrecover() Return

**Description**: `ecrecover()` returns `address(0)` for invalid signatures, which must be explicitly checked.

**Vulnerable Example** (Swivel):
```solidity
function validOrderHash(Hash.Order calldata o, Sig.Components calldata c) internal view returns (bytes32) {
    bytes32 hash = Hash.order(o);
    // Dangerous: if ecrecover returns 0 and o.maker is 0, this passes!
    require(o.maker == Sig.recover(Hash.message(domain, hash), c), 'invalid signature');
}

function recover(bytes32 h, Components calldata c) internal pure returns (address) {
    return ecrecover(h, c.v, c.r, c.s); // No zero check
}
```

**Attack Vector**:
- Attacker sets `o.maker = address(0)`
- Provides invalid signature that makes `ecrecover()` return `address(0)`
- Check `o.maker == address(0)` passes, bypassing signature validation

**Prevention**:
```solidity
function recover(bytes32 h, Components calldata c) internal pure returns (address) {
    address signer = ecrecover(h, c.v, c.r, c.s);
    require(signer != address(0), "Invalid signature");
    return signer;
}
```

**Best Practice**: Use OpenZeppelin's `ECDSA.recover()` which includes zero checks.

**Real Examples**:
- [Swivel ecrecover Issue](https://code4rena.com/reports/2021-09-swivel#h-04-return-value-of-0-from-ecrecover-not-checked)
- [Astaria Zero Address](https://github.com/sherlock-audit/2022-10-astaria-judging/issues/69)

### 6. Signature Malleability

**Description**: Elliptic curve signatures are mathematically malleable - for every valid signature `[v,r,s]`, there exists another valid `[v',r',s']` that produces the same result.

**Vulnerable Pattern**:
```solidity
function verify(address signer, bytes32 hash, bytes memory signature) internal pure returns (bool) {
    require(signature.length == 65);
    
    bytes32 r;
    bytes32 s;
    uint8 v;
    
    assembly {
        r := mload(add(signature, 32))
        s := mload(add(signature, 64))
        v := byte(0, mload(add(signature, 96)))
    }
    
    if (v < 27) { v += 27; }
    require(v == 27 || v == 28);
    
    // Vulnerable to signature malleability
    return signer == ecrecover(hash, v, r, s);
}
```

**Attack Vector**:
- Attacker takes valid signature `[v,r,s]`
- Computes malleable signature `[v',r',s']`
- Both signatures validate but have different hash values
- Can bypass nonce/replay protections that rely on signature uniqueness

**Prevention**:
- Use OpenZeppelin's `ECDSA.sol` library (v4.7.3+)
- Implement proper `s` value validation (`s <= secp256k1n ÷ 2`)
- Use EIP-712 which provides additional protections

**Secure Implementation**:
```solidity
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

function verifySignature(bytes32 hash, bytes memory signature, address expectedSigner) 
    internal pure returns (bool) 
{
    address recoveredSigner = ECDSA.recover(hash, signature);
    return recoveredSigner == expectedSigner;
}
```

**Real Examples**:
- [Larva Labs Signature Malleability](https://github.com/code-423n4/2021-04-meebits)
- [HyperLiquid DEX Issue](https://github.com/ChainAccelOrg/cyfrin-audit-reports/blob/main/reports/2023-04-11-cyfrin-hyperliquid-dex-report.pdf)

## Prevention Best Practices

### 1. Use Established Libraries
- **OpenZeppelin ECDSA.sol** (v4.7.3+) for signature verification
- **OpenZeppelin EIP712.sol** for structured data signing
- **OpenZeppelin Counters.sol** for nonce management

### 2. EIP-712 Implementation
```solidity
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";

contract SecureSignatures is EIP712 {
    mapping(address => uint256) private _nonces;
    
    bytes32 private constant _PERMIT_TYPEHASH = keccak256(
        "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"
    );
    
    constructor() EIP712("MyContract", "1") {}
    
    function executeWithSignature(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        bytes memory signature
    ) external {
        require(block.timestamp <= deadline, "Signature expired");
        
        bytes32 structHash = keccak256(abi.encode(
            _PERMIT_TYPEHASH,
            owner,
            spender,
            value,
            _useNonce(owner),
            deadline
        ));
        
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSA.recover(hash, signature);
        require(signer == owner, "Invalid signature");
        
        // Execute logic...
    }
    
    function _useNonce(address owner) internal returns (uint256 current) {
        current = _nonces[owner];
        _nonces[owner] = current + 1;
    }
}
```

### 3. Signature Validation Checklist
- ✅ Include nonce in signature and track usage
- ✅ Include expiration/deadline timestamp
- ✅ Include chain ID (via EIP-712 domain separator)
- ✅ Include ALL function parameters that affect execution
- ✅ Use OpenZeppelin's ECDSA library for recovery
- ✅ Check for `address(0)` return from signature recovery
- ✅ Validate timestamp before signature verification
- ✅ Use EIP-712 structured data signing

### 4. Audit Considerations
- Verify signature parameters match function parameters exactly
- Check for missing nonce incrementation
- Validate expiration timestamp handling
- Ensure cross-chain deployment considerations
- Test signature malleability scenarios
- Verify ecrecover return value handling

## Tools & Resources

### Libraries
- [OpenZeppelin Contracts](https://github.com/OpenZeppelin/openzeppelin-contracts)
  - `utils/cryptography/ECDSA.sol`
  - `utils/cryptography/EIP712.sol`
  - `utils/Counters.sol`

### Standards
- [EIP-712: Typed structured data hashing and signing](https://eips.ethereum.org/EIPS/eip-712)
- [EIP-2612: Permit Extension for EIP-20](https://eips.ethereum.org/EIPS/eip-2612)

### Security Resources
- [SWC-117: Signature Malleability](https://swcregistry.io/docs/SWC-117)
- [SWC-121: Missing Protection against Signature Replay Attacks](https://swcregistry.io/docs/SWC-121)
- [ImmuneFi Cryptography Guide](https://medium.com/immunefi/intro-to-cryptography-and-signatures-in-ethereum-2025b6a4a33d)

## Testing Strategies

### Replay Attack Tests
```solidity
// Test nonce replay protection
function testNonceReplayProtection() public {
    // Execute transaction with signature
    contract.executeWithSignature(owner, spender, value, deadline, signature);
    
    // Attempt to replay same signature - should fail
    vm.expectRevert("Invalid nonce");
    contract.executeWithSignature(owner, spender, value, deadline, signature);
}

// Test cross-chain replay protection
function testCrossChainReplay() public {
    // Get signature on chain A
    bytes memory signature = getValidSignature();
    
    // Switch to different chain ID
    vm.chainId(differentChainId);
    
    // Signature should be invalid on different chain
    vm.expectRevert("Invalid signature");
    contract.executeWithSignature(owner, spender, value, deadline, signature);
}

// Test signature expiration
function testSignatureExpiration() public {
    uint256 deadline = block.timestamp + 1 hours;
    bytes memory signature = getSignatureWithDeadline(deadline);
    
    // Fast forward past deadline
    vm.warp(deadline + 1);
    
    // Should fail due to expiration
    vm.expectRevert("Signature expired");
    contract.executeWithSignature(owner, spender, value, deadline, signature);
}
```

---

*This database serves as a comprehensive reference for identifying, preventing, and testing signature replay vulnerabilities in smart contracts.*