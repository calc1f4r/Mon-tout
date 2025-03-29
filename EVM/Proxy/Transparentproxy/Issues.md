## Summary

The `MembershipERC1155` proxy contracts cannot be upgraded due to incorrect proxy admin setup in the `MembershipFactory` contract. This is a critical vulnerability as it prevents DAO membership contracts from being upgraded to fix bugs or add new features.

## Vulnerability Details

### Background

The system uses OpenZeppelin's `TransparentUpgradeableProxy` pattern for the `MembershipERC1155` contracts. This pattern involves:

1. A proxy contract that delegates calls to an implementation
2. A `ProxyAdmin` contract that manages upgrades
3. An implementation contract containing the actual logic

### Root Cause

The vulnerability stems from how the proxy admin is set up in `MembershipFactory.sol`:

```solidity
// MembershipFactory.sol
constructor(address _currencyManager, address _owpWallet, string memory _baseURI, address _membershipImplementation) {
    // ...
    proxyAdmin = new ProxyAdmin(msg.sender);
    // ...
}

function createNewDAOMembership(DAOInputConfig calldata daoConfig, TierConfig[] calldata tierConfigs) external returns (address) {
    // ...
    TransparentUpgradeableProxy proxy = new TransparentUpgradeableProxy(
        membershipImplementation,
        address(proxyAdmin),  // This is the critical issue
        abi.encodeWithSignature("initialize(...)")
    );
    // ...
}
```

The issue arises from a fundamental misunderstanding of how `TransparentUpgradeableProxy` works:

1. When a `TransparentUpgradeableProxy` is created, it creates its own `ProxyAdmin` instance internally
2. The `admin` parameter passed to the constructor is used as the owner of this new `ProxyAdmin`
3. This means each proxy has its own separate `ProxyAdmin` instance

### Attack Flow

1. `MembershipFactory` creates a new `ProxyAdmin` instance in its constructor
2. When creating a new DAO membership:
   - A new `TransparentUpgradeableProxy` is created
   - The factory's `proxyAdmin` address is passed as the admin parameter
   - The proxy creates its own `ProxyAdmin` instance internally
   - The factory's `proxyAdmin` becomes the owner of this new `ProxyAdmin`

3. When attempting to upgrade:
   ```solidity
   // This call will fail
   proxyAdmin.upgradeAndCall(proxy, newImplementation, data);
   ```
   - The call is forwarded to the proxy's `_fallback()` function
   - The proxy checks if the caller is its admin (the internal `ProxyAdmin`)
   - Since the factory's `proxyAdmin` is not the proxy's admin, the call reverts

### Technical Analysis

The key to understanding this vulnerability is in the `TransparentUpgradeableProxy` contract:

```solidity
// TransparentUpgradeableProxy.sol
constructor(address _logic, address initialOwner, bytes memory _data) payable ERC1967Proxy(_logic, _data) {
    _admin = address(new ProxyAdmin(initialOwner));  // Creates new ProxyAdmin
    ERC1967Utils.changeAdmin(_proxyAdmin());
}

function _fallback() internal virtual override {
    if (msg.sender == _proxyAdmin()) {  // Checks against internal admin
        if (msg.sig != ITransparentUpgradeableProxy.upgradeToAndCall.selector) {
            revert ProxyDeniedAdminAccess();
        } else {
            _dispatchUpgradeToAndCall();
        }
    } else {
        super._fallback();
    }
}
```

The upgrade flow should be:
```
Factory's ProxyAdmin -> Proxy's ProxyAdmin -> Proxy
```

But due to the incorrect setup, it becomes:
```
Factory's ProxyAdmin -> Proxy (reverts)
```

## Impact

Critical. The inability to upgrade proxy contracts means:

1. Bugs cannot be fixed
2. New features cannot be added
3. Security patches cannot be applied
4. The DAO membership contracts are permanently locked to their initial implementation

## Proof of Concept

```solidity
// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

import {Test} from "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../contracts/dao/MembershipFactory.sol";
import "../contracts/dao/CurrencyManager.sol";
import "../contracts/dao/tokens/MembershipERC1155.sol";
import {DAOType, DAOConfig, DAOInputConfig, TierConfig} from "../contracts/dao/libraries/MembershipDAOStructs.sol";

contract Audit is Test {
    address admin = makeAddr("Admin");
    address owpWallet = makeAddr("owpWallet");

    ERC20 WETH = new MockERC20("Wrapped ETH", "WETH", 18);
    ERC20 WBTC = new MockERC20("Wrapped BTC", "WBTC", 8);
    ERC20 USDC = new MockERC20("USDC", "USDC", 6);

    MembershipFactory membershipFactory;
    CurrencyManager currencyManager;
    
    function setUp() public {
        vm.startPrank(admin);

        // Deploy CurrencyManager
        currencyManager = new CurrencyManager();
        currencyManager.addCurrency(address(WETH));
        currencyManager.addCurrency(address(WBTC));
        currencyManager.addCurrency(address(USDC));

        // Deploy MembershipERC1155
        MembershipERC1155 membershipERC1155Implementation = new MembershipERC1155();

        // Deploy MembershipFactory
        membershipFactory = new MembershipFactory(
            address(currencyManager), 
            owpWallet, 
            "https://baseuri.com/", 
            address(membershipERC1155Implementation)
        );

        vm.stopPrank();
    }

    function testAudit_upgradeProxy() public {
        // Create DAO
        address creator = makeAddr("Creator");
        DAOInputConfig memory daoInputConfig = DAOInputConfig({
            ensname: "SPONSORED DAO",
            daoType: DAOType.SPONSORED,
            currency: address(USDC),
            maxMembers: 127,
            noOfTiers: 7
        });

        vm.startPrank(creator);
        address daoMemebershipProxy = membershipFactory.createNewDAOMembership(
            daoInputConfig, 
            createTierConfigs(
                daoInputConfig.noOfTiers, 
                ERC20(daoInputConfig.currency).decimals()
            )
        );
        vm.stopPrank();

        // Deploy new MembershipERC1155 implementation
        MembershipERC1155v2 membershipERC1155v2Implementation = new MembershipERC1155v2();

        vm.startPrank(admin);
        membershipFactory.updateMembershipImplementation(address(membershipERC1155v2Implementation));
        ProxyAdmin proxyAdmin = membershipFactory.proxyAdmin();
        // Upgrade MembershipERC1155 will revert
        vm.expectRevert();
        proxyAdmin.upgradeAndCall(ITransparentUpgradeableProxy(daoMemebershipProxy), address(membershipERC1155v2Implementation), "");
        vm.stopPrank();
    }

    function createTierConfigs(uint noOfTiers, uint8 decimals) private returns (TierConfig[] memory tiers) {
        tiers = new TierConfig[](noOfTiers);

        uint price = 1 * 10 ** decimals;
        uint power = 1;
        for (int i = int(noOfTiers) - 1; i >= 0; --i) {
            uint index = uint(i);
            tiers[index] = TierConfig({
                amount: 2 ** index,
                price: price,
                power: power,
                minted: 0
            });

            price *= 2;
            power *= 2;
        }
    }
}

contract MockERC20 is ERC20 {
    uint8 _decimals;

    constructor(
        string memory name_, 
        string memory symbol_, 
        uint8 decimals_
    ) ERC20(name_, symbol_) {
        _decimals = decimals_;
    }

    function decimals() public view override returns (uint8) {
        return _decimals;
    }
}

contract MembershipERC1155v2 is MembershipERC1155 {}
```

## Tools Used

- Manual Review
- Foundry for PoC
- OpenZeppelin Contracts Documentation

## Recommendations

There are two main approaches to fix this vulnerability:

### Option 1: Use EOA/Multisig as Admin

The simplest solution is to use an EOA or multisig wallet as the admin instead of a `ProxyAdmin` instance:

```solidity
// MembershipFactory.sol
constructor(address _currencyManager, address _owpWallet, string memory _baseURI, address _membershipImplementation) {
    // ...
    // Use EOA/multisig instead of ProxyAdmin
    admin = msg.sender;
    // ...
}
```

Then the admin can directly interact with each proxy's internal `ProxyAdmin` to perform upgrades.

### Option 2: Custom Proxy Contract

Create a custom proxy contract that overrides the admin logic:

```solidity
contract MembershipERC1155Proxy is TransparentUpgradeableProxy {
    constructor(
        address _logic, 
        address initialOwner, 
        bytes memory _data
    ) TransparentUpgradeableProxy(_logic, initialOwner, _data) {}

    function _proxyAdmin() internal view override returns (address) {
        return ProxyAdmin(super._proxyAdmin()).owner();
    }
}
```

Then update the factory to use this proxy:

```solidity
// MembershipFactory.sol
function createNewDAOMembership(...) external returns (address) {
    // ...
    MembershipERC1155Proxy proxy = new MembershipERC1155Proxy(
        membershipImplementation,
        address(proxyAdmin),
        abi.encodeWithSignature("initialize(...)")
    );
    // ...
}
```

This ensures the factory's `ProxyAdmin` can properly manage all proxies.

## References

- [OpenZeppelin TransparentUpgradeableProxy Documentation](https://docs.openzeppelin.com/contracts/4.x/api/proxy#TransparentUpgradeableProxy)
- [OpenZeppelin ProxyAdmin Documentation](https://docs.openzeppelin.com/contracts/4.x/api/proxy#ProxyAdmin)

## Security Researcher Checklist

When auditing contracts using OpenZeppelin's `TransparentUpgradeableProxy`, check for the following:

### 1. Proxy Admin Setup
- [ ] Verify if the contract creates a `ProxyAdmin` instance in its constructor
- [ ] Check if the `ProxyAdmin` address is passed to proxy constructors
- [ ] Look for factory contracts that create multiple proxies

### 2. Proxy Creation
- [ ] Review how proxies are created in factory contracts
- [ ] Check if the same `ProxyAdmin` instance is used for all proxies
- [ ] Verify the admin parameter passed to proxy constructors

### 3. Upgrade Mechanism
- [ ] Check if upgrade functions are implemented
- [ ] Verify if upgrade calls are made through the correct admin
- [ ] Look for upgrade-related functions in factory contracts

### 4. Common Red Flags
- [ ] Factory contract creating its own `ProxyAdmin` instance
- [ ] Same `ProxyAdmin` address being passed to multiple proxies
- [ ] Upgrade functions that don't check admin ownership
- [ ] Missing or incorrect admin checks in proxy contracts

### 5. Testing
- [ ] Verify upgrade functionality in test cases
- [ ] Check if upgrade calls are properly tested
- [ ] Look for test coverage of admin-related functions

### 6. Documentation
- [ ] Review proxy upgrade documentation
- [ ] Check for comments explaining admin setup
- [ ] Look for upgrade-related documentation

### 7. Related Contracts
- [ ] Review all contracts that interact with proxies
- [ ] Check for admin-related functions in other contracts
- [ ] Look for proxy management patterns

### 8. Impact Assessment
- [ ] Evaluate the impact of non-upgradeable proxies
- [ ] Check if critical functionality depends on upgrades
- [ ] Assess the scope of affected contracts

### 9. Mitigation Verification
- [ ] Check if proper admin setup is implemented
- [ ] Verify upgrade mechanisms are correctly implemented
- [ ] Look for proper access controls on upgrade functions

### 10. Additional Considerations
- [ ] Review proxy initialization logic
- [ ] Check for proxy admin ownership transfers
- [ ] Look for proxy admin access controls
- [ ] Verify proxy admin initialization parameters
