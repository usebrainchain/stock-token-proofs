// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Fixture} from "../Fixture.sol";
import {
    DEFAULT_ADMIN_ROLE,
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

contract DeploymentTest is Fixture {
    function setUp() public {
        _deploy();
    }

    function test_topology() public view {
        assertEq(registry.implementation(), address(impl));
        assertEq(impl.ACCESS_CONTROLLED_REGISTRY(), address(registry));
        assertEq(token.ACCESS_CONTROLLED_REGISTRY(), address(registry));
        assertEq(address(uint160(uint256(vm.load(address(token), BEACON_SLOT)))), address(registry));
        assertEq(token.name(), NAME);
        assertEq(token.symbol(), SYMBOL);
        assertEq(token.uid(), UID);
        assertEq(token.decimals(), 18);
        assertEq(token.totalSupply(), 0);
        assertEq(token.uiMultiplier(), 1e18);
        assertFalse(token.paused());
    }

    function test_rolesHeldByDistinctAddresses() public view {
        bytes32[11] memory roles = [
            DEFAULT_ADMIN_ROLE,
            BEACON_UPGRADER_ROLE,
            MINTER_ROLE,
            BURNER_ROLE,
            ADMIN_BURNER_ROLE,
            TOKEN_PAUSER_ROLE,
            PAUSER_ROLE,
            MULTIPLIER_UPDATER_ROLE,
            ORACLE_PAUSER_ROLE,
            METADATA_UPDATER_ROLE,
            BLOCKER_ROLE
        ];
        address[11] memory holders = _roleHolders();
        for (uint256 i; i < roles.length; ++i) {
            for (uint256 j; j < holders.length; ++j) {
                assertEq(registry.hasRole(roles[i], holders[j]), i == j);
            }
        }
    }

    function test_namespacedSlotsMatchErc7201() public pure {
        assertEq(INITIALIZABLE_SLOT, _erc7201("openzeppelin.storage.Initializable"));
        assertEq(ERC20_SLOT, _erc7201("openzeppelin.storage.ERC20"));
        assertEq(SCALED_SLOT, _erc7201("robinhood.storage.ERC20Rebase"));
        assertEq(STOCK_SLOT, _erc7201("robinhood.storage.Stock"));
        assertEq(ORACLE_SLOT, _erc7201("robinhood.storage.OraclePausable"));
        assertEq(BEACON_SLOT, bytes32(uint256(keccak256("eip1967.proxy.beacon")) - 1));
    }

    function test_setMetadataWritesTheErc20Slot() public {
        vm.prank(METADATA_UPDATER);
        token.setMetadata("NVIDIA Corp", "NVDA2");
        assertEq(token.name(), "NVIDIA Corp");
        assertEq(token.symbol(), "NVDA2");
    }

    function _erc7201(string memory id) private pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(bytes(id))) - 1)) & ~bytes32(uint256(0xff));
    }
}
