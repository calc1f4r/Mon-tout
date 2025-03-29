# Transparent Proxy Pattern: Deep Dive into Deployment and Upgrade Mechanics

## Overview

Transparent proxies are a crucial component in the upgradeable smart contract ecosystem. They allow contracts to be upgraded while maintaining the same address and state. This document provides an in-depth analysis of the internal mechanics, state changes, and execution flow during deployment and upgrades of transparent proxies.

## Core Components

In a transparent proxy pattern, there are three main components:
1. **Proxy Contract**: Stores data and delegates calls to the implementation
2. **Implementation Contract**: Contains the logic but doesn't store state
3. **ProxyAdmin Contract**: Manages the upgrade process

## Deployment Process: What Actually Happens

When you deploy a transparent upgradeable proxy using OpenZeppelin's upgrades plugin, the following sequence occurs:

### Step 1: Implementation Contract Deployment

```solidity
// Example ERC20Upgradeable Implementation
contract MyTokenV1 is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    function initialize(string memory name, string memory symbol) initializer public {
        __ERC20_init(name, symbol);
        __Ownable_init();
        _mint(msg.sender, 1000000 * 10 ** decimals());
    }
    
    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}
```

**What happens internally:**
1. The implementation contract is deployed first
2. No constructor is executed (implementations must use initializers instead)
3. The contract is deployed in an uninitialized state
4. The implementation contract's address is recorded for use in the proxy

**State after deployment:**
- Implementation contract exists on the blockchain with its own address
- Implementation contract has no state initialized
- Implementation contract is not directly usable (it's just a logic container)

### Step 2: ProxyAdmin Contract Deployment

```solidity
// Simplified ProxyAdmin contract
contract ProxyAdmin {
    address private _owner;
    
    constructor() {
        _owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == _owner, "Ownable: caller is not the owner");
        _;
    }
    
    function getProxyImplementation(TransparentUpgradeableProxy proxy) public view returns (address) {
        // Call the implementation() function on the proxy
        (bool success, bytes memory returndata) = address(proxy).staticcall(
            abi.encodeWithSignature("implementation()")
        );
        require(success);
        return abi.decode(returndata, (address));
    }
    
    function getProxyAdmin(TransparentUpgradeableProxy proxy) public view returns (address) {
        // Call the admin() function on the proxy
        (bool success, bytes memory returndata) = address(proxy).staticcall(
            abi.encodeWithSignature("admin()")
        );
        require(success);
        return abi.decode(returndata, (address));
    }
    
    function upgrade(TransparentUpgradeableProxy proxy, address implementation) public onlyOwner {
        proxy.upgradeTo(implementation);
    }
}
```

**What happens internally:**
1. The ProxyAdmin contract is deployed
2. Its constructor sets the deployer as the owner
3. This contract will have exclusive rights to upgrade the proxy

**State after deployment:**
- ProxyAdmin contract exists on the blockchain with its own address
- ProxyAdmin's storage: `_owner = msg.sender` (the deployer)

### Step 3: TransparentUpgradeableProxy Contract Deployment

```solidity
// Simplified TransparentUpgradeableProxy
contract TransparentUpgradeableProxy {
    // Storage slot with the admin of the contract
    bytes32 internal constant _ADMIN_SLOT = 
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    
    // Storage slot with the address of the current implementation
    bytes32 internal constant _IMPLEMENTATION_SLOT = 
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    
    constructor(
        address _logic,
        address admin_,
        bytes memory _data
    ) payable {
        _setAdmin(admin_);
        _setImplementation(_logic);
        if(_data.length > 0) {
            (bool success,) = _logic.delegatecall(_data);
            require(success);
        }
    }
    
    // Admin functions
    function admin() external ifAdmin returns (address admin_) {
        admin_ = _admin();
    }
    
    function implementation() external ifAdmin returns (address implementation_) {
        implementation_ = _implementation();
    }
    
    function upgradeTo(address newImplementation) external ifAdmin {
        _setImplementation(newImplementation);
    }
    
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable ifAdmin {
        _setImplementation(newImplementation);
        (bool success,) = newImplementation.delegatecall(data);
        require(success);
    }
    
    // Modifier that checks if the caller is the admin
    modifier ifAdmin() {
        if (msg.sender == _admin()) {
            _;
        } else {
            _fallback();
        }
    }
    
    // Fallback function that delegates calls
    fallback() external payable {
        _fallback();
    }
    
    receive() external payable {
        _fallback();
    }
    
    function _fallback() internal {
        _delegate(_implementation());
    }
    
    // Delegate call to implementation
    function _delegate(address implementation_) internal {
        assembly {
            // Copy msg.data
            calldatacopy(0, 0, calldatasize())
            
            // Forward all gas and call data to the implementation
            let result := delegatecall(gas(), implementation_, 0, calldatasize(), 0, 0)
            
            // Copy the returned data
            returndatacopy(0, 0, returndatasize())
            
            switch result
            case 0 {
                // Revert if delegatecall failed
                revert(0, returndatasize())
            }
            default {
                // Return data if delegatecall succeeded
                return(0, returndatasize())
            }
        }
    }
    
    // Read the implementation address from its dedicated storage slot
    function _implementation() internal view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }
    
    // Read the admin address from its dedicated storage slot
    function _admin() internal view returns (address adm) {
        bytes32 slot = _ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }
    
    // Write the implementation address to its dedicated storage slot
    function _setImplementation(address newImplementation) internal {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }
    
    // Write the admin address to its dedicated storage slot
    function _setAdmin(address newAdmin) internal {
        bytes32 slot = _ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }
}
```

**What happens internally during proxy deployment:**
1. The TransparentUpgradeableProxy contract is deployed with three parameters:
   - `_logic`: The address of the implementation contract
   - `admin_`: The address of the ProxyAdmin contract
   - `_data`: The encoded initializer function call (e.g., `initialize("MyToken", "MTK")`)

2. In the constructor:
   - `_setAdmin(admin_)` stores the ProxyAdmin address in a special storage slot (`_ADMIN_SLOT`)
   - `_setImplementation(_logic)` stores the implementation address in another special slot (`_IMPLEMENTATION_SLOT`)
   - If `_data` is not empty, it performs a `delegatecall` to the implementation with this data

3. The `delegatecall` in the constructor:
   - Executes the implementation's `initialize` function
   - But all state changes happen in the proxy's storage context
   - This initializes the ERC20 token state (name, symbol, balances, etc.) in the proxy's storage

**State after deployment:**
- Proxy contract exists on the blockchain with its own address
- Proxy's special storage slots:
  - `_ADMIN_SLOT` contains the ProxyAdmin contract address
  - `_IMPLEMENTATION_SLOT` contains the implementation contract address
- Proxy's regular storage contains the initialized ERC20 state:
  - Token name and symbol
  - Initial supply
  - Owner address
  - etc.

### Storage Layout After Deployment

Here's what the storage layout looks like after deployment:

**Proxy Contract Storage:**
```
// Special storage slots (using deterministic storage locations)
slot 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103: ProxyAdmin address
slot 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc: Implementation address

// ERC20 state (from the initialize function)
slot 0: mapping(address => uint256) _balances
slot 1: mapping(address => mapping(address => uint256)) _allowances
slot 2: uint256 _totalSupply
slot 3: string _name
slot 4: string _symbol
slot 5: address _owner (from OwnableUpgradeable)
// ... other ERC20 state variables
```

**Implementation Contract Storage:**
- Empty (not used)

**ProxyAdmin Contract Storage:**
- slot 0: address _owner (the deployer)

## Function Call Execution Flow

When a user interacts with the proxy contract, here's what happens:

### Case 1: Regular User Calls a Function

```javascript
// Example: A user transfers tokens
await myToken.transfer("0x123...", 100);
```

**Execution flow:**
1. The call arrives at the proxy contract's address
2. The proxy checks if the caller is the admin (stored in `_ADMIN_SLOT`)
3. Since the caller is not the admin, the proxy's fallback function is triggered
4. The fallback function:
   - Retrieves the implementation address from `_IMPLEMENTATION_SLOT`
   - Performs a `delegatecall` to the implementation with the same calldata
5. The implementation's `transfer` function executes
6. All state changes happen in the proxy's storage context
7. The result is returned to the caller

### Case 2: Admin Calls a Proxy Function

```javascript
// Example: Admin upgrades the implementation
await proxyAdmin.upgrade(proxyAddress, newImplementationAddress);
```

**Execution flow:**
1. The ProxyAdmin contract calls `upgradeTo` on the proxy
2. The proxy checks if the caller is the admin (stored in `_ADMIN_SLOT`)
3. Since the caller is the admin, the proxy executes its own `upgradeTo` function
4. The `upgradeTo` function calls `_setImplementation` to update the implementation address in `_IMPLEMENTATION_SLOT`
5. No delegatecall is performed in this case

## Upgrade Process: Internal Mechanics

When upgrading a transparent proxy, the following sequence occurs:

### Step 1: Deploy New Implementation

```solidity
// Example ERC20Upgradeable Implementation V2
contract MyTokenV2 is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    uint256 public cap; // New variable
    
    // No reinitialize of old variables; they keep their values
    function initialize(string memory name, string memory symbol) initializer public {
        __ERC20_init(name, symbol);
        __Ownable_init();
    }
    
    // New function in V2
    function setMaxSupply(uint256 _cap) external onlyOwner {
        cap = _cap;
    }
    
    // Override original function with new logic
    function mint(address to, uint256 amount) public onlyOwner {
        require(cap == 0 || totalSupply() + amount <= cap, "Cap exceeded");
        _mint(to, amount);
    }
}
```

**What happens internally:**
1. The new implementation contract is deployed
2. No constructor is executed
3. The contract is deployed in an uninitialized state
4. The new implementation's address is recorded for the upgrade

**State after deployment:**
- New implementation contract exists on the blockchain with its own address
- New implementation has no state initialized (it will use the proxy's existing state)

### Step 2: Upgrade the Proxy

```javascript
// Using OpenZeppelin Upgrades
await upgrades.upgradeProxy(proxyAddress, MyTokenV2);

// What happens under the hood:
// 1. ProxyAdmin.upgrade(proxy, newImplementation) is called
// 2. Which calls proxy.upgradeTo(newImplementation)
```

**What happens internally:**
1. The ProxyAdmin contract calls `upgradeTo` on the proxy
2. The proxy verifies that the caller is the admin
3. The proxy updates its implementation address in the `_IMPLEMENTATION_SLOT`
4. No initialization is performed (the state remains intact)

**State changes during upgrade:**
- Only the implementation address in the proxy's `_IMPLEMENTATION_SLOT` changes
- All other state (token balances, allowances, name, symbol, etc.) remains unchanged
- The new `cap` variable in V2 is initially zero (default value for uint256)

### Storage Layout After Upgrade

```
// Proxy Contract Storage (after upgrade)
slot 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103: ProxyAdmin address
slot 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc: New Implementation address (changed)

// ERC20 state (unchanged from before)
slot 0: mapping(address => uint256) _balances
slot 1: mapping(address => mapping(address => uint256)) _allowances
slot 2: uint256 _totalSupply
slot 3: string _name
slot 4: string _symbol
slot 5: address _owner
// ... other ERC20 state variables

// New V2 state variables
slot 6: uint256 cap (initially 0)
```

## Storage Collision Prevention

Transparent proxies use deterministic storage slots for admin and implementation addresses to prevent storage collisions with the implementation contract:

```solidity
// These are special keccak256 hashes that are extremely unlikely to collide with
// any storage slot that would be used by the implementation
bytes32 internal constant _ADMIN_SLOT = 
    0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

bytes32 internal constant _IMPLEMENTATION_SLOT = 
    0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
```

These slots are defined by EIP-1967 and are calculated as:
- Admin slot: `keccak256("eip1967.proxy.admin") - 1`
- Implementation slot: `keccak256("eip1967.proxy.implementation") - 1`

The `-1` at the end makes these slots even more unlikely to collide with implementation storage.

## Function Selector Clashing and the Admin Problem

Transparent proxies have a unique challenge: what happens if the implementation has a function with the same signature as the proxy's admin functions?

For example, if the implementation has its own `upgradeTo(address)` function, how does the proxy know whether to:
1. Execute its own `upgradeTo` function (for admin)
2. Delegate to the implementation's `upgradeTo` function (for users)

**The solution: Caller-based dispatch**

The transparent proxy pattern solves this by checking the caller:
- If the caller is the admin → execute proxy functions
- If the caller is anyone else → delegate to implementation

This creates a limitation: **the admin cannot directly call implementation functions through the proxy**. The admin must use a separate account or contract to call implementation functions.

```solidity
// Simplified dispatch logic in TransparentUpgradeableProxy
function _fallback() internal {
    if (msg.sender == _admin()) {
        // Admin is trying to call an implementation function, which is not allowed
        revert("Admin cannot call implementation functions");
    } else {
        // Regular user, delegate to implementation
        _delegate(_implementation());
    }
}
```

## Initializer Pattern vs. Constructors

A critical aspect of upgradeable contracts is the use of initializers instead of constructors:

```solidity
// WRONG - Constructor will only run in the implementation context, not the proxy
constructor(string memory name, string memory symbol) {
    _name = name;
    _symbol = symbol;
    _owner = msg.sender;
}

// CORRECT - Initializer runs via delegatecall in the proxy's context
function initialize(string memory name, string memory symbol) initializer public {
    __ERC20_init(name, symbol);
    __Ownable_init();
    _mint(msg.sender, 1000000 * 10 ** decimals());
}
```

**What happens with initializers:**
1. The `initializer` modifier ensures the function can only be called once
2. The function is called via delegatecall during proxy deployment
3. All state changes happen in the proxy's storage

**The initializer modifier:**
```solidity
// Simplified initializer modifier
modifier initializer() {
    require(!_initialized, "Contract instance has already been initialized");
    _initialized = true;
    _;
}
```

## Detailed Deployment Steps with OpenZeppelin Upgrades

When using OpenZeppelin's Upgrades plugin with `deployProxy`, these are the exact steps that occur:

```javascript
const MyTokenV1 = await ethers.getContractFactory("MyTokenV1");
const proxy = await upgrades.deployProxy(MyTokenV1, ["MyToken", "MTK"]);
```

1. **Validation**:
   - The plugin validates the implementation is upgrade-safe
   - Checks for constructors, immutable variables, selfdestruct, etc.

2. **Implementation Deployment**:
   - Deploys the implementation contract
   - Computes a deterministic address based on the bytecode
   - No constructor arguments are passed

3. **ProxyAdmin Deployment** (if not already deployed):
   - Deploys the ProxyAdmin contract
   - Sets the deployer as the owner
   - Uses a deterministic address based on the deployer

4. **Proxy Deployment**:
   - Encodes the initializer call (`initialize("MyToken", "MTK")`)
   - Deploys the TransparentUpgradeableProxy with:
     - Implementation address
     - ProxyAdmin address
     - Encoded initializer call

5. **Initialization**:
   - The proxy's constructor performs a delegatecall to the implementation with the initializer data
   - This sets up the initial state in the proxy's storage

## Detailed Upgrade Steps with OpenZeppelin Upgrades

When using OpenZeppelin's Upgrades plugin with `upgradeProxy`, these are the exact steps that occur:

```javascript
const MyTokenV2 = await ethers.getContractFactory("MyTokenV2");
await upgrades.upgradeProxy(proxyAddress, MyTokenV2);
```

1. **Validation**:
   - The plugin validates the new implementation is compatible with the previous one
   - Checks storage layout compatibility
   - Ensures no existing storage slots will be overwritten

2. **Implementation Deployment**:
   - Deploys the new implementation contract
   - Computes a deterministic address based on the bytecode
   - No constructor arguments are passed

3. **Proxy Update**:
   - Retrieves the ProxyAdmin contract
   - Calls `proxyAdmin.upgrade(proxy, newImplementation)`
   - Which calls `proxy.upgradeTo(newImplementation)`
   - This updates the implementation address in the proxy's storage

4. **No Reinitialization**:
   - The upgrade does not call any initializer
   - All existing state remains intact
   - New state variables get their default values

## Common Pitfalls and Security Considerations

### 1. Storage Layout Changes

Adding, removing, or reordering state variables in an upgrade can corrupt storage:

```solidity
// V1
contract MyTokenV1 {
    uint256 public value1;
    uint256 public value2;
}

// V2 - DANGEROUS! Reordering variables will corrupt storage
contract MyTokenV2 {
    uint256 public value2;
    uint256 public value1;
}
```

**What happens:** The values get swapped because storage slots are assigned by declaration order.

### 2. Variable Type Changes

Changing a variable's type can lead to misinterpretation of storage:

```solidity
// V1
contract MyTokenV1 {
    uint128 public value1;
    uint128 public value2;
}

// V2 - DANGEROUS! Changing types can corrupt storage
contract MyTokenV2 {
    uint256 public value1;
    // value2 is now part of value1's storage slot!
}
```

### 3. Initialization Issues

Forgetting to protect initializers can lead to reinitialization attacks:

```solidity
// VULNERABLE - Missing initializer modifier
function initialize(string memory name, string memory symbol) public {
    __ERC20_init(name, symbol);
    __Ownable_init();
}
```

**What happens:** An attacker could call initialize again and potentially reset critical state.

### 4. Function Selector Clashing

As mentioned earlier, the admin cannot call implementation functions directly through the proxy. This is a deliberate design choice to prevent function selector clashing.

## Researcher Notes: Attack Vectors & Security Considerations

### Core Mechanics

The Transparent Upgradeable Proxy pattern uses a caller-based dispatch mechanism:
- Calls from the admin address are processed by the proxy itself
- Calls from any other address are delegated to the implementation contract

This architecture solves the function selector clashing problem but introduces specific security considerations.

### Implementation Specifics

- Admin address stored as immutable in OpenZeppelin implementation
- ERC-1967 compliance requires redundant storage of admin in _ADMIN_SLOT
- ProxyAdmin pattern creates an intermediary contract that owns upgrade rights

### Deployment Process Security Aspects

The deployment process involves three main steps:
1. Implementation contract deployment (logic container)
2. ProxyAdmin contract deployment (upgrade manager)
3. TransparentUpgradeableProxy deployment with initialization

Critical security points during deployment:
- Initialization data could be front-run or manipulated
- Special storage slots must be properly set to prevent future collisions
- delegatecall during initialization executes in proxy's storage context

### Storage Layout Considerations

```
// Special storage slots (EIP-1967 standard)
slot 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103: ProxyAdmin address
slot 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc: Implementation address

// Implementation state variables begin at slot 0
```

### Execution Flow Security Implications

#### Case 1: Regular User Calls
1. Call arrives at proxy
2. Proxy checks if caller is admin (not in this case)
3. Proxy fallback triggers, performs delegatecall to implementation
4. Implementation function executes in proxy's storage context
5. Result returns to caller

#### Case 2: Admin Calls
1. Admin calls proxy function
2. Proxy executes its own function (no delegation)
3. No implementation code is executed

This dual behavior creates a security boundary but also introduces complexity.

### Upgrade Process Vectors

When upgrading a transparent proxy:
1. New implementation is deployed (uninitialized)
2. Proxy's implementation pointer is updated
3. No initialization is performed (state remains intact)
4. New variables get default values

Security considerations during upgrades:
- Only implementation address changes; all other state remains unchanged
- Storage layout compatibility is critical
- No automatic validation of new implementation safety

### Potential Attack Vectors

#### 1. Delegatecall Context Vulnerabilities

The proxy performs delegatecall to the implementation, executing implementation code in the proxy's storage context. This creates risk if:

- Implementation contains selfdestruct with insufficient access control
- Implementation manipulates ERC-1967 storage slots directly
- Implementation uses assembly to modify storage at predictable slots

#### 2. Admin-Related Vulnerabilities

- If an EOA is set as admin directly (bypassing ProxyAdmin), it cannot interact with implementation functions
- Compromised admin can set malicious implementation
- Admin cannot verify implementation behavior directly due to the transparent mechanism

#### 3. Storage Collision Risks

Despite using predefined storage slots for admin/implementation pointers:
- Implementation contracts using assembly could still manipulate these slots
- Hash collisions are theoretically possible but highly improbable

#### 4. Initialization Vulnerabilities

- No automatic protection against reinitialization if initializer modifier is omitted
- Uninitialized proxies can be front-run during deployment
- Initialization can be called with unexpected parameters during deployment

#### 5. Cross-Contract Interference

- Function selector clashing between different proxies sharing an implementation
- Proxies with the same implementation but different states could lead to logical inconsistencies
- Improper event emission in implementation could cause indexing confusion

#### 6. Upgrade Path Vulnerabilities

- Storage layout corruption during upgrades
- Lack of verification mechanisms for implementation compatibility
- No atomicity in multi-proxy upgrade scenarios

#### 7. Caller-Based Dispatch Limitations

The proxy's execution flow depends on the caller:
- The same function signature behaves differently based on caller
- Admin cannot call implementation functions directly through the proxy
- Potential for unexpected behavior when proxies are called by contracts rather than EOAs

#### 8. Storage Layout Corruption Risks

Adding, removing, or reordering state variables in upgrades can corrupt storage:
```solidity
// V1
contract MyTokenV1 {
    uint256 public value1;
    uint256 public value2;
}

// V2 - DANGEROUS! Reordering variables corrupts storage
contract MyTokenV2 {
    uint256 public value2;
    uint256 public value1;
}
```

#### 9. Variable Type Change Vulnerabilities

Changing variable types can lead to storage misinterpretation:
```solidity
// V1
contract MyTokenV1 {
    uint128 public value1;
    uint128 public value2;
}

// V2 - DANGEROUS! Type changes corrupt storage
contract MyTokenV2 {
    uint256 public value1; // now occupies full slot including value2
}
```

### Research Directions

1. **Storage Analysis**: Develop tools to verify storage layout compatibility between implementations

2. **Admin Management**: Investigate better patterns for admin management without sacrificing direct interface interaction

3. **Verification Techniques**: Create formal verification methods for proxy-implementation compatibility

4. **Cross-Chain Considerations**: Analyze behavior differences when transparent proxies are used in cross-chain environments

5. **Gas Optimization**: Storage slots and runtime checks introduce overhead; research more efficient patterns

6. **Formal Security Properties**: Define a complete set of security invariants that should hold for any proxy implementation

7. **Deterministic Deployment Analysis**: Study security implications of deterministic deployment addresses for proxies and implementations

8. **Storage Layout Verification**: Build automated tools to detect storage layout incompatibilities between versions

9. **Proxy Interaction Analysis**: Research tools to track proxy-to-proxy interactions and identify potential cascading failures

10. **Initialization Pattern Improvements**: Develop more robust initialization patterns that prevent reinitialization attacks

## References

- [EIP-1967: Proxy Storage Slots](https://eips.ethereum.org/EIPS/eip-1967)
- [OpenZeppelin Upgradeable Contracts](https://docs.openzeppelin.com/contracts/4.x/upgradeable)
- [OpenZeppelin TransparentUpgradeableProxy Implementation](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/transparent/TransparentUpgradeableProxy.sol)
- [OpenZeppelin ProxyAdmin Implementation](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/proxy/transparent/ProxyAdmin.sol)
