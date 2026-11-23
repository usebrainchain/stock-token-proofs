// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Fixture} from "../Fixture.sol";
import {Stock} from "stock/Stock.sol";
import {AccessControlled} from "stock/AccessControlled.sol";
import {
    MINTER_ROLE,
    BURNER_ROLE,
    ADMIN_BURNER_ROLE,
    TOKEN_PAUSER_ROLE,
    MULTIPLIER_UPDATER_ROLE,
    ORACLE_PAUSER_ROLE,
    METADATA_UPDATER_ROLE
} from "stock/Roles.sol";

/// Drives the deployed system with every user-facing and role-gated action and keeps an independent model of
/// what the statements say each call must do. Each call's outcome is compared with the model:
/// a success the statements forbid, or a revert they do not explain, is counted against the property it breaks.
contract Handler is Fixture {
    uint256 internal constant USERS = 5;
    uint256 internal constant MAX_AMOUNT = 1e30;
    uint256 internal constant MAX_MULTIPLIER = 1e24;
    bytes32 internal constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    uint256 internal constant P1 = 1 << 1;
    uint256 internal constant P2 = 1 << 2;
    uint256 internal constant P3 = 1 << 3;
    uint256 internal constant P4 = 1 << 4;
    uint256 internal constant P5 = 1 << 5;
    uint256 internal constant P6 = 1 << 6;
    uint256 internal constant P7 = 1 << 7;

    address[USERS] public users;
    uint256[USERS] internal keys;

    mapping(address => uint256) public modelBalance;
    mapping(address => mapping(address => uint256)) public modelAllowance;
    mapping(address => uint256) public modelNonce;
    mapping(address => bool) public modelBlocked;
    mapping(address => uint256) public balanceAtBlock;
    mapping(address => uint256) public adminBurnedSinceBlock;
    bool public modelTokenPaused;
    bool public modelRegistryPaused;
    uint256 public minted;
    uint256 public burned;
    uint256 public adminBurned;

    uint256 public modelPrevMultiplier = 1e18;
    uint256 public modelNewMultiplier;
    uint256 public modelEffectiveAt;

    bool public multiplierMovedRawState;
    mapping(uint256 => uint256) public violations;
    mapping(bytes32 => uint256) public calls;
    uint256 public succeeded;
    bytes4 internal lastRevert;

    constructor() {
        _deploy();
        for (uint256 i; i < USERS; ++i) {
            keys[i] = 0x1000 + i;
            users[i] = vm.addr(keys[i]);
        }
    }

    function system() external view returns (Stock, Stock, address) {
        return (token, impl, address(registry));
    }

    function modelUiMultiplier() public view returns (uint256) {
        if (modelNewMultiplier != 0 && block.timestamp >= modelEffectiveAt) return modelNewMultiplier;
        return modelPrevMultiplier;
    }

    function modelPaused() public view returns (bool) {
        return modelTokenPaused || modelRegistryPaused;
    }

    /// The fuzzer favours edge values; hashing spreads the toggles to a one-in-four chance of switching on.
    function _quarter(uint8 mode) internal pure returns (bool) {
        return uint256(keccak256(abi.encode(mode))) % 4 == 0;
    }

    function _user(uint256 seed) internal view returns (address) {
        return users[seed % USERS];
    }

    function _target(uint256 seed) internal view returns (address) {
        return seed % 16 == 15 ? address(0) : users[seed % USERS];
    }

    function _call(address caller, bytes memory data) internal returns (bool ok) {
        bytes memory ret;
        vm.prank(caller);
        (ok, ret) = address(token).call(data);
        lastRevert = ok || ret.length < 4 ? bytes4(0) : bytes4(ret);
    }

    /// A refused role holder breaks P5 whatever the call; any other unexplained revert breaks `livenessProperty`.
    function _judge(bool ok, uint256 reasons, uint256 livenessProperty) internal {
        if (ok) {
            ++succeeded;
            for (uint256 p = 1; p <= 7; ++p) {
                if (reasons & (1 << p) != 0) ++violations[p];
            }
        } else if (reasons == 0) {
            bool refused = lastRevert == AccessControlled.AccessControlUnauthorizedAccount.selector;
            ++violations[refused ? 5 : livenessProperty];
        }
    }

    function _pausedReason() internal view returns (uint256) {
        return modelPaused() ? P3 : 0;
    }

    function _blockedReason(address a) internal view returns (uint256) {
        return modelBlocked[a] ? P2 : 0;
    }

    function _move(address from, address to, uint256 value) internal {
        modelBalance[from] -= value;
        modelBalance[to] += value;
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 value) external {
        address from = _user(fromSeed);
        address to = _target(toSeed);
        value = bound(value, 0, modelBalance[from] + 1);
        uint256 reasons = _pausedReason() | _blockedReason(from) | _blockedReason(to);
        if (to == address(0) || value > modelBalance[from]) reasons |= P7;
        bool ok = _call(from, abi.encodeCall(Stock.transfer, (to, value)));
        _judge(ok, reasons, 7);
        if (ok) _move(from, to, value);
        ++calls["transfer"];
    }

    function transferFrom(uint256 spenderSeed, uint256 fromSeed, uint256 toSeed, uint256 value) external {
        address spender = _user(spenderSeed);
        address from = _user(fromSeed);
        address to = _target(toSeed);
        value = bound(value, 0, modelBalance[from] + 1);
        uint256 current = modelAllowance[from][spender];
        uint256 reasons = _pausedReason() | _blockedReason(from) | _blockedReason(to) | _blockedReason(spender);
        if (to == address(0) || value > modelBalance[from] || value > current) reasons |= P7;
        bool ok = _call(spender, abi.encodeCall(Stock.transferFrom, (from, to, value)));
        _judge(ok, reasons, 7);
        if (ok) {
            _move(from, to, value);
            if (current != type(uint256).max) modelAllowance[from][spender] = current - value;
        }
        ++calls["transferFrom"];
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 value, bool infinite) external {
        address owner = _user(ownerSeed);
        address spender = _target(spenderSeed);
        value = infinite ? type(uint256).max : bound(value, 0, MAX_AMOUNT);
        uint256 reasons = _pausedReason() | _blockedReason(owner) | _blockedReason(spender);
        if (spender == address(0)) reasons |= P7;
        bool ok = _call(owner, abi.encodeCall(Stock.approve, (spender, value)));
        _judge(ok, reasons, 7);
        if (ok) modelAllowance[owner][spender] = value;
        ++calls["approve"];
    }

    function permit(uint256 ownerSeed, uint256 spenderSeed, uint256 relayerSeed, uint256 value) external {
        uint256 key = keys[ownerSeed % USERS];
        address owner = vm.addr(key);
        address spender = _user(spenderSeed);
        address relayer = _user(relayerSeed);
        value = bound(value, 0, MAX_AMOUNT);
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                token.DOMAIN_SEPARATOR(),
                keccak256(abi.encode(PERMIT_TYPEHASH, owner, spender, value, modelNonce[owner], block.timestamp))
            )
        );
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(key, digest);
        uint256 reasons = _pausedReason() | _blockedReason(owner) | _blockedReason(spender) | _blockedReason(relayer);
        bool ok = _call(relayer, abi.encodeCall(Stock.permit, (owner, spender, value, block.timestamp, v, r, s)));
        _judge(ok, reasons, 7);
        if (ok) {
            modelAllowance[owner][spender] = value;
            ++modelNonce[owner];
        }
        ++calls["permit"];
    }

    function mint(uint256 toSeed, uint256 amount) external {
        address to = _target(toSeed);
        amount = bound(amount, 0, MAX_AMOUNT);
        uint256 reasons = _pausedReason() | _blockedReason(to) | _blockedReason(MINTER);
        if (to == address(0)) reasons |= P1;
        bool ok = _call(MINTER, abi.encodeCall(Stock.mint, (to, amount)));
        _judge(ok, reasons, 1);
        if (ok) {
            modelBalance[to] += amount;
            minted += amount;
        }
        ++calls["mint"];
    }

    function burn(uint256 fromSeed, uint256 amount) external {
        address from = _user(fromSeed);
        amount = bound(amount, 0, modelBalance[from] + 1);
        uint256 reasons = _pausedReason() | _blockedReason(from) | _blockedReason(BURNER);
        if (amount > modelBalance[from]) reasons |= P1;
        bool ok = _call(BURNER, abi.encodeCall(Stock.burn, (from, amount)));
        _judge(ok, reasons, 1);
        if (ok) {
            modelBalance[from] -= amount;
            burned += amount;
        }
        ++calls["burn"];
    }

    function adminBurn(uint256 fromSeed, uint256 amount) external {
        address from = _user(fromSeed);
        amount = bound(amount, 0, modelBalance[from] + 1);
        uint256 reasons = amount > modelBalance[from] ? P1 : 0;
        uint256 liveness = modelPaused() ? 3 : (modelBlocked[from] || modelBlocked[ADMIN_BURNER]) ? 2 : 1;
        bool ok = _call(ADMIN_BURNER, abi.encodeCall(Stock.adminBurn, (from, amount)));
        _judge(ok, reasons, liveness);
        if (ok) {
            modelBalance[from] -= amount;
            adminBurned += amount;
            if (modelBlocked[from]) adminBurnedSinceBlock[from] += amount;
        }
        ++calls["adminBurn"];
    }

    function updateMultiplier(uint256 m, int256 offset, bool immediate) external {
        m = bound(m, 0, MAX_MULTIPLIER);
        offset = bound(offset, -1 days, 30 days);
        uint256 at = immediate ? block.timestamp : uint256(int256(block.timestamp) + offset);
        uint256 reasons = _pausedReason();
        if (m == 0 || at < block.timestamp) reasons |= P4;
        uint256[USERS] memory before;
        for (uint256 i; i < USERS; ++i) {
            before[i] = token.balanceOf(users[i]);
        }
        uint256 supplyBefore = token.totalSupply();
        bytes memory data = immediate
            ? abi.encodeWithSignature("updateMultiplier(uint256)", m)
            : abi.encodeWithSignature("updateMultiplier(uint256,uint256)", m, at);
        bool ok = _call(MULTIPLIER_UPDATER, data);
        _judge(ok, reasons, 4);
        for (uint256 i; i < USERS; ++i) {
            if (token.balanceOf(users[i]) != before[i]) multiplierMovedRawState = true;
        }
        if (token.totalSupply() != supplyBefore) multiplierMovedRawState = true;
        if (ok) {
            modelPrevMultiplier = modelUiMultiplier();
            modelNewMultiplier = m;
            modelEffectiveAt = at;
        }
        ++calls["updateMultiplier"];
    }

    function setBlocked(uint256 seed, uint8 mode) external {
        bool blocked = _quarter(mode);
        address[USERS + 3] memory candidates =
            [users[0], users[1], users[2], users[3], users[4], MINTER, BURNER, ADMIN_BURNER];
        address a = candidates[seed % candidates.length];
        if (blocked) {
            if (!modelBlocked[a]) {
                balanceAtBlock[a] = modelBalance[a];
                adminBurnedSinceBlock[a] = 0;
            }
            _block(a);
        } else {
            _unblock(a);
        }
        modelBlocked[a] = blocked;
        ++calls["setBlocked"];
    }

    function setTokenPaused(uint8 mode) external {
        bool paused = _quarter(mode);
        vm.prank(TOKEN_PAUSER);
        (bool ok,) = address(token).call(abi.encodeWithSignature(paused ? "pause()" : "unpause()"));
        _judge(ok, 0, 5);
        if (ok) modelTokenPaused = paused;
        ++calls["setTokenPaused"];
    }

    function setRegistryPaused(uint8 mode) external {
        bool paused = _quarter(mode);
        vm.prank(REGISTRY_PAUSER);
        (bool ok,) = address(registry).call(abi.encodeWithSignature(paused ? "pause()" : "unpause()"));
        _judge(ok, 0, 5);
        if (ok) modelRegistryPaused = paused;
        ++calls["setRegistryPaused"];
    }

    function warp(uint256 dt) external {
        vm.warp(block.timestamp + bound(dt, 0, 10 days));
        ++calls["warp"];
    }

    function unprivileged(uint256 callerSeed, uint256 which, uint256 amount) external {
        address[USERS + 11] memory callers = [
            users[0],
            users[1],
            users[2],
            users[3],
            users[4],
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
        address caller = callers[callerSeed % callers.length];
        address victim = _user(amount);
        amount = bound(amount, 0, MAX_AMOUNT);
        bytes32[10] memory roles = [
            MINTER_ROLE,
            BURNER_ROLE,
            ADMIN_BURNER_ROLE,
            TOKEN_PAUSER_ROLE,
            TOKEN_PAUSER_ROLE,
            MULTIPLIER_UPDATER_ROLE,
            MULTIPLIER_UPDATER_ROLE,
            ORACLE_PAUSER_ROLE,
            ORACLE_PAUSER_ROLE,
            METADATA_UPDATER_ROLE
        ];
        bytes[10] memory gated = [
            abi.encodeCall(Stock.mint, (victim, amount)),
            abi.encodeCall(Stock.burn, (victim, amount % (modelBalance[victim] + 1))),
            abi.encodeCall(Stock.adminBurn, (victim, amount % (modelBalance[victim] + 1))),
            abi.encodeCall(Stock.pause, ()),
            abi.encodeCall(Stock.unpause, ()),
            abi.encodeWithSignature("updateMultiplier(uint256)", amount + 1),
            abi.encodeWithSignature("updateMultiplier(uint256,uint256)", amount + 1, block.timestamp),
            abi.encodeCall(Stock.pauseOracle, ()),
            abi.encodeCall(Stock.unpauseOracle, ()),
            abi.encodeCall(Stock.setMetadata, ("Hijacked", "HJK"))
        ];
        which %= gated.length;
        if (registry.hasRole(roles[which], caller)) return;
        bool ok = _call(caller, gated[which]);
        _judge(ok, P5, 5);
        ++calls["unprivileged"];
    }

    function initialize(uint256 callerSeed, bytes32 uid, bool onImplementation) external {
        address caller = _user(callerSeed);
        vm.prank(caller);
        (bool ok,) = address(onImplementation ? impl : token).call(abi.encodeCall(Stock.initialize, (uid, "Re", "RE")));
        _judge(ok, P6, 6);
        ++calls["initialize"];
    }
}
