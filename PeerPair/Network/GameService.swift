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
    func connectedDevicesChanged(manager: GameService, connectedDevices: [String])
    
    // TODO: Add other message handler functions here
}

class GameService : NSObject {
    
    // Service type must be a unique string, at most 15 characters long
    // and can contain only ASCII lowercase letters, numbers and hyphens.
    let gameServiceType = "ludisto-wts"
    
    let versionKey: String = "apiVersion"
    let networkApiVersion = "1.0.0" // Different from our app version # as not every update will break the network "API"

    private let myPeerID = MCPeerID(displayName: UIDevice.current.name)
    private var opponentID: MCPeerID?
    
    private let serviceAdvertiser : MCNearbyServiceAdvertiser
    private let serviceBrowser : MCNearbyServiceBrowser
    
    private var myState = MCSessionState.notConnected
    
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
        
        self.serviceBrowser.delegate = self
        self.serviceBrowser.startBrowsingForPeers()
        NSLog("Started searching for players")
    }
    
    public func stopSearchingForPlayers() {
        
        self.serviceAdvertiser.stopAdvertisingPeer()
        self.serviceBrowser.stopBrowsingForPeers()
        NSLog("Stopped searching for players")
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
                NSLog("%@", "Error for sending: \(error)")
            }
        }
    }

    public func disconnect() {
        NSLog("Session disconnect called")
        session.disconnect()
        stopSearchingForPlayers()   // Needed in case someone quits before game starts
    }
}

extension GameService : MCNearbyServiceAdvertiserDelegate {
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        NSLog("%@", "didNotStartAdvertisingPeer: \(error)")
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID, withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        NSLog("%@", "didReceiveInvitationFromPeer \(peerID)")
        if myState == .notConnected {
            invitationHandler(true, self.session)   // Automatically accept invitation
            opponentID = peerID
            myState = .connecting
        }
    }
}

extension GameService : MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        NSLog("%@", "didNotStartBrowsingForPeers: \(error)")
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) {
        NSLog("self.peerId: \(self.myPeerID)")
        NSLog("%@", "foundPeer and invitePeer: \(peerID)")
        
        // Extra check to be absolutely sure a device doesn't connect with itself
        // and also checks to make sure it doesn't connect with more than one device
        if self.myPeerID.displayName != peerID.displayName && myState == .notConnected {
            browser.invitePeer(peerID,
                               to: self.session,
                               withContext: nil,
                               timeout: 10)
        }
    }
    
    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
    }
}

extension GameService : MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        NSLog("%@", "peer \(peerID) didChangeState: \(state.rawValue))")
        
        // Only listen to connection changes from opponent (or if you don't yet have an opponent)
        if opponentID == nil || opponentID == peerID {
            
            myState = state     // Set my state to opponent's state
            opponentID = peerID // Store opponent's ID
            
            switch state {
            case .connected:
                // TODO: Display connected message
                break
            case .connecting:
                // TODO: Display connecting message
                break
            case .notConnected:
                // Disconnected, erase opponent ID
                opponentID = nil
                
                // TODO: Show disconnected message
            @unknown default:
                NSLog("Ignoring: unknown network state")
            }
            
            let displayNames = session.connectedPeers.map{$0.displayName}
            
            self.delegate?.connectedDevicesChanged(manager: self,
                                                   connectedDevices: displayNames)
        }
    }
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        NSLog("%@", "didReceiveData: \(data.count) bytes")
        if let msg = String(data: data, encoding: .utf8) {
            processMessage(msg)
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
    func processMessage(_ message: String) {
    }
}
