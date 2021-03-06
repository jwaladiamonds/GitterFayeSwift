//
//  Client.swift
//
//
//  Created by Nikhil John on 29/12/20.
//

import Foundation

// MARK: FayeClient
open class FayeClient {
    open var fayeURLString:String {
        didSet {
            if let transport = self.transport {
                transport.urlString = fayeURLString
            }
        }
    }
    
    open var fayeClientId:String?
    open var accessToken: String?
    open weak var delegate:FayeClientDelegate?
    
    var transport:WebsocketTransport?
    open var transportHeaders: [String: String]? = nil {
        didSet {
            if let transport = self.transport {
                transport.headers = self.transportHeaders
            }
        }
    }
    
    open internal(set) var fayeConnected:Bool? {
        didSet {
            if fayeConnected == false {
                unsubscribeAllSubscriptions()
            }
        }
    }
    
    var connectionInitiated:Bool?
    var messageNumber:UInt32 = 0
    
    var queuedSubscriptions = Array<FayeSubscriptionModel>()
    var pendingSubscriptions = Array<FayeSubscriptionModel>()
    var openSubscriptions = Array<FayeSubscriptionModel>()
    
    var channelSubscriptionBlocks = Dictionary<String, ChannelSubscriptionBlock>()
    
    lazy var pendingSubscriptionSchedule: Timer = {
        return Timer.scheduledTimer(
            timeInterval: 45,
            target: self,
            selector: #selector(pendingSubscriptionsAction(_:)),
            userInfo: nil, 
            repeats: true
        )
    }()
    
    /// Default in 10 seconds
    let timeOut: Int
    
    let readOperationQueue = DispatchQueue(label: "com.hamin.fayeclient.read", attributes: [])
    let writeOperationQueue = DispatchQueue(label: "com.hamin.fayeclient.write", attributes: DispatchQueue.Attributes.concurrent)
    let queuedSubsLockQueue = DispatchQueue(label:"com.fayeclient.queuedSubscriptionsLockQueue")
    let pendingSubsLockQueue = DispatchQueue(label:"com.fayeclient.pendingSubscriptionsLockQueue")
    let openSubsLockQueue = DispatchQueue(label:"com.fayeclient.openSubscriptionsLockQueue")
    
    // MARK: Init
    public init(aFayeURLString:String, accessToken: String, timeoutAdvice:Int=10000) {
        self.fayeURLString = aFayeURLString
        self.fayeConnected = false;
        self.timeOut = timeoutAdvice
        self.accessToken = accessToken
        
        self.transport = WebsocketTransport(url: aFayeURLString)
        self.transport!.headers = self.transportHeaders
        self.transport!.delegate = self;
    }
    
    deinit {
        pendingSubscriptionSchedule.invalidate()
    }
    
    // MARK: Client
    open func connectToServer() {
        if self.connectionInitiated != true {
            self.transport?.openConnection()
            self.connectionInitiated = true;
            print("Faye: Connection initiated")
        } else {
            print("Faye: Connection established")
        }
    }
    
    open func disconnectFromServer() {
        unsubscribeAllSubscriptions()
        
        self.disconnect()
    }
    
    open func sendMessage(_ messageDict: NSDictionary, channel:String) {
        self.publish(messageDict as! Dictionary, channel: channel)
    }
    
    open func sendMessage(_ messageDict: [String:AnyObject], channel:String) {
        self.publish(messageDict, channel: channel)
    }
    
    open func sendPing(_ data: Data, completion: (() -> ())?) {
        writeOperationQueue.async { [unowned self] in
            self.transport?.sendPing(data, completion: completion)
        }
    }
    
    open func subscribeToChannel(_ model:FayeSubscriptionModel, block:ChannelSubscriptionBlock?=nil) -> FayeSubscriptionState {
        guard !self.isSubscribedToChannel(model.subscription) else {
            return .subscribed(model)
        }
        
        guard !self.pendingSubscriptions.contains(where: { $0 == model }) else {
            return .pending(model)
        }
        
        if let block = block {
            self.channelSubscriptionBlocks[model.subscription] = block;
        }
        
        if self.fayeConnected == false {
            self.queuedSubscriptions.append(model)
            
            return .queued(model)
        }
        
        self.subscribe(model)
        
        return .subscribingTo(model)
    }
    
    open func subscribeToChannel(_ channel:String, block:ChannelSubscriptionBlock?=nil) -> FayeSubscriptionState {
        return subscribeToChannel(
            FayeSubscriptionModel(subscription: channel, channel: .Subscribe, clientId: fayeClientId),
            block: block
        )
    }
    
    open func unsubscribeFromChannel(_ channel:String) {
        _ = removeChannelFromQueuedSubscriptions(channel)
        
        self.unsubscribe(channel)
        self.channelSubscriptionBlocks[channel] = nil;
        
        _ = removeChannelFromOpenSubscriptions(channel)
        _ = removeChannelFromPendingSubscriptions(channel)
    }
}
