//
//  Ejabberd.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 27.12.2019.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import XMPPFrameworkSwift

class Ejabberd: NSObject, XMPPStreamDelegate {
    private(set) static var shared: Ejabberd = Ejabberd()

    private let delegateQueue = DispatchQueue(label: "EjabberdDelegate")

    internal let stream: XMPPStream = XMPPStream()
    internal var error: Error?
    internal let initializeMutex: Mutex = Mutex()
    internal let sendMutex: Mutex = Mutex()
    internal var state: State = .disconnected
    internal var shouldRetry: Bool = true

    internal let upload = XMPPHTTPFileUpload()
    internal let deliveryReceipts = XMPPMessageDeliveryReceipts()
    internal let readReceipts = XMPPMessageReadReceipts()

    private let uploadJid: XMPPJID = XMPPJID(string: "upload.\(URLConstants.ejabberdHost)")!

    static var updatedPushToken: Data?

    internal let serviceErrorDomain: String = "EjabberdErrorDomain"

    override init() {
        super.init()

        self.stream.hostName = URLConstants.ejabberdHost
        self.stream.hostPort = URLConstants.ejabberdHostPort
        self.stream.startTLSPolicy = .allowed
        self.stream.addDelegate(self, delegateQueue: self.delegateQueue)

        self.upload.activate(self.stream)

        self.deliveryReceipts.activate(self.stream)
        self.deliveryReceipts.autoSendMessageDeliveryRequests = true
        self.deliveryReceipts.addDelegate(self, delegateQueue: self.delegateQueue)

        self.readReceipts.activate(self.stream)
        self.readReceipts.autoSendMessageReadRequests = true
        self.readReceipts.addDelegate(self, delegateQueue: self.delegateQueue)

        try? self.initializeMutex.lock()
        try? self.sendMutex.lock()
    }

    internal func checkError() throws {
        if let error = self.error {
            throw error
        }
    }

    internal func unlockMutex(_ mutex: Mutex, with error: Error? = nil) {
        do {
            self.error = error
            try mutex.unlock()
        }
        catch {
            Log.error(error, message: "Unlocking mutex failed")
        }
    }

    public static func setupJid(with username: String) throws -> XMPPJID {
        let jidString = "\(username)@\(URLConstants.ejabberdHost)"

        guard let jid = XMPPJID(string: jidString) else {
            throw EjabberdError.jidFormingFailed
        }

        return jid
    }

    public func requestMediaSlot(name: String, size: Int) throws -> CallbackOperation<XMPPSlot> {
        return CallbackOperation { _, completion in
            self.upload.requestSlot(fromService: self.uploadJid,
                                    filename: name,
                                    size: UInt(size),
                                    contentType: "image/png")
            { (slot, iq, error) in
                completion(slot, error)
            }
        }
    }
}
