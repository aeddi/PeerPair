//
//  GameService.swift
//  WhatTheShell
//
//  Created by Chuck Smith on 09.04.19.
//  Copyright © 2019 Ludisto. All rights reserved.
//

import Foundation
import MultipeerConnectivity

protocol GameServiceDelegate {
    func networkLog(_ logText: String)

    // Add other message handler functions here
}

class GameService : NSObject {

    // Service type must be a unique string, at most 15 characters long
    // and can contain only ASCII lowercase letters, numbers and hyphens.
    let gameServiceType = "peerpair"

    let versionKey: String = "apiVersion"
    let networkApiVersion = "1.0.0" // Different from our app version # as not every update will break the network "API"

    private let myPeerID = MCPeerID(displayName: "Macbook")
    private var opponentID: MCPeerID?

    private let serviceAdvertiser : MCNearbyServiceAdvertiser
    private let serviceBrowser : MCNearbyServiceBrowser

    private var myState = MCSessionState.notConnected
    private var successful = false

    var oppDisplayName: String?

    lazy var session : MCSession = {
        let session = MCSession(peer: self.myPeerID,
                                securityIdentity: nil,
                                encryptionPreference: .none)

        session.delegate = self
        return session
    }()

    var delegate: GameServiceDelegate?

    override init() {
        self.serviceAdvertiser = MCNearbyServiceAdvertiser(peer: myPeerID,
                                                           discoveryInfo: nil,
                                                           serviceType: gameServiceType)

        self.serviceBrowser = MCNearbyServiceBrowser(peer: myPeerID,
                                                     serviceType: gameServiceType)

        super.init()
    }

    deinit {
        NSLog("deinit: stop searching for players")
        stopSearchingForPlayers()
    }

    public func startSearchingForPlayers() {
        self.serviceAdvertiser.delegate = self
        self.serviceAdvertiser.startAdvertisingPeer()
        delegate?.networkLog("Started advertising")

        self.serviceBrowser.delegate = self
        self.serviceBrowser.startBrowsingForPeers()
        delegate?.networkLog("Started browsing")
    }

    public func stopSearchingForPlayers() {
        self.serviceAdvertiser.stopAdvertisingPeer()
        delegate?.networkLog("Stopped advertising")
        self.serviceBrowser.stopBrowsingForPeers()
        delegate?.networkLog("Stopped browsing")
    }

    func tryAnotherConnection() {
        if myState == .notConnected && !successful {
            opponentID = nil

            delegate?.networkLog("Trying to connect to another device")

            self.serviceBrowser.stopBrowsingForPeers()
            self.serviceBrowser.startBrowsingForPeers()
        }
    }

    func send(data: Data) {
        NSLog("%@", "sending data to \(session.connectedPeers.count) peers")

        if session.connectedPeers.count > 0 {
            do {
                try self.session.send(data,
                                      toPeers: session.connectedPeers,
                                      with: .reliable)
            }
            catch let error {
                delegate?.networkLog("Error for sending: \(error)")
            }
        }
    }

    public func ping() {
        delegate?.networkLog("Pinging \(session.connectedPeers.count) peers")

        let stringToSend = "Hi!"
        if let dataToSend = stringToSend.data(using: .utf8) {
            send(data: dataToSend)
        }

    }

    public func disconnect() {
        delegate?.networkLog("Disconnecting from session")
        session.disconnect()
        stopSearchingForPlayers()   // Needed in case someone quits before game starts
    }
}

extension GameService : MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        delegate?.networkLog("Did not start advertising peer: \(error)")
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        delegate?.networkLog("Received invitation from \(peerID.displayName)")
        if myState == .notConnected && opponentID == nil {
            delegate?.networkLog("Accepting invitation from \(peerID.displayName)")
            invitationHandler(true, self.session)   // Automatically accept invitation
            opponentID = peerID
            myState = .connecting
        } else {
            delegate?.networkLog("Rejecting invitation from \(peerID.displayName), \(myState.debugValue) to \(opponentID!.displayName)")
            invitationHandler(false, self.session)  // Reject invitation
        }
    }
}

extension GameService : MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        delegate?.networkLog("did not start browsing for peers: \(error)")
    }

    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        delegate?.networkLog("Found: \(peerID.displayName)")

        // Extra check to be absolutely sure a device doesn't connect with itself
        // and also checks to make sure it doesn't connect with more than one device
        if self.myPeerID.displayName != peerID.displayName && myState == .notConnected {
            delegate?.networkLog("Inviting: \(peerID.displayName)")
            browser.invitePeer(peerID,
                               to: self.session,
                               withContext: nil,
                               timeout: 10)
            opponentID = peerID
            myState = .connecting
        }
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        delegate?.networkLog("Lost \(peerID.displayName)")

        if opponentID == peerID {
            opponentID = nil
            myState = .notConnected
        }
    }
}

extension GameService : MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        delegate?.networkLog("\(state.debugValue): \(peerID.displayName)")

        // Only listen to connection changes from opponent
        if opponentID == peerID {
            myState = state     // Set my state to opponent's state

            switch state {
            case .connecting:
                // TODO: Connecting successfully, so stop advertising
                stopSearchingForPlayers()
            case .connected:
                successful = true
            case .notConnected:
                opponentID = nil    // Disconnected, erase opponent ID
                if successful {
                    successful = false  // Reset success for next connection
                } else {
                    tryAnotherConnection()
                }
            @unknown default:
                NSLog("Ignoring: unknown network state")
            }
        }

        if session.connectedPeers.count > 0 {
            let displayNames = session.connectedPeers.map{$0.displayName}.joined(separator: ", ")
            self.delegate?.networkLog("Currently connected devices: \(displayNames)")
        } else {
            self.delegate?.networkLog("No devices connected!")
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveData: \(data.count) bytes")
        if let msg = String(data: data, encoding: .utf8) {
            processMessage(msg, fromPeer: peerID)
        }

    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
    }

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
    }

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
    }
}

// Process network messages
extension GameService {
    func processMessage(_ message: String, fromPeer peerID: MCPeerID) {
        delegate?.networkLog("\(peerID.displayName) said \(message)")
    }
}

extension MCSessionState {
    var debugValue: String {
        switch self {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting"
        case .notConnected:
            return "Not Connected"
        @unknown default:
            return "Unknown"
        }
    }
}
