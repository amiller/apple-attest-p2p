import Foundation

// Trust assumption: the RPC endpoint reports canonical chain state; no light client.
struct Chain {
    let rpcURL: URL
    let registry: String
    let chainId: UInt64
    func rpc(_ method: String,_ params: [Any]) throws -> Any {
        guard let r=try http(rpcURL,["jsonrpc":"2.0","id":1,"method":method,"params":params]) as? [String:Any] else {throw DemoError.invalid("RPC response")}
        if let e=r["error"] {throw DemoError.invalid("RPC error \(e)")}
        guard let value=r["result"] else {throw DemoError.invalid("RPC result")}
        return value
    }
    func call(_ signature: String,_ words: Data=Data()) throws -> Data {
        guard let s=try rpc("eth_call",[["to":registry,"data":hex(keccak(Data(signature.utf8)).prefix(4)+words)],"latest"]) as? String else {throw DemoError.invalid("call response")}
        return try unhex(s)
    }
    func groupPublic(_ scope: Data) throws -> Data {
        let value=try call("sharedKeys(bytes32)",scope);try need(value.count==128,"shared key encoding")
        try need(try smallWord(value.subdata(in:96..<128))==1,"key not committed")
        return Data([4])+value.prefix(64)
    }
    func committed(_ scope: Data) throws -> Bool {
        let value=try call("sharedKeys(bytes32)",scope);try need(value.count==128,"shared key encoding")
        return try smallWord(value.suffix(32))==1
    }
    func eligible(_ member: Data,_ category: Data,_ scope: Data) throws {
        try need(try smallWord(call("isActive(bytes32)",member))==1,"inactive peer")
        if scope==Data(repeating:0,count:32){
            let c=try call("categories(bytes32)",category);try need(c.count==192,"category encoding")
            try need(try smallWord(c.subdata(in:128..<160))==1,"overall ineligible")
        }else{try need(category==scope,"wrong recipient category")}
    }
    struct CheckedPeer {let member:Data;let category:Data;let context:Data;let session:Data;let logs:[[String:Any]]}
    func checkedPeer(_ transaction: String) throws -> CheckedPeer {
        try need(try unhex(transaction).count==32,"transaction width")
        guard let receipt=try rpc("eth_getTransactionReceipt",[transaction]) as? [String:Any],
              let blockHash=receipt["blockHash"] as? String,let blockNumber=receipt["blockNumber"] as? String,
              let logs=receipt["logs"] as? [[String:Any]] else {throw DemoError.invalid("unmined receipt")}
        try need(try quantity(receipt["status"])==1,"failed transaction")
        guard let block=try rpc("eth_getBlockByNumber",[blockNumber,false]) as? [String:Any],let canonicalHash=block["hash"] as? String else {throw DemoError.invalid("missing block")}
        try need(canonicalHash==blockHash,"reorged receipt")
        let timestamp=try quantity(block["timestamp"]);let now=UInt64(Date().timeIntervalSince1970)
        try need(timestamp<=now+5 && now<timestamp+60,"stale peer check-in")
        let topic=hex(keccak(Data("Checked(bytes32,bytes32,address,bytes32,bytes32)".utf8)))
        let found=logs.filter{($0["address"] as? String)?.lowercased()==registry.lowercased() && ($0["topics"] as? [String])?.first==topic}
        try need(found.count==1,"ambiguous peer check-in")
        guard let topics=found[0]["topics"] as? [String],topics.count==4,let raw=found[0]["data"] as? String else {throw DemoError.invalid("check-in log")}
        let data=try unhex(raw);try need(data.count==64,"check-in encoding")
        return try CheckedPeer(member:bytes32(topics[1]),category:bytes32(topics[2]),context:data.prefix(32),session:data.suffix(32),logs:logs)
    }
    func validateRelease(_ tx: String,_ parcel: Data,_ scope: Data) throws {
        let peer=try checkedPeer(tx);try eligible(peer.member,peer.category,scope)
        try need(peer.session==keccak(parcel.prefix(65)),"sender session")
        let topic=hex(keccak(Data("KeyReceipt(bytes32,bytes32,bytes32,bytes32)".utf8)))
        let matches=peer.logs.filter{log in
            guard (log["address"] as? String)?.lowercased()==registry.lowercased(),let topics=log["topics"] as? [String],topics.count==3 else {return false}
            return topics[0]==topic && topics[1]==hex(scope) && topics[2]==hex(peer.member)
        }
        try need(matches.count==1,"missing release commitment")
        guard let encoded=matches[0]["data"] as? String else {throw DemoError.invalid("release data")}
        try need(try unhex(encoded)==keccak(parcel)+peer.context,"release digest/context")
    }
}
func quantity(_ value: Any?) throws -> UInt64 {
    guard let s=value as? String,let n=UInt64(s.hasPrefix("0x") ? String(s.dropFirst(2)):s,radix:16) else {throw DemoError.invalid("RPC quantity")};return n
}
func smallWord(_ data: Data) throws -> UInt64 {
    try need(data.count==32 && data.prefix(24)==Data(repeating:0,count:24),"uint64 encoding")
    return data.suffix(8).reduce(UInt64(0)){($0<<8)|UInt64($1)}
}
