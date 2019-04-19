//
//  VirgilHelper+Encryption.swift
//  VirgilMessenger
//
//  Created by Yevhen Pyvovarov on 3/26/19.
//  Copyright © 2019 VirgilSecurity. All rights reserved.
//

import VirgilSDK
import VirgilCrypto
import VirgilSDKRatchet
import VirgilCryptoRatchet

extension VirgilHelper {
    private func getSessionAsSender(card: Card) throws -> SecureSession {
        guard let session = secureChat.existingSession(withParticpantIdentity: card.identity) else {
            return try secureChat.startNewSessionAsSender(receiverCard: card).startSync().getResult()
        }

        return session
    }

    private func getSessionAsReceiver(message: RatchetMessage, receiverCard card: Card) throws -> SecureSession {
        guard let session = secureChat.existingSession(withParticpantIdentity: card.identity) else {
            return try secureChat.startNewSessionAsReceiver(senderCard: card, ratchetMessage: message)
        }

        return session
    }

    public func getGroupInitMessage(_ cards: [Card]) throws -> RatchetGroupMessage {
        return try self.secureChat.startNewGroupSession(with: cards)
    }

    // FIXME
    func encrypt(_ text: String, cards: [Card] = []) throws -> String {
        let cards = cards.isEmpty ? self.channelCards : cards

        guard !cards.isEmpty else {
            Log.error("Virgil: Channel Card not found")
            throw NSError()
        }

        let session = try self.getSessionAsSender(card: cards.first!)

        let ratchetMessage = try session.encrypt(string: text)

        return ratchetMessage.serialize().base64EncodedString()
    }

    func decrypt(_ encrypted: String, withCard: Card? = nil) throws -> String {
        guard let data = Data(base64Encoded: encrypted) else {
            Log.error("Converting utf8 string to data failed")
            throw NSError()
        }

        let tryCard: Card?
        if let receiverCard = withCard {
            tryCard = receiverCard
        } else {
            tryCard = self.channelCards.first
        }

        guard let card = tryCard else {
            Log.error("No card")
            throw NSError()
        }

        let ratchetMessage = try RatchetMessage.deserialize(input: data)

        let session = try self.getSessionAsReceiver(message: ratchetMessage, receiverCard: card)

        return try session.decryptString(from: ratchetMessage)
    }
}
