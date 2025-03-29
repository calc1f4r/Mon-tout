// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

/// @title MembershipERC1155Proxy
/// @notice Custom proxy contract for MembershipERC1155 that fixes the upgrade issue
contract MembershipERC1155Proxy is TransparentUpgradeableProxy {
    constructor(
        address _logic,
        address initialOwner,
        bytes memory _data
    ) TransparentUpgradeableProxy(_logic, initialOwner, _data) {}

    /// @notice Override _proxyAdmin to return the owner of the ProxyAdmin contract
    /// @return The address of the proxy admin owner
    function _proxyAdmin() internal view override returns (address) {
        return ProxyAdmin(super._proxyAdmin()).owner();
    }
} 