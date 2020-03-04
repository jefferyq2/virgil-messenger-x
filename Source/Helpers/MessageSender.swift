import Chatto
import ChattoAdditions
import VirgilSDK
import XMPPFrameworkSwift

public protocol UIMessageModelProtocol: MessageModelProtocol {
    var status: MessageStatus { get set }
}

public class MessageSender {
    public var onMessageChanged: ((_ message: UIMessageModelProtocol) -> Void)?

    private let queue = DispatchQueue(label: "MessageSender")

    public func send(uiModel: UITextMessageModel, coreChannel: Channel, type: XMPPMessage.MessageType) throws {
        self.queue.async {
            do {
                let plaintext = uiModel.body

                let ciphertext: String

                switch coreChannel.type {
                case .group:
                    let group = try coreChannel.getGroup()

                    ciphertext = try group.encrypt(text: plaintext)
                case .single:
                    ciphertext = try Virgil.ethree.authEncrypt(text: plaintext, for: coreChannel.getCard())
                }

                let encryptedMessage = EncryptedMessage(ciphertext: ciphertext, date: uiModel.date)

                try Ejabberd.shared.send(encryptedMessage, to: coreChannel.name, type: type)

                _ = try CoreData.shared.createTextMessage(plaintext,
                                                          in: coreChannel,
                                                          isIncoming: uiModel.isIncoming,
                                                          date: uiModel.date)

                self.updateMessage(uiModel, status: .success)
            }
            catch {
                self.updateMessage(uiModel, status: .failed)
            }
        }
    }

    private func updateMessage(_ message: UIMessageModelProtocol, status: MessageStatus) {
        if message.status != status {
            message.status = status
            self.notifyMessageChanged(message)
        }
    }

    private func notifyMessageChanged(_ message: UIMessageModelProtocol) {
        DispatchQueue.main.async {
            self.onMessageChanged?(message)
        }
    }
}
