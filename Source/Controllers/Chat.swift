/*
 The MIT License (MIT)

 Copyright (c) 2015-present Badoo Trading Limited.

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
*/

import UIKit
import Chatto
import ChattoAdditions
import AVFoundation
import PKHUD

class ChatViewController: BaseChatViewController {
    @IBOutlet weak var avatarView: GradientView!
    @IBOutlet weak var avatarLetterLabel: UILabel!

    private let indicator = UIActivityIndicatorView()
    private let indicatorLabel = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 21))

    public var channel: Storage.Channel!

    private var soundPlayer: AVAudioPlayer?
    weak private var cachedAudioModel: UIAudioMessageViewModel?

    private var statusBarHidden: Bool = false {
        didSet {
            self.setNeedsStatusBarAppearanceUpdate()
        }
    }

    override var prefersStatusBarHidden: Bool {
        return statusBarHidden
    }

    lazy private var dataSource: DataSource = {
        let dataSource = DataSource(channel: self.channel)
        self.chatDataSource = dataSource
        return dataSource
    }()

    lazy private var baseMessageHandler: BaseMessageHandler = {
         return BaseMessageHandler(messageSender: self.dataSource.messageSender)
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        super.chatItemsDecorator = ChatItemsDemoDecorator()

        super.inputContainer.backgroundColor = .appThemeBackgroundColor
        super.bottomSpaceView.backgroundColor = .appThemeBackgroundColor
        super.collectionView?.backgroundColor = .appThemeForegroundColor

        self.avatarLetterLabel.text = self.channel.letter
        self.avatarView.draw(with: self.channel.colors)

        self.setupIndicator()
        self.updateTitle()

        self.setupObservers()
        self.dataSource.setupObservers()

        self.updateUnreadState()
    }

    deinit {
        Storage.shared.deselectChannel(self.channel)
    }

    private func updateUnreadState() {
        do {
            if self.channel.unreadCount > 0 {
                try Ejabberd.shared.sendGlobalReadReceipt(to: self.channel.name)
            }

            try Storage.shared.resetUnreadCount(for: self.channel)
        }
        catch {
            Log.error(error, message: "Chat viewDidLoad failed")
        }
    }

    private func setupObservers() {
        let popToRoot: Notifications.Block = { [weak self] _ in
            DispatchQueue.main.async {
                self?.popToRoot()
            }
        }

        let updateTitle: Notifications.Block = { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateTitle()
            }
        }

        Notifications.observe(for: .connectionStateChanged, block: updateTitle)
        Notifications.observe(for: .currentChannelDeleted, block: popToRoot)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if let rootVC = navigationController?.viewControllers.first {
            navigationController?.viewControllers = [rootVC, self]
        }
    }

    private func setupIndicator() {
        self.indicator.hidesWhenStopped = false
        self.indicatorLabel.textColor = .white
        self.indicatorLabel.text = "Connecting"
    }

    private func updateTitle() {
        switch Ejabberd.shared.state {
        case .connected:
            self.indicator.stopAnimating()

            let titleButton = UIButton(type: .custom)
            titleButton.frame = CGRect(x: 0, y: 0, width: 200, height: 21)
            titleButton.tintColor = .white
            titleButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 16.0)
            titleButton.setTitle(self.channel.name, for: .normal)

            let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(showChatInfo(_:)))
            titleButton.addGestureRecognizer(tapRecognizer)

            self.navigationItem.titleView = titleButton

        case .connecting, .disconnected:
            guard !self.indicator.isAnimating else {
                return
            }

            self.indicator.startAnimating()

            let progressView = UIStackView(arrangedSubviews: [self.indicator, self.indicatorLabel])
            progressView.spacing = 5

            self.navigationItem.titleView = progressView
        }
    }

    @IBAction func showChatInfo(_ sender: Any) {
        self.perform(segue: .toChatInfo)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let chatInfo = segue.destination as? ChatInfoViewController {
            chatInfo.channel = self.channel
        }

        self.view.endEditing(true)

        super.prepare(for: segue, sender: sender)
    }

    var chatInputPresenter: BasicChatInputBarPresenter!

    override func createChatInputView() -> UIView {
        let chatInputView = InputBar.loadNib()
        var appearance = ChatInputBarAppearance()

        appearance.textInputAppearance.textColor = .white
        appearance.textInputAppearance.font = appearance.textInputAppearance.font.withSize(CGFloat(20))
        appearance.sendButtonAppearance.titleColors = [UIControlStateWrapper(state: .disabled): UIColor(rgb: 0x585A60)]
        appearance.sendButtonAppearance.font = appearance.textInputAppearance.font

        appearance.sendButtonAppearance.title = NSLocalizedString("Send", comment: "")
        appearance.textInputAppearance.placeholderText = NSLocalizedString("Message...", comment: "")
        appearance.textInputAppearance.placeholderFont = appearance.textInputAppearance.font

        self.chatInputPresenter = BasicChatInputBarPresenter(chatInputBar: chatInputView,
                                                             chatInputItems: self.createChatInputItems(),
                                                             chatInputBarAppearance: appearance)

        chatInputView.maxCharactersCount = ChatConstants.chatMaxCharectersCount

        return chatInputView
    }

    override func createPresenterBuilders() -> [ChatItemType: [ChatItemPresenterBuilderProtocol]] {
        let chatColor = BaseMessageCollectionViewCellDefaultStyle.Colors(
            incoming: .appThemeBackgroundColor, // background
            outgoing: UIColor(rgb: 0x4A4E58)
        )

        // used for base message background + text background
        let baseMessageStyle = BaseMessageCollectionViewCellDefaultStyle(colors: chatColor)

        return [
            UITextMessageModel.chatItemType: [self.createTextPresenter(with: baseMessageStyle)],
            UIPhotoMessageModel.chatItemType: [self.createPhotoPresenter(with: baseMessageStyle)],
            UIAudioMessageModel.chatItemType: [self.createAudioPresenter(with: baseMessageStyle)],
            SendingStatusModel.chatItemType: [SendingStatusPresenterBuilder()],
            TimeSeparatorModel.chatItemType: [TimeSeparatorPresenterBuilder()]
        ]
    }

    func createChatInputItems() -> [ChatInputItemProtocol] {
        var items = [ChatInputItemProtocol]()
        items.append(self.createTextInputItem())
        items.append(self.createPhotoInputItem())
        items.append(self.createAudioInputItem())

        return items
    }
}

/// Presenters creators
extension ChatViewController {
    private func createTextPresenter(with baseMessageStyle: BaseMessageCollectionViewCellDefaultStyle) -> TextMessagePresenterBuilder<UITextMessageViewModelBuilder, UITextMessageHandler> {
        let textStyle = TextMessageCollectionViewCellDefaultStyle.TextStyle(
            font: UIFont.systemFont(ofSize: 15),
            incomingColor: UIColor(rgb: 0xE4E4E4),
            outgoingColor: UIColor.white, //for outgoing
            incomingInsets: UIEdgeInsets(top: 10, left: 19, bottom: 10, right: 15),
            outgoingInsets: UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 19)
        )

        let textCellStyle: TextMessageCollectionViewCellDefaultStyle = TextMessageCollectionViewCellDefaultStyle(
            textStyle: textStyle,
            baseStyle: baseMessageStyle) // without baseStyle, you won't have the right background

        let textMessagePresenter = TextMessagePresenterBuilder(
            viewModelBuilder: UITextMessageViewModelBuilder(),
            interactionHandler: UITextMessageHandler(baseHandler: self.baseMessageHandler)
        )

        textMessagePresenter.baseMessageStyle = baseMessageStyle
        textMessagePresenter.textCellStyle = textCellStyle

        return textMessagePresenter
    }

    private func createPhotoPresenter(with baseMessageStyle: BaseMessageCollectionViewCellDefaultStyle) -> PhotoMessagePresenterBuilder<UIPhotoMessageViewModelBuilder, UIPhotoMessageHandler> {
        let photoMessagePresenter = PhotoMessagePresenterBuilder(
            viewModelBuilder: UIPhotoMessageViewModelBuilder(),
            interactionHandler: UIPhotoMessageHandler(baseHandler: self.baseMessageHandler,
                                                      photoObserverController: self)
        )
        photoMessagePresenter.baseCellStyle = baseMessageStyle

        return photoMessagePresenter
    }

    private func createAudioPresenter(with baseMessageStyle: BaseMessageCollectionViewCellDefaultStyle) -> AudioMessagePresenterBuilder<UIAudioMessageViewModelBuilder, UIAudioMessageHandler> {
        let audioTextStyle = AudioMessageCollectionViewCellDefaultStyle.TextStyle(
            font: UIFont.systemFont(ofSize: 15),
            incomingColor: UIColor(rgb: 0xE4E4E4),
            outgoingColor: UIColor.white, //for outgoing
            incomingInsets: UIEdgeInsets(top: 10, left: 19, bottom: 10, right: 15),
            outgoingInsets: UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 19)
        )

        let audioTextCellStyle: AudioMessageCollectionViewCellDefaultStyle = AudioMessageCollectionViewCellDefaultStyle(
            textStyle: audioTextStyle,
            baseStyle: baseMessageStyle) // without baseStyle, you won't have the right background

        let interactionHandler = UIAudioMessageHandler(baseHandler: self.baseMessageHandler, playableController: self)

        let audioMessagePresenter = AudioMessagePresenterBuilder(viewModelBuilder: UIAudioMessageViewModelBuilder(),
                                                                 interactionHandler: interactionHandler)

        audioMessagePresenter.baseMessageStyle = baseMessageStyle
        audioMessagePresenter.textCellStyle = audioTextCellStyle

        return audioMessagePresenter
    }
}

/// ChatInputItems creators
extension ChatViewController {
    private func createTextInputItem() -> TextChatInputItem {
        let item = TextChatInputItem()

        item.textInputHandler = { [weak self] text in
            guard
                self?.checkReachability() ?? false,
                Ejabberd.shared.state == .connected
            else {
                throw NSError(domain: "ChatViewDomain", code: -1, userInfo: [NSLocalizedDescriptionKey: "No connection"])
            }

            if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self?.dataSource.addTextMessage(text)
            }
        }

        return item
    }

    private func createPhotoInputItem() -> UIPhotosChatInputItem {
        var liveCamaraAppearence = LiveCameraCellAppearance.createDefaultAppearance()
        liveCamaraAppearence.backgroundColor = .appThemeForegroundColor
        let photosAppearence = PhotosInputViewAppearance(liveCameraCellAppearence: liveCamaraAppearence)
        let item = UIPhotosChatInputItem(presentingController: self,
                                         tabInputButtonAppearance: PhotosChatInputItem.createDefaultButtonAppearance(),
                                         inputViewAppearance: photosAppearence)

        item.photoInputHandler = { [weak self] image in
            if self?.checkReachability() ?? false, Ejabberd.shared.state == .connected {
                self?.dataSource.addPhotoMessage(image)
            }
        }
        return item
    }

    private func createAudioInputItem() -> AudioChatInputItem {
        let item = AudioChatInputItem(presentingController: self)

        item.audioInputHandler = { [weak self] audioUrl, duration in
            if self?.checkReachability() ?? false, Ejabberd.shared.state == .connected {
                self?.dataSource.addVoiceMessage(audioUrl, duration: duration)
            }
        }

        return item
    }
}

extension ChatViewController: AudioPlayableProtocol {
    func play(model: UIAudioMessageViewModel) {
        // TODO: error handling
        try? AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)

        do {
            self.soundPlayer = try AVAudioPlayer(contentsOf: model.audioUrl)
            self.soundPlayer?.delegate = self
            self.soundPlayer?.prepareToPlay()
            self.soundPlayer?.volume = 1.0
            self.soundPlayer?.play()

            if let audioModel = self.cachedAudioModel {
                audioModel.state.value = .stopped
            }
            self.cachedAudioModel = model
        }
        catch {
            Log.error(error, message: "AVAudioPlayer playing error")
            self.alert(UserFriendlyError.playingError)
        }
    }

    func pause() {
        self.soundPlayer?.pause()
    }

    func resume() {
        self.soundPlayer?.prepareToPlay()
        self.soundPlayer?.play()
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.cachedAudioModel?.state.value = .stopped
        self.cachedAudioModel = nil
    }
}

extension ChatViewController: PhotoObserverProtocol {
    func showImage(_ image: UIImage) {
        self.view.endEditing(true)

        let newImageView = UIImageView()
        newImageView.backgroundColor = .black
        newImageView.frame = UIScreen.main.bounds
        newImageView.contentMode = .scaleAspectFit
        newImageView.image = image
        newImageView.isUserInteractionEnabled = true

        let tap = UITapGestureRecognizer(target: self, action: #selector(dismissFullscreenImage))
        newImageView.addGestureRecognizer(tap)

        self.view.addSubview(newImageView)
        self.navigationController?.isNavigationBarHidden = true
        self.statusBarHidden = true
    }

    @objc private func dismissFullscreenImage(_ sender: UITapGestureRecognizer) {
        self.navigationController?.isNavigationBarHidden = false
        sender.view?.removeFromSuperview()
        self.statusBarHidden = false
    }

    func showSaveImageAlert(_ image: UIImage) {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)

        let saveAction = UIAlertAction(title: "Save to Camera Roll", style: .default) { _ in
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(self.image(_:didFinishSavingWithError:contextInfo:)), nil)
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)

        alert.addAction(saveAction)
        alert.addAction(cancelAction)

        self.present(alert, animated: true)
    }

    @objc func image(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer) {
        if let error = error {
            let ac = UIAlertController(title: "Save error",
                                       message: error.localizedDescription,
                                       preferredStyle: .alert)
            ac.addAction(UIAlertAction(title: "OK", style: .default))

            self.present(ac, animated: true)
        }
        else {
            HUD.flash(.success)
        }
    }
}
