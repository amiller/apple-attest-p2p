// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import {Test} from "forge-std/Test.sol";
import {AppleAttestRegistryV1} from "../src/AppleAttestRegistryV1.sol";
import {AppleAuthData} from "../src/AppleAuthData.sol";
import {CDRegistry} from "../src/CDRegistry.sol";
import {P256Verifier} from "./P256Verifier.sol";
contract Lookup is AppleAttestRegistryV1 {
    constructor(CDRegistry cds_,bytes16 aaguid_) AppleAttestRegistryV1(msg.sender,cds_,aaguid_,3,false){}
    function check(bytes memory auth) external view {(,,bytes32 cdhash,bytes32 rp)=AppleAuthData.check(auth,aaguid,false,0,0,validationCategory);admit(cdhash,rp);}
}
contract AppleAttestRegistryV1Test is Test {
    AppleAttestRegistryV1 adapter;CDRegistry cds;bytes cert;bytes auth;bytes clientData;bytes32 kid;bytes16 aaguid;string fixture;
    bytes32 constant OURS=0x90a07dc69293aa64c279caed89cfebd3fde0ad92b510f752ed45ba829157fff6;
    function setUp() public {P256Verifier p=new P256Verifier();vm.etch(address(0x100),address(p).code);}
    function load(string memory path,string memory build,uint32 category,bool ios,bool register) internal {
        fixture=vm.readFile(path);
        cert=vm.parseJsonBytes(fixture,".cert");auth=vm.parseJsonBytes(fixture,".auth");clientData=vm.parseJsonBytes(fixture,".clientData");kid=vm.parseJsonBytes32(fixture,".kid");
        bytes memory guid=vm.parseJsonBytes(fixture,".aaguid");assembly{sstore(aaguid.slot,shr(128,mload(add(guid,32))))}
        string memory b=vm.readFile(build);bytes memory cd=vm.parseJsonBytes(b,".cd");bytes memory page0=vm.parseJsonBytes(b,".page0");bytes memory ent=vm.parseJsonBytes(b,".ent");
        cds=new CDRegistry();cds.setBuild(cd,page0,ent,vm.parseJsonUint(b,".linkeditCmd"),vm.parseJsonUint(b,".codeSigCmd"));
        if(register)assertEq(cds.registerBuild(cd,page0,ent),vm.parseJsonBytes32(fixture,".cdhash"));
        adapter=new AppleAttestRegistryV1(address(this),cds,aaguid,category,ios);
    }
    function mac(bool register) internal {vm.warp(1789588800);load("fixtures/fresh-apple.json","fixtures/cd-args-probe-macos.json",3,false,register);}
    function iphone(bool register) internal {vm.warp(1790200000);load("fixtures/iphone-apple.json","fixtures/resign/iphone-honest.json",5,true,register);}
    function assertion(string memory name) internal view returns(bytes32 context,bytes memory proof){
        context=sha256(vm.parseJsonBytes(fixture,string.concat(".",name,".context")));
        proof=abi.encode(kid,vm.parseJsonBytes(fixture,string.concat(".",name,".auth")),uint256(vm.parseJsonBytes32(fixture,string.concat(".",name,".r"))),uint256(vm.parseJsonBytes32(fixture,string.concat(".",name,".s"))));
    }
    function test_MacEnrollAndAssertThroughRegistry() public {
        mac(true);assertEq(adapter.enroll(cert,auth,clientData),kid);
        (bytes32 context,bytes memory proof)=assertion("assert");assertEq(adapter.verify(context,proof),kid);
        (context,proof)=assertion("modified");vm.expectRevert("build not admitted");adapter.verify(context,proof);
        (context,proof)=assertion("restored");assertEq(adapter.verify(context,proof),kid);
        (,,,uint32 count,)=adapter.keys(kid);assertEq(count,3);
    }
    function test_MacUnregisteredBuildRejected() public {mac(false);vm.expectRevert("build not admitted");adapter.enroll(cert,auth,clientData);}
    function test_IPhoneEnrollAndAssertThroughRegistry() public {
        iphone(true);assertEq(adapter.enroll(cert,auth,clientData),kid);
        (bytes32 context,bytes memory proof)=assertion("assert");assertEq(adapter.verify(context,proof),kid);
        (context,proof)=assertion("modified");vm.expectRevert("build not admitted");adapter.verify(context,proof);
    }
    function test_IPhoneUnderMacProfileRejected() public {
        iphone(true);AppleAttestRegistryV1 m=new AppleAttestRegistryV1(address(this),cds,aaguid,5,false);
        vm.expectRevert("key ACL");m.enroll(cert,auth,clientData);
    }
    function test_IPhoneUnregisteredBuildRejected() public {iphone(false);vm.expectRevert("build not admitted");adapter.enroll(cert,auth,clientData);}
    function withBuild(bytes memory a,bytes32 rp,bytes32 cdhash) internal pure returns(bytes memory){assembly{mstore(add(a,32),rp) mstore(add(a,94),cdhash)}return a;}
    function jb(string memory j,string memory k) internal pure returns(bytes memory){return vm.parseJsonBytes(j,k);}
    /// Real cross-team pair (Eigen Developer ID build of Darkbloom, our re-sign): each CDHash resolves only to its own team's RP ID.
    function test_SecondTeamLookup() public {
        mac(true);bytes memory a=vm.parseJsonBytes(fixture,".assert.auth");
        string memory e=vm.readFile("fixtures/resign/darkbloom-eigen.json");string memory o=vm.readFile("fixtures/resign/darkbloom-ours-ent.json");
        cds=new CDRegistry();cds.setBuild(jb(e,".cd"),jb(e,".page0"),jb(e,".ent"),vm.parseJsonUint(e,".linkeditCmd"),vm.parseJsonUint(e,".codeSigCmd"));
        bytes32 eh=cds.registerBuild(jb(e,".cd"),jb(e,".page0"),jb(e,".ent"));bytes32 oh=cds.registerBuild(jb(o,".cd"),jb(o,".page0"),jb(o,".ent"));
        bytes32 erp=sha256("SLDQ2GJ6TL.io.darkbloom.provider");bytes32 orp=sha256("DC9JH5DRMY.io.darkbloom.provider");
        Lookup l=new Lookup(cds,aaguid);
        l.check(withBuild(a,erp,eh));l.check(withBuild(a,orp,oh));
        vm.expectRevert("build not admitted");l.check(withBuild(a,erp,oh));
        vm.expectRevert("build not admitted");l.check(withBuild(a,orp,eh));
    }
}
