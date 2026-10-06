// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import {StrictDER} from "./StrictDER.sol";

/// Admits re-signed copies of one approved Mach-O, by any signer. Pinned (behavior):
/// - code slots 1..n and codeLimit;
/// - page 0 after masking the three signer-dependent fields (__LINKEDIT vmsize, filesize;
///   LC_CODE_SIGNATURE datasize);
/// - CodeDirectory header fields that change execution: version, flags (hardened runtime,
///   ad hoc), hash/page parameters, execSeg base/limit/flags, runtime version;
/// - the DER entitlements (slot -7): same keys in the same order and byte-equal values, except
///   the identity keys (application-identifier, team-identifier, keychain-access-groups),
///   whose values AMFI checks against the signer's provisioning profile at launch.
/// Free (signer identity, no effect on the executable's code or privileges): CD identifier,
/// team ID, slots -1 (Info.plist), -2 (requirements), -3 (resources), -5 (XML entitlements),
/// and the CMS signature.
/// Info.plist is not pinned: the probe/node apps read no Info.plist keys, and hardened runtime
/// (pinned) blocks DYLD_* injection through LSEnvironment. Residual: a re-signer can change
/// non-code bundle metadata (e.g. ATS exceptions, LSEnvironment for non-DYLD variables).
/// Each admitted CDHash records rpIdHash = sha256(application-identifier), the App Attest RP ID.
/// The owner sets the approved build; CDHashes registered under an earlier build stop resolving.
contract CDRegistry {
    struct Build {
        bytes32 rest;
        bytes32 maskedPage0;
        bytes32 header;
        bytes32 entitlements;
        uint256 codeLimit;
        uint256 linkeditCmd;
        uint256 codeSigCmd;
    }
    address public immutable owner = msg.sender;
    Build public approved;
    bytes32 public buildId;
    mapping(bytes32 => bytes32) rp;
    mapping(bytes32 => bytes32) buildOf;
    function be32(bytes calldata b, uint256 o) internal pure returns (uint256) { return uint32(bytes4(b[o:o + 4])); }
    function maskedHash(bytes memory p, uint256 linkedit, uint256 codeSig) public pure returns (bytes32 h) {
        assembly {
            let d := add(p, 0x20)
            mstore(add(d, add(linkedit, 32)), and(mload(add(d, add(linkedit, 32))), not(shl(192, not(0)))))
            mstore(add(d, add(linkedit, 48)), and(mload(add(d, add(linkedit, 48))), not(shl(192, not(0)))))
            mstore(add(d, add(codeSig, 12)), and(mload(add(d, add(codeSig, 12))), not(shl(224, not(0)))))
            h := keccak256(d, mload(p))
        }
    }
    /// Hash of the entitlement shape (identity values blanked) and sha256(application-identifier).
    function entitlements(bytes memory der) public pure returns (bytes32 shape, bytes32 app) {
        StrictDER.Node memory outer = StrictDER.expect(der, 0, der.length, 0x70);
        StrictDER.Node memory version = StrictDER.expect(der, outer.body, outer.end, 0x02);
        require(outer.end == der.length && version.end == version.body + 1 && der[version.body] == 0x01, "entitlements");
        StrictDER.Node memory dict = StrictDER.expect(der, version.end, outer.end, 0xb0);
        require(dict.end == outer.end, "entitlements");
        for (uint256 p = dict.body; p < dict.end;) {
            StrictDER.Node memory pair = StrictDER.expect(der, p, dict.end, 0x30);
            StrictDER.Node memory key = StrictDER.expect(der, pair.body, pair.end, 0x0c);
            StrictDER.Node memory value = StrictDER.node(der, key.end, pair.end);
            require(value.end == pair.end, "entitlements");
            bytes32 k = keccak256(StrictDER.contents(der, key));
            if (k == keccak256("application-identifier") || k == keccak256("com.apple.application-identifier")) {
                require(app == 0 && value.tag == 0x0c, "application-identifier");
                app = sha256(StrictDER.contents(der, value));
                shape = keccak256(abi.encode(shape, k));
            } else if (k == keccak256("com.apple.developer.team-identifier") || k == keccak256("keychain-access-groups")) {
                shape = keccak256(abi.encode(shape, k));
            } else shape = keccak256(abi.encode(shape, keccak256(StrictDER.encoded(der, pair))));
            p = pair.end;
        }
        require(app != 0, "application-identifier");
    }
    function header(bytes calldata cd) internal pure returns (bytes32) {
        return keccak256(bytes.concat(cd[8:16], cd[0x24:0x30], cd[0x34:be32(cd, 8) >= 0x20500 ? 0x60 : 0x58]));
    }
    function measure(bytes calldata cd, bytes calldata page0, bytes calldata ent, uint256 linkedit, uint256 codeSig) public pure returns (Build memory b, bytes32 app) {
        require(be32(cd, 0) == 0xfade0c02 && be32(cd, 4) == cd.length, "blob");
        require(cd[0x24] == 0x20 && cd[0x25] == 0x02 && cd[0x27] == 0x0e && page0.length == 16384, "sha256/16KiB");
        uint256 off = be32(cd, 0x10);
        uint256 end = off + 32 * be32(cd, 0x1c);
        require(end <= cd.length && sha256(page0) == bytes32(cd[off:off + 32]), "page0 hash");
        require(be32(cd, 0x18) >= 7 && sha256(abi.encodePacked(uint32(0xfade7172), uint32(ent.length + 8), ent)) == bytes32(cd[off - 7 * 32:off - 6 * 32]), "entitlements slot");
        (b.entitlements, app) = entitlements(ent);
        b.rest = keccak256(cd[off + 32:end]);
        b.maskedPage0 = maskedHash(page0, linkedit, codeSig);
        b.header = header(cd);
        (b.codeLimit, b.linkeditCmd, b.codeSigCmd) = (be32(cd, 0x20), linkedit, codeSig);
    }
    function setBuild(bytes calldata cd, bytes calldata page0, bytes calldata ent, uint256 linkedit, uint256 codeSig) external {
        require(msg.sender == owner, "owner");
        (approved,) = measure(cd, page0, ent, linkedit, codeSig);
        buildId = keccak256(abi.encode(approved));
    }
    function registerBuild(bytes calldata cd, bytes calldata page0, bytes calldata ent) external returns (bytes32 h) {
        Build memory a = approved;
        require(a.codeLimit != 0, "no approved build");
        (Build memory b, bytes32 app) = measure(cd, page0, ent, a.linkeditCmd, a.codeSigCmd);
        require(b.codeLimit == a.codeLimit, "limit");
        require(b.rest == a.rest, "code slots");
        require(b.maskedPage0 == a.maskedPage0, "page0");
        require(b.header == a.header, "header");
        require(b.entitlements == a.entitlements, "entitlements");
        h = sha256(cd);
        rp[h] = app;
        buildOf[h] = buildId;
    }
    function rpIdHash(bytes32 h) public view returns (bytes32) { return buildOf[h] == buildId ? rp[h] : bytes32(0); }
    function isAdmitted(bytes32 h) external view returns (bool) { return rpIdHash(h) != 0; }
}
