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
        string memory b=vm.readFile(build);bytes memory cd=vm.parseJsonBytes(b,".cd");bytes memory page0=vm.parseJsonBytes(b,".page0");
        cds=new CDRegistry();cds.setBuild(cd,page0,vm.parseJsonUint(b,".linkeditCmd"),vm.parseJsonUint(b,".codeSigCmd"));
        if(register)assertEq(cds.registerBuild(cd,page0),vm.parseJsonBytes32(fixture,".cdhash"));
        adapter=new AppleAttestRegistryV1(address(this),cds,aaguid,category,ios);
    }
    function mac(bool register) internal {vm.warp(1789588800);load("fixtures/fresh-apple.json","network/cd-args-macos.json",3,false,register);}
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
    function test_SecondTeamLookup() public {
        mac(true);Lookup l=new Lookup(cds,aaguid);
        bytes memory a=vm.parseJsonBytes(fixture,".assert.auth");bytes memory page0=vm.readFileBinary("fixtures/resign/A-original.page0");
        bytes memory z=vm.readFileBinary("fixtures/resign/A-original.cd");for(uint256 i=116;i<126;i++)z[i]="Z";
        bytes32 zh=cds.registerBuild(z,page0);bytes32 zrp=sha256("ZZZZZZZZZZ.dev.dsmack.provider");assertEq(cds.rpIdHash(zh),zrp);
        bytes32 ah=sha256(vm.readFileBinary("fixtures/resign/A-original.cd"));
        l.check(withBuild(a,zrp,zh));l.check(withBuild(a,OURS,ah));
        vm.expectRevert("build not admitted");l.check(withBuild(a,OURS,zh));
        vm.expectRevert("build not admitted");l.check(withBuild(a,zrp,ah));
        bytes memory dbg=vm.readFileBinary("fixtures/resign/A-original.cd");dbg[0x57]^=0x10;
        vm.expectRevert("header");cds.registerBuild(dbg,page0);
        bytes32 dh=sha256(dbg);vm.expectRevert("build not admitted");l.check(withBuild(a,OURS,dh));
    }
}
