import Foundation

extension Node {
    func attemptParticipantBadge() {
        guard badgeParticipation && !badgeComplete && Date()>=nextBadgeAttempt && cfg.badges != nil else {return}
        nextBadgeAttempt=Date().addingTimeInterval(60)
        do {try claimParticipantBadge();badgeComplete=true}
        catch {log("badge retrying",["error":String(describing:error),"retryAfterSeconds":60])}
    }
    func claimParticipantBadge() throws {
        guard let badges=cfg.badges,let factory=cfg.accountFactory,let group=held[zero32],let kid=Data(base64Encoded:keyID) else {throw DemoError.invalid("badge setup unavailable")}
        let personal=try PersonalAccountKey.loadOrCreate(chainId:cfg.chainId,factory:factory)
        let point=personal.publicPoint;let coordinates=Data(point.dropFirst())
        let result=try chain.call("accountAddress(uint256,uint256)",coordinates,to:factory)
        try need(result.count==32 && result.prefix(12)==Data(repeating:0,count:12),"personal account address")
        let account=hex(result.suffix(20))
        log("badge preparing",["personalAccount":account])
        guard let code=try chain.rpc("eth_getCode",[account,"latest"]) as? String else {throw DemoError.invalid("account code")}
        if code=="0x" {
            let digest=try keccak(keccak(Data("ATTEST_PERSONAL_CREATE_V1".utf8))+word(cfg.chainId)+addressWord(factory)+kid+coordinates)
            let (_,request)=try executeDetailed(3,group:group,envelope:digest)
            _=try relay("personal-account",["x":hex(coordinates.prefix(32)),"y":hex(coordinates.suffix(32)),"keyId":hex(kid),"request":request.json])
        }
        try need(try chain.call("badges()",to:account)==addressWord(badges),"personal account badge policy")
        try need(try chain.call("keyX()",to:account)+chain.call("keyY()",to:account)==coordinates,"This account has been handed to another app; use that copy")
        var token=try smallWord(chain.call("participantOf(address)",addressWord(account),to:badges))
        var transaction=""
        if token==0 {
            log("badge claiming",["personalAccount":account])
            let claim=BadgeClaim(recipient:account,keyId:kid,level:1,parent:0,deadline:try chain.requestDeadline())
            let digest=try claim.digest(chainId:cfg.chainId,badges:badges)
            try need(try chain.call("claimDigest((address,bytes32,uint8,uint256,uint64))",claim.words(),to:badges)==digest,"badge claim ABI")
            let generation=try smallWord(chain.call("generation()",to:account))
            let signature=try personal.consent(chainId:cfg.chainId,account:account,generation:generation,claim:digest)
            let (_,request)=try executeDetailed(3,group:group,envelope:digest)
            let response=try relay("badge-claim",["claim":claim.json,"request":request.json,"recipientSignature":hex(signature)])
            transaction=response["tx"] as? String ?? ""
            token=try smallWord(chain.call("participantOf(address)",addressWord(account),to:badges))
        }
        try need(token>0,"NFT claim not confirmed yet")
        try need(try chain.call("ownerOf(uint256)",word(token),to:badges)==addressWord(account),"NFT recipient mismatch")
        log("badge claimed",["badgeLevel":1,"badgeToken":token,"badgeContract":badges,"personalAccount":account,"badgeTransaction":transaction,"chainId":cfg.chainId])
    }
}
