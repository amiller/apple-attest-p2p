import Foundation

// Measured release network; operational metadata cannot redirect the peer.
// The deployment remains paused until the exact signed build is admitted.
enum ReleaseNetwork {
    static let name = "Apple peer testnet"
    static let settings: [String:Any]? = try! JSONSerialization.jsonObject(with:Data(#"""
{
  "category": "0xc34deb12633776ff7cd9c9690b28da7211248fe619baf5aca75c3afc8941f4a7",
  "chainId": 84532,
  "peer": "release-seed",
  "persistentIdentity": true,
  "protocolVersion": 2,
  "registry": "0x46113dF78D1D412c3B01f0Cf9d4265044336e3FB",
  "relay": "https://pod.dstack.soc1024.com/apple-attest-p2p-relay",
  "rpc": "https://sepolia.base.org"
}
"""#.utf8)) as? [String:Any]
}
