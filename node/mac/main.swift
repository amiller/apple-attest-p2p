import Foundation

func emit(_ event: String,_ fields: [String:Any]) {
    var f=fields;f["event"]=event;f["t"]=Date().timeIntervalSince1970
    print(String(decoding:try! JSONSerialization.data(withJSONObject:f,options:[.sortedKeys]),as:UTF8.self));fflush(stdout)
}
do {
    let args=CommandLine.arguments;try need(args.count==3 && ["listen","connect"].contains(args[2]),"usage: node <config.json> listen|connect")
    guard let d=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:args[1]))) as? [String:Any] else {throw DemoError.invalid("config JSON")}
    let node=Node(try Config(d),log:emit)
    if args[2]=="listen" {try node.listen()} else {try node.connect()}
    emit("done",[:])
} catch {emit("error",["error":"\(error)"]);exit(1)}
