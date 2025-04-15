# Access Control Upgradable Notes

1. When a contract is using AccessControlUpgradable and some pattern like this one is used:

```solidity
_grantRole(DEFAULT_ADMIN_ROLE, admin);
_grantRole(MANAGER_ROLE, manager);
_grantRole(ORACLE_MANAGER_ROLE, _oracle);
```

A Auditor may be concerned what if the manager role renounces its role. The important thing to understand is that the user address with `DEFAULT_ADMIN_ROLE` has the power to set it to another address, so there is no issue with that. 

It an issue when there is no user set with DEFAULT_ADMIN_ROLE!!