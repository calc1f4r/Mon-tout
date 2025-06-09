# UUPS (Universal Upgradeable Proxy Standard) Best Practices

## 1. Initializer Implementation

### Missing `_disableInitializers()` in the constructor
Always call `_disableInitializers()` in the constructor of implementation contracts to prevent them from being initialized directly:

```solidity
constructor() {
    _disableInitializers();
}
```

### Correct usage of modifiers
- Use the `initializer` modifier on the initialization function to prevent re-initialization
- Use the `onlyInitializing` modifier on functions that should only be called during initialization

```solidity
function initialize(address admin) public initializer {
    __Ownable_init();
    _transferOwnership(admin);
    _setupRole();
}

function _setupRole() internal onlyInitializing {
    // Setup logic that should only run during initialization
}
```

## 2. Storage Management

### Use storage gaps to prevent collisions
Ensure storage gaps are correctly defined to prevent storage collisions in future upgrades. This is crucial for maintaining the integrity of the contract's state across upgrades.
A standard 50 gaps is recommended, but you can adjust based on your contract's needs.

#### Dangerous Layout (Don't Do This)
```solidity
// V1 Layout
uint256 var1;  // Slot 0
uint256 var2;  // Slot 1

// V2 Layout (DANGER)
uint256 var3;  // Slot 0  → Collides with var1!
uint256 var1;  // Slot 1  → Collides with var2!
```

#### Safe Layout (Recommended)
```solidity
// V1
uint256 var1;
uint256[49] __gap; // Reserves 49 slots

// V2
uint256 var1;
uint256 var2; // Uses slot 1 (safe)
uint256[48] __gap; // Adjust gap size
```

## 3. Upgrade Security

### Implement proper access control
Ensure that the `upgradeTo` and `upgradeToAndCall` functions are properly secured with access control mechanisms like `onlyOwner` or a specific role.

### Validate the new implementation
Consider implementing a validation mechanism to ensure the new implementation is compatible with the current one:

```solidity
function _authorizeUpgrade(address newImplementation) internal override onlyOwner {
    // Optional: Add custom validation logic here
    require(IMyInterface(newImplementation).version() > version(), "New implementation must have higher version");
}
```


```bash
  * @dev Function that should revert when `msg.sender` is not authorized to upgrade the contract. Called by
     * {upgradeToAndCall}.
     *
     * Normally, this function will use an xref:access.adoc[access control] modifier such as {Ownable-onlyOwner}.
     *
     * ```solidity
     * function _authorizeUpgrade(address) internal onlyOwner {}
     * ```
```
https://github.com/OpenZeppelin/openzeppelin-contracts/blob/13d9086d0b55229ca1b9d5f4c158b0ba75682b5c/contracts/proxy/utils/UUPSUpgradeable.sol#L125

> Openzepplin says you must always protect this function with `onlyOwner` or a specific role to prevent unauthorized upgrades.


## 4 . do not count the constants as storage variables
When defining constants in your contract, do not count them as storage variables. Constants are not stored in the contract's storage and do not consume gas when accessed.

```solidity
uint256 public constant MAX_SUPPLY = 10000; // This is a constant, not a storage variable
```

## 5. Function Clashing
Function clashing occurs when a function in the proxy contract has the same signature as a function in the implementation contract. This can lead to unexpected behavior, as calls to the proxy might inadvertently execute proxy logic instead of delegating to the implementation.

**Example:**
If the proxy has an `owner()` function and the implementation also has an `owner()` function with the same signature, calls to `owner()` on the proxy will execute the proxy's `owner()` function, not the one in the implementation.

**Prevention:**
- **Namespacing:** Prefix proxy-specific functions (e.g., `proxyOwner()`, `adminUpgradeTo()`) to avoid clashes with implementation functions.
- **Careful Naming:** Be mindful of common function names (e.g., `owner`, `version`, `name`) and ensure they don't unintentionally clash.
- **Transparent Proxies:** While UUPS is different, Transparent Proxies solve this by having admin functions callable only by an admin account, and user functions callable only by non-admin accounts, thus preventing clashes based on `msg.sender`. UUPS proxies do not have this built-in separation, so careful design is crucial.

## 6. Delegatecall Vulnerabilities
`delegatecall` is fundamental to how proxies work, but it can introduce vulnerabilities if not handled carefully. The core idea is that the implementation contract's code executes in the context of the proxy's storage, `msg.sender`, and `msg.value`.

**Key Considerations:**
- **Storage Layout:** As discussed in "Storage Management," the storage layout of the implementation contract must be compatible with the proxy's storage to avoid overwriting or misinterpreting data.
- **`selfdestruct` Opcode:** If an implementation contract can call `selfdestruct`, it will destroy the proxy contract, not just the implementation. This is a critical vulnerability. Ensure implementation contracts cannot be self-destructed or that such functionality is heavily restricted.
- **Initialization:** Ensure the implementation contract's initialization function (e.g., `initialize`) can only be called once and is protected. If it can be re-initialized, an attacker might be able to take control of the proxy.
- **Unintended State Changes:** Be aware that any state-changing operation in the implementation contract directly affects the proxy's state. Thoroughly audit implementation contracts for any functions that could lead to unintended state changes in the proxy.

**Example of `selfdestruct` risk:**
```solidity
// Implementation Contract - Vulnerable
contract ImplementationV1 {
    address public owner;
    // ... other state variables

    function initialize() public {
        owner = msg.sender;
    }

    // Malicious or accidental function
    function destroy() public {
        require(msg.sender == owner, "Only owner");
        selfdestruct(payable(owner)); // This will destroy the PROXY contract
    }
}
```
If `destroy()` is called on this implementation through the proxy, the proxy itself will be destroyed.

