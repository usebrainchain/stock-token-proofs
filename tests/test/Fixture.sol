// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {Stock} from "stock/Stock.sol";
import {AccessControlsRegistry} from "registry/AccessControlsRegistry.sol";
import {BeaconProxy} from "oz-proxy/proxy/beacon/BeaconProxy.sol";
import {
    MINTER_ROLE,
    BURNER_ROLE,
    PAUSER_ROLE,
    BEACON_UPGRADER_ROLE,
    MULTIPLIER_UPDATER_ROLE,
    METADATA_UPDATER_ROLE,
    BLOCKER_ROLE,
    ADMIN_BURNER_ROLE,
    TOKEN_PAUSER_ROLE,
    ORACLE_PAUSER_ROLE
} from "stock/Roles.sol";

/// Production topology: one AccessControlsRegistry that is both the role/blocklist/pause authority and the
/// beacon, one Stock implementation built against it, and a token that is a BeaconProxy initialised in its
/// constructor. Every role sits with its own address; the deployer keeps only DEFAULT_ADMIN_ROLE.
abstract contract Fixture is Test {
    bytes32 internal constant UID = keccak256("NVDA");
    string internal constant NAME = "NVIDIA";
    string internal constant SYMBOL = "NVDA";

    bytes32 internal constant BEACON_SLOT = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
    bytes32 internal constant INITIALIZABLE_SLOT = 0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00;
    bytes32 internal constant ERC20_SLOT = 0x52c63247e1f47db19d5ce0460030c497f067ca4cebf71ba98eeadabe20bace00;
    bytes32 internal constant SCALED_SLOT = 0x395525728d1d6f4af44d273368682dd92b28e7464d750ef3212d3cb7f5959d00;
    bytes32 internal constant STOCK_SLOT = 0x8d25ea8ee309999a79f0af498fbab0e424669497170669bd9e93b81a62babc00;
    bytes32 internal constant ORACLE_SLOT = 0x50204cc2d5276a366b2f6a19361d0f388c29e773a6f6aa2c92cfb0dc04a5fe00;

    address internal constant ADMIN = address(0xA0);
    address internal constant UPGRADER = address(0xA1);
    address internal constant MINTER = address(0xA2);
    address internal constant BURNER = address(0xA3);
    address internal constant ADMIN_BURNER = address(0xA4);
    address internal constant TOKEN_PAUSER = address(0xA5);
    address internal constant REGISTRY_PAUSER = address(0xA6);
    address internal constant MULTIPLIER_UPDATER = address(0xA7);
    address internal constant ORACLE_PAUSER = address(0xA8);
    address internal constant METADATA_UPDATER = address(0xA9);
    address internal constant BLOCKER = address(0xAA);

    AccessControlsRegistry internal registry;
    Stock internal impl;
    Stock internal token;

    function _deploy() internal {
        vm.startPrank(ADMIN);
        registry = new AccessControlsRegistry();
        registry.grantRole(BEACON_UPGRADER_ROLE, UPGRADER);
        registry.revokeRole(BEACON_UPGRADER_ROLE, ADMIN);
        registry.grantRole(MINTER_ROLE, MINTER);
        registry.grantRole(BURNER_ROLE, BURNER);
        registry.grantRole(ADMIN_BURNER_ROLE, ADMIN_BURNER);
        registry.grantRole(TOKEN_PAUSER_ROLE, TOKEN_PAUSER);
        registry.grantRole(PAUSER_ROLE, REGISTRY_PAUSER);
        registry.grantRole(MULTIPLIER_UPDATER_ROLE, MULTIPLIER_UPDATER);
        registry.grantRole(ORACLE_PAUSER_ROLE, ORACLE_PAUSER);
        registry.grantRole(METADATA_UPDATER_ROLE, METADATA_UPDATER);
        registry.grantRole(BLOCKER_ROLE, BLOCKER);
        vm.stopPrank();

        impl = new Stock(address(registry));
        vm.prank(UPGRADER);
        registry.upgradeTo(address(impl));

        token = Stock(address(new BeaconProxy(address(registry), abi.encodeCall(Stock.initialize, (UID, NAME, SYMBOL)))));
    }

    function _roleHolders() internal pure returns (address[11] memory) {
        return [
            ADMIN,
            UPGRADER,
            MINTER,
            BURNER,
            ADMIN_BURNER,
            TOKEN_PAUSER,
            REGISTRY_PAUSER,
            MULTIPLIER_UPDATER,
            ORACLE_PAUSER,
            METADATA_UPDATER,
            BLOCKER
        ];
    }

    function _isRoleHolder(address a) internal pure returns (bool) {
        address[11] memory holders = _roleHolders();
        for (uint256 i; i < holders.length; ++i) {
            if (holders[i] == a) return true;
        }
        return false;
    }

    function _block(address a) internal {
        address[] memory list = new address[](1);
        list[0] = a;
        vm.prank(BLOCKER);
        registry.blockAccounts(list);
    }

    function _unblock(address a) internal {
        address[] memory list = new address[](1);
        list[0] = a;
        vm.prank(BLOCKER);
        registry.unblockAccounts(list);
    }

    function _mint(address to, uint256 amount) internal {
        vm.prank(MINTER);
        token.mint(to, amount);
    }

    function _pauseToken() internal {
        vm.prank(TOKEN_PAUSER);
        token.pause();
    }

    function _pauseRegistry() internal {
        vm.prank(REGISTRY_PAUSER);
        registry.pause();
    }
}
