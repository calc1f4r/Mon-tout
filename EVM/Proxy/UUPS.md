# UUPS (Universal Upgradeable Proxy Standard) Security Checks

## Mandatory Security Checks

1. The `_authorizeUpgrade` function must be admin-protected:

```solidity
function _authorizeUpgrade(address _newImplementation) internal override onlyAdmin {}
```

2. Use initializers instead of constructors

   - Implementation contracts should use initializer functions instead of constructors
   - This ensures proper initialization when the contract is used behind a proxy

3. Prevent standalone initialization
   - Use `_disableInitializers()` in the constructor to prevent initialization if the contract is deployed standalone:

```solidity
constructor() {
    _disableInitializers();
}
```

4. Avoid custom upgrade implementations

   - Do not implement custom upgrade mechanisms
   - Rely on the standard OpenZeppelin UUPS implementation

5. Avoid delegatecall in implementation contracts

   - Implementation contracts should not use delegatecall
   - The proxy could execute a selfdestruct opcode through delegatecall

6. Be cautious with authorization changes during upgrades
   - When upgrading, carefully review changes to authorization schemas
   - Watch out for scenarios where admin privileges might have been renounced
   - Verify admin access is properly maintained across upgrades

## References

- [RareSkills - Understanding UUPS Proxies](https://www.rareskills.io/post/uups-proxy)
