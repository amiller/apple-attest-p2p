#if GUI
import AppKit

final class StatusContentView: NSView {
    override var isOpaque:Bool {true}
    override func draw(_ dirtyRect:NSRect) {
        NSColor.windowBackgroundColor.setFill();dirtyRect.fill()
    }
}

final class ParticipantApp: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var window: NSWindow!
    private var menuItem: NSStatusItem!
    private let titleLabel=NSTextField(labelWithString:"Connecting to the testnet…")
    private let detailLabel=NSTextField(wrappingLabelWithString:"Starting automatically. You can close this window and keep participating from the menu bar.")
    private let receiptLabel=NSTextField(wrappingLabelWithString:"No verified key receipt yet")
    private let badgeLabel=NSTextField(wrappingLabelWithString:"Participant NFT: waiting for a connection")
    private let badgeReceiptButton=NSButton(title:"View NFT receipt",target:nil,action:nil)
    private let diagnosticScroll=NSScrollView()
    private let detailsButton=NSButton(title:"Show technical details",target:nil,action:nil)
    private let diagnostics=NSTextView()
    private var status=[String:Any]()
    private var eventLines=[String]()
    private var peerNames=Set<String>()
    private var node: Node?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        window=NSWindow(contentRect:NSRect(x:0,y:0,width:740,height:440),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
        window.contentView=StatusContentView(frame:window.contentView!.frame)
        window.title=ReleaseNetwork.name;window.delegate=self;window.isReleasedWhenClosed=false
        titleLabel.font = .systemFont(ofSize:25,weight:.semibold)
        detailLabel.textColor = .secondaryLabelColor
        receiptLabel.isSelectable=true;badgeLabel.isSelectable=true
        badgeReceiptButton.target=self;badgeReceiptButton.action=#selector(openBadgeReceipt);badgeReceiptButton.isEnabled=false
        if ReleaseNetwork.settings?["badges"] == nil {badgeLabel.stringValue="This preview connects to the network; NFT claims are not enabled."}
        diagnostics.isEditable=false;diagnostics.font = .monospacedSystemFont(ofSize:11,weight:.regular)
        detailsButton.target=self;detailsButton.action=#selector(toggleDetails)
        let scroll=diagnosticScroll;scroll.isHidden=true;scroll.documentView=diagnostics;scroll.hasVerticalScroller=true
        let caption=NSTextField(labelWithString:"Research testnet • no monetary value • shared key stays in memory")
        caption.font = .systemFont(ofSize:11);caption.textColor = .secondaryLabelColor
        let stack=NSStackView(views:[titleLabel,detailLabel,receiptLabel,badgeLabel,badgeReceiptButton,caption,detailsButton,scroll])
        stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=18;stack.translatesAutoresizingMaskIntoConstraints=false
        let content=window.contentView!;content.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:content.leadingAnchor,constant:24),stack.trailingAnchor.constraint(equalTo:content.trailingAnchor,constant:-24),stack.topAnchor.constraint(equalTo:content.topAnchor,constant:24),stack.bottomAnchor.constraint(lessThanOrEqualTo:content.bottomAnchor,constant:-24),scroll.widthAnchor.constraint(equalTo:stack.widthAnchor),scroll.heightAnchor.constraint(greaterThanOrEqualToConstant:160),detailLabel.widthAnchor.constraint(equalTo:stack.widthAnchor),receiptLabel.widthAnchor.constraint(equalTo:stack.widthAnchor),badgeLabel.widthAnchor.constraint(equalTo:stack.widthAnchor)])
        let menu=NSMenu()
        menu.addItem(withTitle:"Show testnet status",action:#selector(showWindow),keyEquivalent:"").target=self
        menu.addItem(withTitle:"Save status image…",action:#selector(saveStatusImage),keyEquivalent:"").target=self
        menu.addItem(.separator())
        menu.addItem(withTitle:"Quit peer",action:#selector(quit),keyEquivalent:"q").target=self
        menuItem=NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        menuItem.button?.title="◌ Testnet";menuItem.menu=menu
        let mainMenu=NSMenu();let appItem=NSMenuItem();mainMenu.addItem(appItem);appItem.submenu=menu.copy() as? NSMenu;NSApp.mainMenu=mainMenu
        window.center();showWindow()
        DispatchQueue.global(qos:.utility).async {self.runParticipant()}
    }
    @objc private func showWindow() {window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)}
    @objc private func toggleDetails() {
        let show=diagnosticScroll.isHidden;diagnosticScroll.isHidden = !show
        detailsButton.title=show ? "Hide technical details":"Show technical details"
        var frame=window.frame;let delta:CGFloat=show ? 200:-200
        frame.origin.y-=delta;frame.size.height+=delta;window.setFrame(frame,display:true,animate:true)
    }
    private func captureStatus(to url:URL) throws {
        guard let content=window.contentView else {throw DemoError.invalid("status view unavailable")}
        content.layoutSubtreeIfNeeded();window.displayIfNeeded()
        guard let bitmap=content.bitmapImageRepForCachingDisplay(in:content.bounds) else {throw DemoError.invalid("status image unavailable")}
        content.cacheDisplay(in:content.bounds,to:bitmap)
        guard let png=bitmap.representation(using:.png,properties:[:]) else {throw DemoError.invalid("status PNG unavailable")}
        try png.write(to:url,options:.atomic)
    }
    @objc private func saveStatusImage() {
        let panel=NSSavePanel();panel.nameFieldStringValue="AttestNode-status.png"
        if panel.runModal() == .OK,let url=panel.url {
            do {try captureStatus(to:url)} catch {NSAlert(error:error).runModal()}
        }
    }
    @objc private func openBadgeReceipt() {
        guard let contract=status["badgeContract"] as? String,let token=status["badgeToken"],
              (status["chainId"] as? NSNumber)?.uint64Value==84532,let url=URL(string:"https://sepolia.basescan.org/token/\(contract)?a=\(token)") else {return}
        NSWorkspace.shared.open(url)
    }
    @objc private func quit() {NSApp.terminate(nil)}
    func applicationShouldTerminateAfterLastWindowClosed(_ sender:NSApplication)->Bool {false}

    private func runParticipant() {
        do {
            var settings=ReleaseNetwork.settings
            // Developer launch only: explicit local config, no editor or buttons.
            if CommandLine.arguments.count==3 && CommandLine.arguments[1]=="--config" {
                settings=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:CommandLine.arguments[2]))) as? [String:Any]
            }
            guard var config=settings else {
                emit("configuration unavailable",["message":"This development build has no validated release network yet."]);return
            }
            if config["name"] == nil {
                let defaults=UserDefaults.standard
                let identity=defaults.string(forKey:"participantName") ?? UUID().uuidString.lowercased()
                defaults.set(identity,forKey:"participantName");config["name"]=identity
            }
            config["persistentIdentity"]=true
            let cfg=try Config(config)
            try need(!cfg.peer.isEmpty,"missing faucet peer")
            emit("configured",["network":ReleaseNetwork.name,"chainId":cfg.chainId,"registry":cfg.registry,"participant":cfg.name])
            let participant=Node(cfg,log:emit);self.node=participant
            var delay:Double=2
            while true {
                do {try participant.participate();return}
                catch {
                    let message=String(describing:error)
                    if message.contains("App Attest unsupported") || message.contains("identity already running") {
                        emit("stopped",["error":message]);return
                    }
                    emit("retrying",["error":message,"retryAfterSeconds":delay])
                    Thread.sleep(forTimeInterval:delay);delay=min(delay*2,60)
                }
            }
        } catch {emit("stopped",["error":String(describing:error)])}
    }
    private func emit(_ event:String,_ fields:[String:Any]) {
        var entry=fields;entry["event"]=event;entry["t"]=Date().timeIntervalSince1970
        guard let data=try? JSONSerialization.data(withJSONObject:entry,options:[.sortedKeys]) else {return}
        let line=String(decoding:data,as:UTF8.self);print(line);fflush(stdout)
        DispatchQueue.main.async {
            self.eventLines.append(line);self.eventLines=Array(self.eventLines.suffix(100))
            self.diagnostics.string=self.eventLines.joined(separator:"\n")
            self.status.merge(fields){_,new in new};self.status["lastEvent"]=event;self.status["updatedAt"]=entry["t"]
            switch event {
            case "badge preparing":self.badgeLabel.stringValue="Preparing your personal NFT account…"
            case "badge claiming":self.badgeLabel.stringValue="Claiming your participant NFT…"
            case "badge retrying":self.badgeLabel.stringValue="NFT claim pending; retrying automatically. Your peer remains connected."
            case "badge claimed":self.badgeReceiptButton.isEnabled=(fields["chainId"] as? NSNumber)?.uint64Value==84532;self.badgeLabel.stringValue="Participant NFT #\(fields["badgeToken"] ?? "") confirmed\nYour account: \(fields["personalAccount"] ?? "")"
            case "connecting":self.setState("connecting","Connecting to the testnet…","Checking the configured network and relay.")
            case "attesting":self.setState("attesting","Verifying this app…","Checking the signed app and this Mac’s attestation identity.")
            case "getting key":self.setState("getting-key","Getting the shared testnet key…","Waiting for an admitted peer and a verifiable receipt.")
            case "key verified":
                self.receiptLabel.stringValue="Shared testnet key verified · epoch \(fields["keyEpoch"] ?? 0)"
            case "participating":self.setState("active","You’re connected","The shared key is verified. This Mac is available to admitted peers; closing the window keeps it running.")
            case "peer holds group key":
                if let peer=fields["peer"] as? String {self.peerNames.insert(peer)}
                self.status["verifiedPeersThisSession"]=self.peerNames.count
            case "retrying":self.setState("retrying","Connection interrupted; retrying…","Retrying in \(fields["retryAfterSeconds"] ?? 0) seconds. Details are below.")
            case "configuration unavailable":self.setState("unconfigured","Release network not configured",fields["message"] as? String ?? "")
            case "stopped":self.setState("stopped","Participation stopped",fields["error"] as? String ?? "")
            default:break
            }
            self.writeStatus()
            // Explicit agent invocation captures the same AppKit view as the menu
            // action, after a confirmed claim. No whole-desktop permission needed.
            let args=CommandLine.arguments
            if event=="badge claimed",args.count==3,args[1]=="--capture-status" {
                do {try self.captureStatus(to:URL(fileURLWithPath:args[2]));print("Status image saved");fflush(stdout)}
                catch {NSLog("Status image failed: %@",String(describing:error))}
            }
        }
    }
    private func setState(_ state:String,_ title:String,_ detail:String) {
        status["state"]=state;titleLabel.stringValue=title;detailLabel.stringValue=detail
        menuItem.button?.title=state=="active" ? "● Testnet":"◌ Testnet"
    }
    private func writeStatus() {
        // Agent-readable evidence follows exactly the same events as the window.
        guard let root=try? FileManager.default.url(for:.applicationSupportDirectory,in:.userDomainMask,appropriateFor:nil,create:true) else {return}
        let dir=root.appendingPathComponent("AttestNode",isDirectory:true)
        do {
            try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
            let file=dir.appendingPathComponent("status.json")
            try JSONSerialization.data(withJSONObject:status,options:[.sortedKeys,.prettyPrinted]).write(to:file,options:.atomic)
            try FileManager.default.setAttributes([.posixPermissions:0o600],ofItemAtPath:file.path)
        } catch {NSLog("Could not write participant status: %@",String(describing:error))}
    }
}
func runParticipantApp() {
    let app=NSApplication.shared;let delegate=ParticipantApp();app.delegate=delegate
    withExtendedLifetime(delegate){app.run()}
}
#endif
