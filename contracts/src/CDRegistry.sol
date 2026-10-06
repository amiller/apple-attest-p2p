// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
/// Admits re-signed copies of one approved Mach-O. Code slots 1..n must equal the approved
/// build's; page 0 must equal the approved page 0 after masking the three signer-dependent
/// fields (__LINKEDIT vmsize, filesize; LC_CODE_SIGNATURE datasize). The CodeDirectory header
/// fields a re-signer controls (version, flags, hash/page parameters, execSeg*, runtime),
/// nSpecialSlots and the Info.plist slot (-1) must equal the approved build's; slots -2..-7 are free.
/// Each admitted CDHash records rpIdHash = sha256(teamID "." identifier), the App Attest RP ID,
/// assuming App ID prefix == team ID (true for DC9JH5DRMY). The owner sets the approved build;
/// CDHashes registered under an earlier build stop resolving.
contract CDRegistry {
    struct Build {
        bytes32 rest;
        bytes32 maskedPage0;
        bytes32 header;
        bytes32 info;
        uint256 nSpecial;
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
    function cstr(bytes calldata b, uint256 o) internal pure returns (bytes calldata) {
        uint256 e = o;
        while (b[e] != 0) e++;
        return b[o:e];
    }
    function maskedHash(bytes memory p, uint256 linkedit, uint256 codeSig) public pure returns (bytes32 h) {
        assembly {
            let d := add(p, 0x20)
            mstore(add(d, add(linkedit, 32)), and(mload(add(d, add(linkedit, 32))), not(shl(192, not(0)))))
            mstore(add(d, add(linkedit, 48)), and(mload(add(d, add(linkedit, 48))), not(shl(192, not(0)))))
            mstore(add(d, add(codeSig, 12)), and(mload(add(d, add(codeSig, 12))), not(shl(224, not(0)))))
            h := keccak256(d, mload(p))
        }
    }
    function measure(bytes calldata cd, bytes calldata page0, uint256 linkedit, uint256 codeSig) public pure returns (Build memory) {
        require(be32(cd, 0) == 0xfade0c02 && be32(cd, 4) == cd.length, "blob");
        require(cd[0x24] == 0x20 && cd[0x25] == 0x02 && cd[0x27] == 0x0e && page0.length == 16384, "sha256/16KiB");
        uint256 off = be32(cd, 0x10);
        uint256 end = off + 32 * be32(cd, 0x1c);
        require(end <= cd.length && sha256(page0) == bytes32(cd[off:off + 32]), "page0 hash");
        uint256 hdrEnd = be32(cd, 8) >= 0x20500 ? 0x60 : 0x58;
        return Build(keccak256(cd[off + 32:end]), maskedHash(page0, linkedit, codeSig),
            keccak256(bytes.concat(cd[8:16], cd[0x24:0x30], cd[0x34:hdrEnd])), bytes32(cd[off - 32:off]),
            be32(cd, 0x18), be32(cd, 0x20), linkedit, codeSig);
    }
    function setBuild(bytes calldata cd, bytes calldata page0, uint256 linkedit, uint256 codeSig) external {
        require(msg.sender == owner, "owner");
        approved = measure(cd, page0, linkedit, codeSig);
        buildId = keccak256(abi.encode(approved));
    }
    function registerBuild(bytes calldata cd, bytes calldata page0) external returns (bytes32 h) {
        Build memory a = approved;
        Build memory b = measure(cd, page0, a.linkeditCmd, a.codeSigCmd);
        require(b.codeLimit == a.codeLimit, "limit");
        require(b.rest == a.rest, "code slots");
        require(b.maskedPage0 == a.maskedPage0, "page0");
        require(b.header == a.header, "header");
        uint256 team = be32(cd, 0x30);
        require(team != 0, "no team");
        require(b.nSpecial == a.nSpecial && b.info == a.info, "info");
        h = sha256(cd);
        rp[h] = sha256(bytes.concat(cstr(cd, team), ".", cstr(cd, be32(cd, 0x14))));
        buildOf[h] = buildId;
    }
    function rpIdHash(bytes32 h) public view returns (bytes32) { return buildOf[h] == buildId ? rp[h] : bytes32(0); }
    function isAdmitted(bytes32 h) external view returns (bool) { return rpIdHash(h) != 0; }
}
