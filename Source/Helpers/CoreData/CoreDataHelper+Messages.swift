//
//  CoreDataHelper+Messages.swift
//  VirgilMessenger
//
//  Created by Eugen Pivovarov on 2/20/18.
//  Copyright © 2018 VirgilSecurity. All rights reserved.
//

import CoreData
import VirgilCryptoRatchet
import VirgilSDK

extension CoreDataHelper {
    private func save(_ message: Message) throws {
        let messages = message.channel.mutableOrderedSetValue(forKey: Channel.MessagesKey)
        messages.add(message)

        try self.appDelegate.saveContext()
    }

    func save(_ message: ServiceMessage, to channel: Channel) throws {
        let messages = channel.mutableOrderedSetValue(forKey: Channel.ServiceMessagesKey)
        messages.add(message)

        try self.appDelegate.saveContext()
    }

    func createChangeMembersMessage(_ serviceMessage: ServiceMessage,
                                    in channel: Channel? = nil,
                                    isIncoming: Bool,
                                    date: Date = Date()) throws -> Message {
        guard let channel = channel ?? self.currentChannel else {
            throw CoreDataHelperError.nilCurrentChannel
        }

        let message = try Message(body: serviceMessage.getChangeMembersText(),
                                  type: .changeMembers,
                                  isIncoming: isIncoming,
                                  date: date,
                                  channel: channel,
                                  managedContext: self.managedContext)

        try self.save(message)

        return message
    }

    func createEncryptedMessage(in channel: Channel, isIncoming: Bool, date: Date) throws -> Message {
        let message = try Message(body: "Message encrypted",
                                  type: .text,
                                  isIncoming: isIncoming,
                                  date: date,
                                  channel: channel,
                                  managedContext: self.managedContext)

        try self.save(message)

        return message
    }

    func createTextMessage(_ body: String,
                           in channel: Channel? = nil,
                           isIncoming: Bool,
                           date: Date = Date()) throws -> Message {
        guard let channel = channel ?? self.currentChannel else {
            throw CoreDataHelperError.nilCurrentChannel
        }

        let message = try Message(body: body,
                                  type: .text,
                                  isIncoming: isIncoming,
                                  date: date,
                                  channel: channel,
                                  managedContext: self.managedContext)

        try self.save(message)

        return message
    }

    func createMediaMessage(_ data: Data,
                            in channel: Channel? = nil,
                            isIncoming: Bool,
                            date: Date = Date(),
                            type: MessageType) throws -> Message {
        guard let channel = channel ?? self.currentChannel else {
            throw CoreDataHelperError.nilCurrentChannel
        }

        let message = try Message(media: data,
                                  type: type,
                                  isIncoming: isIncoming,
                                  date: date,
                                  channel: channel,
                                  managedContext: self.managedContext)

        try self.save(message)

        return message
    }

    func findServiceMessage(from identity: String, withSessionId sessionId: Data, identifier: String? = nil) throws -> ServiceMessage? {
        guard identity != self.currentAccount?.identity else {
            return nil
        }

        guard let user = self.getSingleChannel(with: identity) else {
            throw CoreDataHelperError.channelNotFound
        }

        return user.serviceMessages.first { $0.message.getSessionId() == sessionId && $0.identifier == identifier }
    }

    func serviceMessagesCount(from identity: String, withSessionId sessionId: Data) -> Int {
        guard let user = self.getSingleChannel(with: identity) else {
            return 0
        }

        return user.serviceMessages.filter { $0.message.getSessionId() == sessionId }.count
    }

    func delete(_ serviceMessage: ServiceMessage) throws {
        self.managedContext.delete(serviceMessage)

        try self.appDelegate.saveContext()
    }
}
