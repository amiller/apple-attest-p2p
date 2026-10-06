// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import {Test} from "forge-std/Test.sol";
import {CDRegistry} from "../src/CDRegistry.sol";
contract CDRegistryTest is Test {
    string constant D = "fixtures/resign/";
    uint256 constant LINKEDIT = 2320;
    uint256 constant CODESIG = 3608;
    bytes32 constant OURS = 0x90a07dc69293aa64c279caed89cfebd3fde0ad92b510f752ed45ba829157fff6;
    function rd(string memory n, string memory ext) internal view returns (bytes memory) { return vm.readFileBinary(string.concat(D, n, ext)); }
    function registry(bytes memory cd, bytes memory page0, uint256 linkedit, uint256 codeSig) internal returns (CDRegistry r) {
        r = new CDRegistry();
        r.setBuild(cd, page0, linkedit, codeSig);
    }
    function mac() internal returns (CDRegistry) { return registry(rd("A-original", ".cd"), rd("A-original", ".page0"), LINKEDIT, CODESIG); }
    function json(string memory n) internal returns (CDRegistry r, bytes memory cd, bytes memory page0) {
        string memory j = vm.readFile(string.concat(D, n, ".json"));
        (cd, page0) = (vm.parseJsonBytes(j, ".cd"), vm.parseJsonBytes(j, ".page0"));
        r = registry(cd, page0, vm.parseJsonUint(j, ".linkeditCmd"), vm.parseJsonUint(j, ".codeSigCmd"));
    }
    function admit(CDRegistry r, bytes memory cd, bytes memory page0) internal returns (bytes32 h) {
        h = r.registerBuild(cd, page0);
        assertEq(h, sha256(cd));
        assertTrue(r.isAdmitted(h));
    }
    function test_resignFixtures() public {
        CDRegistry r = mac();
        assertEq(r.rpIdHash(admit(r, rd("A-original", ".cd"), rd("A-original", ".page0"))), OURS);
        assertEq(OURS, sha256("DC9JH5DRMY.dev.dsmack.provider"));
        string[3] memory hdr = ["B-adhoc", "C-adhoc-otherid", "H-strip-then-adhoc"];
        for (uint256 i; i < 3; i++) { vm.expectRevert("header"); r.registerBuild(rd(hdr[i], ".cd"), rd(hdr[i], ".page0")); }
        string[4] memory info = ["D-dev-timestamp", "E-dev-noent", "G-strip-then-dev", "I-dev-resign-same"];
        for (uint256 i; i < 4; i++) { vm.expectRevert(bytes("info")); r.registerBuild(rd(info[i], ".cd"), rd(info[i], ".page0")); }
        vm.expectRevert("page0"); r.registerBuild(rd("M-modified", ".cd"), rd("M-modified", ".page0"));
        bytes memory p = rd("B-adhoc", ".page0"); p[100] ^= 0x01;
        vm.expectRevert("page0 hash"); r.registerBuild(rd("B-adhoc", ".cd"), p);
    }
    function patched(uint256 at, bytes1 x) internal view returns (bytes memory cd) { cd = rd("A-original", ".cd"); cd[at] ^= x; }
    function test_signerSlotsFreeHeaderAndInfoPinned() public {
        CDRegistry r = mac();
        bytes memory page0 = rd("A-original", ".page0");
        bytes32 h = admit(r, patched(351 - 64, 0x01), page0);
        assertEq(r.rpIdHash(h), OURS);
        assertTrue(h != sha256(rd("A-original", ".cd")));
        vm.expectRevert("header"); r.registerBuild(patched(0x0d, 0x01), page0);
        vm.expectRevert("header"); r.registerBuild(patched(0x57, 0x10), page0);
        vm.expectRevert("header"); r.registerBuild(patched(0x5b, 0x01), page0);
        vm.expectRevert(bytes("info")); r.registerBuild(patched(351 - 1, 0x01), page0);
        bytes memory cd = rd("A-original", ".cd"); cd[0x33] = 0;
        vm.expectRevert("no team"); r.registerBuild(cd, page0);
    }
    function test_secondTeamGetsItsOwnRpId() public {
        CDRegistry r = mac();
        bytes memory cd = rd("A-original", ".cd");
        for (uint256 i = 116; i < 126; i++) cd[i] = "Z";
        bytes32 h = admit(r, cd, rd("A-original", ".page0"));
        assertEq(r.rpIdHash(h), sha256("ZZZZZZZZZZ.dev.dsmack.provider"));
        assertEq(r.rpIdHash(sha256(rd("A-original", ".cd"))), 0);
    }
    function test_ownerSetsBuildAndOldBuildsStopResolving() public {
        CDRegistry r = mac();
        bytes32 a = admit(r, rd("A-original", ".cd"), rd("A-original", ".page0"));
        string memory j = vm.readFile(string.concat(D, "iphone-honest.json"));
        (bytes memory cd, bytes memory page0) = (vm.parseJsonBytes(j, ".cd"), vm.parseJsonBytes(j, ".page0"));
        vm.prank(address(1)); vm.expectRevert("owner"); r.setBuild(cd, page0, 2880, 5120);
        r.setBuild(cd, page0, 2880, 5120);
        assertEq(r.rpIdHash(a), 0);
        assertEq(r.rpIdHash(admit(r, cd, page0)), OURS);
    }
    function test_iphoneBuild() public {
        (CDRegistry r, bytes memory cd, bytes memory page0) = json("iphone-honest");
        bytes32 h = admit(r, cd, page0);
        assertEq(h, 0x5395bf39ecded47ab804eb78b7f878c246baa4860ca32cad1c63ed468783b591);
        assertEq(r.rpIdHash(h), OURS);
        string memory j = vm.readFile(string.concat(D, "iphone-modified.json"));
        vm.expectRevert("code slots"); r.registerBuild(vm.parseJsonBytes(j, ".cd"), vm.parseJsonBytes(j, ".page0"));
    }
    function test_darkbloomCrossTeam() public {
        (CDRegistry r, bytes memory cd, bytes memory page0) = json("darkbloom-eigen");
        bytes32 h = r.registerBuild(cd, page0);
        emit log_named_uint("darkbloom-eigen registerBuild exec gas", vm.lastCallGas().gasTotalUsed);
        emit log_named_uint("calldata bytes", abi.encodeCall(CDRegistry.registerBuild, (cd, page0)).length);
        assertEq(r.rpIdHash(h), sha256("SLDQ2GJ6TL.io.darkbloom.provider"));
        string memory j = vm.readFile(string.concat(D, "darkbloom-ours.json"));
        vm.expectRevert(bytes("info")); r.registerBuild(vm.parseJsonBytes(j, ".cd"), vm.parseJsonBytes(j, ".page0"));
    }
    function synth(uint256 n) internal pure returns (bytes memory cd, bytes memory page0) {
        page0 = new bytes(16384);
        for (uint256 i; i < 16384; i++) page0[i] = bytes1(uint8(i * 7 + 1));
        uint256 off = 0x60 + 20 + 11 + 7 * 32;
        cd = new bytes(off + 32 * n);
        bytes memory h = abi.encodePacked(uint32(0xfade0c02), uint32(cd.length), uint32(0x20500), uint32(0), uint32(off), uint32(0x60), uint32(7), uint32(n), uint32(n * 16384));
        h = bytes.concat(h, new bytes(0x30 - h.length), bytes4(uint32(0x74)), new bytes(0x60 - 0x34), "dev.dsmack.provider\x00DC9JH5DRMY\x00");
        for (uint256 i; i < h.length; i++) cd[i] = h[i];
        cd[0x24] = 0x20; cd[0x25] = 0x02; cd[0x27] = 0x0e;
        bytes32 s0 = sha256(page0);
        for (uint256 i; i < 32; i++) cd[off + i] = s0[i];
        for (uint256 i = 32; i < 32 * n; i++) cd[off + i] = bytes1(uint8(uint256(keccak256(abi.encode(i / 32))) >> (8 * (i % 32))));
    }
    function measure(uint256 n) internal {
        (bytes memory cd, bytes memory page0) = synth(n);
        CDRegistry r = registry(cd, page0, LINKEDIT, CODESIG);
        r.registerBuild(cd, page0);
        uint256 exec = vm.lastCallGas().gasTotalUsed;
        bytes memory d = abi.encodeCall(CDRegistry.registerBuild, (cd, page0));
        uint256 z;
        for (uint256 i; i < d.length; i++) if (d[i] == 0) z++;
        uint256 nz = d.length - z;
        uint256 std = 16 * nz + 4 * z;
        uint256 floor = 10 * (4 * nz + z);
        emit log_named_uint("slots", n);
        emit log_named_uint("calldata bytes", d.length);
        emit log_named_uint("exec", exec);
        emit log_named_uint("calldata std", std);
        emit log_named_uint("calldata floor", floor);
        emit log_named_uint("tx total", 21000 + (std + exec > floor ? std + exec : floor));
    }
    function test_gas1280() public { measure(1280); }
    function test_gas3200() public { measure(3200); }
    function test_gas6400() public { measure(6400); }
}
