import Foundation
import DeviceCheck
import CryptoKit

let zero32=Data(repeating:0,count:32)
#if MODIFIED
let variant="modified" // negative control: differs in measured code, must never be admitted
#else
let variant="honest"
#endif

struct Config {
    let rpc: URL; let registry: String; let chainId: UInt64; let category: Data; let relay: URL; let name: String
    let peer: String; let helloDelay: Double; let protocolVersion: Int; let persistentIdentity: Bool
    init(_ d: [String:Any]) throws {
        guard let rpc=d["rpc"] as? String,let registry=d["registry"] as? String,let chainId=d["chainId"] as? Int,let category=d["category"] as? String,
              let relay=d["relay"] as? String,let name=d["name"] as? String,let r=URL(string:rpc),let l=URL(string:relay) else {throw DemoError.invalid("config fields")}
        self.rpc=r;self.registry=registry;self.chainId=UInt64(chainId);self.category=try bytes32(category);self.relay=l;self.name=name
        peer=d["peer"] as? String ?? "";helloDelay=d["helloDelay"] as? Double ?? 0
        protocolVersion=d["protocolVersion"] as? Int ?? 1
        try need(protocolVersion==1 || protocolVersion==2,"unsupported protocol version")
        persistentIdentity=d["persistentIdentity"] as? Bool ?? false
    }
}

/// One network node: App Attest key enrolled on chain, fresh check-in per action,
/// peer messages through an untrusted relay mailbox, group key held in RAM only.
final class Node {
    let cfg: Config; let chain: Chain; let log: (String,[String:Any]) -> Void
    let service=DCAppAttestService.shared
    let session=P256.KeyAgreement.PrivateKey()
    var sessionPublic: Data {session.publicKey.x963Representation}
    var keyID=""; var owner=""; var me=Data(); var held=[Data:P256.Signing.PrivateKey](); var heldEpoch=[Data:UInt64](); var nonces=[String:Data]()
    struct EnrollmentState: Codable {var keyID: String;var attestation: String?;var clientData: String?}
    func statePath() throws -> URL {
        let root=try FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true)
            .appendingPathComponent("AttestNode",isDirectory:true)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        let domain="\(cfg.chainId):\(cfg.registry.lowercased()):\(hex(cfg.category)):\(cfg.name)"
        return root.appendingPathComponent(hex(keccak(Data(domain.utf8)))+".json")
    }
    func saveState(_ state: EnrollmentState) throws {
        if cfg.persistentIdentity {
            let path=try statePath();try JSONEncoder().encode(state).write(to:path,options:.atomic)
            try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:path.path)
        }
    }
    init(_ cfg: Config,log: @escaping (String,[String:Any]) -> Void) {
        self.cfg=cfg;chain=Chain(rpcURL:cfg.rpc,registry:cfg.registry,chainId:cfg.chainId);self.log=log
    }
    func relay(_ path: String,_ body: [String:Any]?=nil) throws -> [String:Any] {
        guard let r=try http(cfg.relay.appendingPathComponent(path),body) as? [String:Any] else {throw DemoError.invalid("relay response")}
        return r
    }
    func appAttest(enroll: Bool,_ context: Data) throws -> Data {
        let wait=DispatchSemaphore(value:0);var result:Data?;var failure:Error?
        let done:(Data?,Error?)->Void={d,e in result=d;failure=e;wait.signal()}
        // Enrollment: the adapter takes clientData and hashes it. Assertion: the adapter takes the 32-byte context as clientDataHash.
        if enroll {service.attestKey(keyID,clientDataHash:Data(SHA256.hash(data:context)),completionHandler:done)} else {service.generateAssertion(keyID,clientDataHash:context,completionHandler:done)}
        try need(wait.wait(timeout:.now()+90) == .success,"App Attest timeout")
        if let failure {throw failure}
        guard let result else {throw DemoError.invalid("missing App Attest response")};return result
    }
    func start() throws {
        try need(try quantity(chain.rpc("eth_chainId",[]))==cfg.chainId,"wrong chain")
        guard let o=try relay("info")["owner"] as? String else {throw DemoError.invalid("relay owner")};owner=o
        log("start",["variant":variant,"rpc":cfg.rpc.absoluteString,"registry":cfg.registry,"owner":owner,"appAttestSupported":service.isSupported])
        try need(service.isSupported,"App Attest unsupported")
        var state: EnrollmentState?
        if cfg.persistentIdentity {
            let path=try statePath()
            if FileManager.default.fileExists(atPath:path.path) {
                state=try JSONDecoder().decode(EnrollmentState.self,from:Data(contentsOf:path))
                guard let kid=Data(base64Encoded:state!.keyID),kid.count==32 else {throw DemoError.invalid("stored key ID")}
                let existing=try chain.enrollment(kid,category:cfg.category)
                if existing.enrolled && existing.expires>UInt64(Date().timeIntervalSince1970) {
                    keyID=state!.keyID;me=keccak(cfg.category+kid)
                    log("identity resumed",["member":hex(me),"expires":existing.expires]);return
                }
                if existing.enrolled {
                    log("identity expired",["previousMember":hex(keccak(cfg.category+kid)),"message":"A new attestation identity is required by the current verifier policy"])
                    state=nil
                }
            }
        }
        if state==nil {
        let wait=DispatchSemaphore(value:0);var failure:Error?
        service.generateKey{k,e in self.keyID=k ?? "";failure=e;wait.signal()}
        try need(wait.wait(timeout:.now()+90) == .success,"key generation timeout")
        if let failure {throw failure}
            state=EnrollmentState(keyID:keyID);try saveState(state!)
        } else {keyID=state!.keyID}
        guard let kid=Data(base64Encoded:keyID),kid.count==32 else {throw DemoError.invalid("key id")}
        me=keccak(cfg.category+kid)
        var context: Data;var attestation: Data
        if let cached=state!.attestation,let originalContext=state!.clientData {
            guard let value=Data(base64Encoded:cached) else {throw DemoError.invalid("stored enrollment")}
            attestation=value;context=try unhex(originalContext)
            log("resuming enrollment",[:])
        } else {
            context=try keccak(Data("TEE_INTEROP_ENROLL_V1".utf8)+addressWord(cfg.registry)+addressWord(owner)+sessionPublic)
            attestation=try appAttest(enroll:true,context)
            state!.attestation=attestation.base64EncodedString();state!.clientData=hex(context)
            try saveState(state!)
        }
        let r=try relay("enroll",["category":hex(cfg.category),"attestation":attestation.base64EncodedString(),"clientData":hex(context)])
        log("enrolled",["keyId":hex(kid),"member":hex(me),"tx":r["tx"] ?? "","sessionPublic":hex(sessionPublic)])
    }
    /// action: 0 join, 2 bootstrap, 3 receipt. The relay is gas sponsor and Request.owner.
    func execute(_ action: UInt64,scope: Data=zero32,group: P256.Signing.PrivateKey?=nil,envelope: Data=zero32) throws -> String {
        let nonce=try smallWord(chain.call("nonces(address)",addressWord(owner)))
        let point=group?.publicKey.x963Representation ?? Data(repeating:0,count:65)
        let request=Request(action:action,category:cfg.category,owner:owner,session:keccak(sessionPublic),nonce:nonce,deadline:UInt64(Date().timeIntervalSince1970)+55,
                            scope:action<2 ? zero32:scope,x:point.subdata(in:1..<33),y:point.subdata(in:33..<65),envelope:envelope)
        let epoch=action<2 ? 0:try chain.keyEpoch(scope,protocolVersion:cfg.protocolVersion)
        let context=try request.context(registry:cfg.registry,chainId:cfg.chainId,protocolVersion:cfg.protocolVersion,keyEpoch:epoch)
        let assertion=try appAttest(enroll:false,context)
        let signature=try group.map{hex(try $0.signature(for:RawDigest(data:context)).rawRepresentation)} ?? "0x"
        guard let tx=try relay("execute",["request":request.json,"context":hex(context),"assertion":assertion.base64EncodedString(),
                                          "keyId":keyID,"groupSignature":signature])["tx"] as? String else {throw DemoError.invalid("relay tx")}
        log("executed",["action":action,"scope":hex(scope),"keyEpoch":epoch,"tx":tx]);return tx
    }
    func join() throws -> String {try execute(0)}
    func bootstrap(_ scope: Data) throws {
        let epoch=try chain.keyEpoch(scope,protocolVersion:cfg.protocolVersion)
        let key=P256.Signing.PrivateKey();_=try execute(2,scope:scope,group:key);held[scope]=key;heldEpoch[scope]=epoch
    }
    func aad(_ scope: Data,_ recipient: Data,_ recipientPublic: Data) throws -> Data {
        try Data("TEE_INTEROP_PARCEL_V1".utf8)+word(cfg.chainId)+addressWord(cfg.registry)+scope+recipient+recipientPublic
    }
    func transport(_ peerPublic: Data,_ associated: Data) throws -> SymmetricKey {
        try session.sharedSecretFromKeyAgreement(with:P256.KeyAgreement.PublicKey(x963Representation:peerPublic))
            .hkdfDerivedSymmetricKey(using:SHA256.self,salt:Data(SHA256.hash(data:associated)),sharedInfo:Data("TEE_INTEROP_PARCEL_V1".utf8),outputByteCount:32)
    }
    /// Seal the held group key to a peer whose fresh on-chain check-in binds recipientPublic; commit the release on chain.
    func export(_ scope: Data,recipientPublic pub: Data,recipientTx: String) throws -> (Data,String) {
        try need(pub.count==65,"recipient public key")
        let peer=try chain.checkedPeer(recipientTx);try need(peer.session==keccak(pub),"recipient key binding")
        try chain.eligible(peer.member,peer.category,scope)
        guard let key=held[scope] else {throw DemoError.invalid("no local key")}
        try need(heldEpoch[scope]==(try chain.keyEpoch(scope,protocolVersion:cfg.protocolVersion)),"key epoch changed")
        try need(try chain.groupPublic(scope)==key.publicKey.x963Representation,"local key not committed")
        let associated=try aad(scope,peer.member,pub)
        guard let sealed=try AES.GCM.seal(key.rawRepresentation,using:transport(pub,associated),authenticating:associated).combined else {throw DemoError.invalid("AEAD result")}
        let parcel=sessionPublic+pub+peer.member+scope+sealed
        return (parcel,try execute(3,scope:scope,group:key,envelope:keccak(parcel)))
    }
    func importParcel(_ parcel: Data,senderTx: String) throws -> Data {
        try need(parcel.count==254,"parcel size")
        let scope=parcel.subdata(in:162..<194)
        try need(parcel.subdata(in:65..<130)==sessionPublic && parcel.subdata(in:130..<162)==me,"parcel recipient")
        try chain.eligible(me,cfg.category,scope);try chain.validateRelease(senderTx,parcel,scope)
        let associated=try aad(scope,me,sessionPublic)
        let raw=try AES.GCM.open(AES.GCM.SealedBox(combined:parcel.suffix(60)),using:transport(parcel.prefix(65),associated),authenticating:associated)
        let key=try P256.Signing.PrivateKey(rawRepresentation:raw)
        try need(try chain.groupPublic(scope)==key.publicKey.x963Representation,"imported key commitment")
        held[scope]=key;heldEpoch[scope]=try chain.keyEpoch(scope,protocolVersion:cfg.protocolVersion)
        _=try execute(3,scope:scope,group:key,envelope:keccak(parcel))
        return scope
    }
    func send(_ to: String,_ message: [String:Any]) throws {
        var m=message;m["from"]=cfg.name;_=try relay("send/\(to)",m);log("sent",["to":to,"type":m["type"] ?? ""])
    }
    func receive(timeout: Double) throws -> [String:Any] {
        let end=Date().addingTimeInterval(timeout)
        while Date()<end {
            if let m=try relay("recv/\(cfg.name)")["message"] as? [String:Any] {log("received",["type":m["type"] ?? "","from":m["from"] ?? ""]);return m}
            Thread.sleep(forTimeInterval:0.5)
        }
        throw DemoError.invalid("receive timeout")
    }
    /// Holds the overall group key and hands it to admitted peers until a STOP message.
    func listen() throws {
        try start()
        if !(try chain.committed(zero32)) {try bootstrap(zero32)}
        try need(held[zero32] != nil,"overall key committed by another process; this node cannot export it")
        while true {
            let m=try receive(timeout:3600);guard let type=m["type"] as? String,let from=m["from"] as? String else {throw DemoError.invalid("message fields")}
            do {
                switch type {
                case "HELLO":
                    guard let pub=m["sessionPublic"] as? String,let tx=m["joinTx"] as? String,let nonce=m["nonce"] as? String else {throw DemoError.invalid("HELLO fields")}
                    let (parcel,receipt)=try export(zero32,recipientPublic:unhex(pub),recipientTx:tx)
                    nonces[from]=try unhex(nonce)
                    try send(from,["type":"PARCEL","parcel":hex(parcel),"receiptTx":receipt])
                case "PROOF":
                    guard let nonce=nonces.removeValue(forKey:from),let sig=m["signature"] as? String else {throw DemoError.invalid("unexpected PROOF")}
                    let group=try P256.Signing.PublicKey(x963Representation:chain.groupPublic(zero32))
                    try need(group.isValidSignature(try P256.Signing.ECDSASignature(rawRepresentation:unhex(sig)),for:nonce),"PROOF signature")
                    log("peer holds group key",["peer":from])
                case "STOP": log("stop",[:]);return
                default: throw DemoError.invalid("message type")
                }
            } catch {
                log("refused",["peer":from,"type":type,"error":"\(error)"])
                try send(from,["type":"ERROR","reason":"\(error)"])
            }
        }
    }
    /// Joins, asks `peer` for the overall group key, imports it, proves possession.
    func connect() throws {
        try start()
        let joinTx=try join()
        Thread.sleep(forTimeInterval:cfg.helloDelay)
        let nonce=Data(SHA256.hash(data:Data(UUID().uuidString.utf8)))
        if !cfg.peer.isEmpty {try send(cfg.peer,["type":"HELLO","member":hex(me),"joinTx":joinTx,"sessionPublic":hex(sessionPublic),"nonce":hex(nonce)])}
        let m=try receive(timeout:300)
        guard let type=m["type"] as? String,type=="PARCEL",let parcel=m["parcel"] as? String,let tx=m["receiptTx"] as? String
        else {throw DemoError.invalid("peer replied \(m["type"] ?? ""): \(m["reason"] ?? "")")}
        let scope=try importParcel(unhex(parcel),senderTx:tx)
        log("imported group key",["scope":hex(scope),"groupPublic":hex(try chain.groupPublic(scope))])
        guard let key=held[scope] else {throw DemoError.invalid("no key")}
        try send(cfg.peer,["type":"PROOF","signature":hex(try key.signature(for:nonce).rawRepresentation)])
    }
}
