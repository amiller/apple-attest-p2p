import SwiftUI
import DeviceCheck

@main struct NodeApp: App {
    var body: some Scene {WindowGroup {NodeView()}}
}

/// One participant worker per process. SwiftUI view recreation must not generate
/// another enrollment or start a second network loop.
final class ParticipantModel: ObservableObject {
    @Published var title = "Connecting to the testnet…"
    @Published var detail = "Keep this app open while it verifies your device and joins."
    @Published var badge = "Your participant NFT will be claimed automatically."
    @Published var receiptURL: URL?
    @Published var lines = [String]()
    @Published var simulatorScenario = false
    private var started = false

    func start() {
        guard !started else {return};started = true
        emit("app launched",["os":ProcessInfo.processInfo.operatingSystemVersionString,
            "appVersion":Bundle.main.object(forInfoDictionaryKey:"CFBundleShortVersionString") ?? "unknown",
            "appBuild":Bundle.main.object(forInfoDictionaryKey:"CFBundleVersion") ?? "unknown"])
        #if targetEnvironment(simulator)
        if let scenario = ProcessInfo.processInfo.environment["ATTESTNODE_UI_SCENARIO"] {
            simulatorScenario = true
            emit("simulator scenario",["scenario":scenario])
            emit("configured",["chainId":84532,"participant":"SIMULATED"])
            switch scenario {
            case "claimed":emit("participating",[:]);emit("badge claimed",["badgeToken":42])
            case "retry":emit("retrying",["retryAfterSeconds":4,"error":"Injected network outage"])
            case "apple-failure":
                emit("apple operation failed",["stage":"attestKey","errorChain":[["domain":"com.apple.devicecheck.error","code":0],["domain":"CryptoTokenKit","code":-3]]])
                emit("stopped",["error":"Injected Apple failure"])
            default:emit("attesting",[:])
            }
            return
        }
        #endif
        DispatchQueue.global(qos:.userInitiated).async {self.run()}
    }
    private func run() {
        do {
            guard var settings = ReleaseNetwork.settings else {throw DemoError.invalid("Release network is unavailable")}
            let defaults = UserDefaults.standard
            let name = defaults.string(forKey:"participantName") ?? UUID().uuidString.lowercased()
            defaults.set(name,forKey:"participantName")
            settings["name"] = name;settings["persistentIdentity"] = true
            let config = try Config(settings)
            try need(!config.peer.isEmpty,"missing faucet peer")
            emit("configured",["chainId":config.chainId,"registry":config.registry,"participant":name])
            guard DCAppAttestService.shared.isSupported else {
                emit("stopped",["error":"App Attest unsupported on this device","appAttestSupported":false]);return
            }
            let node = Node(config,log:emit)
            var delay:Double = 2
            while true {
                do {try node.participate();return}
                catch {
                    let e = error as NSError
                    // Only Apple's service-unavailable error is retried here.
                    // Invalid keys and unknown native errors need diagnosis;
                    // repeating them indefinitely conceals a failed enrollment.
                    let terminalApple = NativeAttestation.mustStop(error)
                    let message = String(describing:error)
                    if terminalApple || message.contains("unsupported") || message.contains("timeout") || message.contains("identity already running") {
                        emit("stopped",["error":message,"errorDomain":e.domain,"errorCode":e.code]);return
                    }
                    emit("retrying",["error":message,"retryAfterSeconds":delay])
                    Thread.sleep(forTimeInterval:delay);delay = min(delay*2,60)
                }
            }
        } catch {emit("stopped",["error":String(describing:error)])}
    }
    private func emit(_ event:String,_ fields:[String:Any]) {
        // Reports contain public receipts and bounded diagnostic metadata, never
        // enrollment blobs, private keys, or peer exchange payloads.
        let allowed:Set<String> = ["appAttestSupported","scenario","os","appVersion","appBuild","stage","errorChain","chainId","registry","participant","error","errorDomain","errorCode","retryAfterSeconds","badgeToken","badgeLevel","badgeContract","personalAccount","tx","receipt","keyEpoch"]
        var entry = fields.filter {allowed.contains($0.key)}
        entry["event"] = event;entry["t"] = Date().timeIntervalSince1970
        guard let data = try? JSONSerialization.data(withJSONObject:entry,options:[.sortedKeys]) else {return}
        let line = String(decoding:data,as:UTF8.self)
        print(line);fflush(stdout)
        DispatchQueue.main.async {
            self.lines.append(line);self.lines = Array(self.lines.suffix(200))
            if let directory = FileManager.default.urls(for:.documentDirectory,in:.userDomainMask).first {
                try? self.lines.joined(separator:"\n").write(to:directory.appendingPathComponent("diagnostics.jsonl"),atomically:true,encoding:.utf8)
            }
            switch event {
            case "connecting":self.title = "Connecting to the testnet…"
            case "attesting":self.title = "Verifying this app…";self.detail = "Apple attestation checks this app before the network admits it."
            case "getting key":self.title = "Joining the network…";self.detail = "Waiting for a verified peer to share the testnet key."
            case "participating":self.title = "You’re connected";self.detail = "The shared testnet key is verified. This iPhone participates while the app is open."
            case "badge preparing":self.badge = "Preparing your personal NFT account…"
            case "badge claiming":self.badge = "Claiming your participant NFT…"
            case "badge retrying":self.badge = "NFT claim pending; retrying automatically."
            case "badge claimed":
                self.badge = "Participant NFT #\(fields["badgeToken"] ?? "") confirmed"
                if let contract = fields["badgeContract"] as? String,let token = fields["badgeToken"],(fields["chainId"] as? NSNumber)?.uint64Value == 84532 {
                    self.receiptURL = URL(string:"https://sepolia.basescan.org/token/\(contract)?a=\(token)")
                }
            case "retrying":self.title = "Waiting to reconnect…";self.detail = "Retrying in \(fields["retryAfterSeconds"] ?? 0) seconds."
            case "stopped":self.title = "Couldn’t join the network";self.detail = "No further automatic attempts will run. Share the diagnostic report so we can investigate.";if self.receiptURL == nil {self.badge = "NFT claim has not completed."}
            default:break
            }
        }
    }
}

struct NodeView: View {
    @StateObject private var participant = ParticipantModel()
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment:.leading,spacing:24) {
                    Image(systemName:"network").font(.system(size:44)).foregroundStyle(.tint).accessibilityHidden(true)
                    Text(participant.title).font(.largeTitle.bold())
                    Text(participant.detail).foregroundStyle(.secondary)
                    Divider()
                    Text(participant.badge).font(.headline)
                    if let url = participant.receiptURL {Link("View NFT receipt",destination:url)}
                    Text("Research testnet · Base Sepolia\nNo payment or wallet setup required.").font(.footnote).foregroundStyle(.secondary)
                    DisclosureGroup("Technical details") {
                        Text(participant.lines.joined(separator:"\n")).font(.caption.monospaced()).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading)
                    }
                    ShareLink(item:participant.lines.joined(separator:"\n")) {Label("Share diagnostic report",systemImage:"square.and.arrow.up")}
                }.padding(24)
            }.navigationTitle("Apple peer testnet").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge:.top) {
                if participant.simulatorScenario {
                    Text("SIMULATOR SCENARIO — no hardware attestation or NFT transaction")
                        .font(.caption.bold()).foregroundStyle(.orange).padding().frame(maxWidth:.infinity).background(.background)
                }
            }
        }.onAppear {participant.start()}
    }
}
