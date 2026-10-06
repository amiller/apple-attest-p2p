import SwiftUI
import DeviceCheck

/// Thin iOS shell over node/shared: edit the config JSON, run listen/connect, watch the log.
/// NODE_CONFIG / NODE_ROLE in the environment prefill the config and start a role at launch.
/// NODE_PROBE_KEYGEN calls DCAppAttestService.generateKey directly and logs its result (simulator check).
@main struct NodeApp: App {
    var body: some Scene {WindowGroup {NodeView()}}
}
struct NodeView: View {
    @State var config=ProcessInfo.processInfo.environment["NODE_CONFIG"] ?? ""
    @State var lines=[String]()
    var body: some View {
        VStack(alignment:.leading) {
            TextEditor(text:$config).font(.caption.monospaced()).frame(height:140).border(.gray)
            HStack {Button("Listen"){run("listen")};Button("Connect"){run("connect")}}
            List(lines.indices,id:\.self){Text(lines[$0]).font(.caption2.monospaced())}
        }.padding().onAppear {
            let env=ProcessInfo.processInfo.environment
            if env["NODE_PROBE_KEYGEN"] != nil {DCAppAttestService.shared.generateKey{k,e in emit("generateKey",["keyId":k ?? "nil","error":e.map{"\($0)"} ?? "nil"])}}
            if let role=env["NODE_ROLE"] {run(role)}
        }
    }
    func emit(_ event: String,_ fields: [String:Any]) {
        var f=fields;f["event"]=event
        let line=String(decoding:(try? JSONSerialization.data(withJSONObject:f,options:[.sortedKeys])) ?? Data(),as:UTF8.self)
        print(line);fflush(stdout)
        DispatchQueue.main.async {lines.append(line)}
    }
    func run(_ role: String) {
        let text=config
        DispatchQueue.global().async {
            do {
                guard let d=try JSONSerialization.jsonObject(with:Data(text.utf8)) as? [String:Any] else {throw DemoError.invalid("config JSON")}
                let node=Node(try Config(d),log:emit)
                if role=="listen" {try node.listen()} else {try node.connect()}
                emit("done",[:])
            } catch {emit("error",["error":"\(error)"])}
        }
    }
}
