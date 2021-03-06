//
//  Transport.swift
//
//
//  Created by Nikhil John on 29/12/20.
//

import Foundation

// MARK: Transport Delegate
extension FayeClient: TransportDelegate {
    public func didConnect() {
        self.connectionInitiated = false;
        self.handshake(token: self.accessToken!)
    }
    
    public func didFailConnection(_ error: NSError?) {
        self.delegate?.connectionFailed(self)
        self.connectionInitiated = false
        self.fayeConnected = false
    }
    
    public func didWriteError(_ error: NSError?) {
        self.delegate?.fayeClientError(self, error: error ?? NSError(error: FayeSocketError.transportWrite))
    }
    
    public func didReceiveMessage(_ text: String) {
        self.receive(text)
    }
    
    public func didReceivePong() {
        self.delegate?.pongReceived(self)
    }

    public func didDisconnect(_ type: DisconnectionType?) {
        self.delegate?.disconnectedFromServer(self)
        self.connectionInitiated = false
        self.fayeConnected = false
    }

    public func didReceiveData(_ data: Data) {
        self.receive(data)
    }

    public func didReceivePing() {
        self.delegate?.pingReceived(self)
    }
}
