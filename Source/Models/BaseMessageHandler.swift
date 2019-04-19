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

import Foundation
import Chatto
import ChattoAdditions

public protocol DemoMessageViewModelProtocol {
    var messageModel: DemoMessageModelProtocol { get }
}

class BaseMessageHandler {
    private let messageSender: MessageSender

    init (messageSender: MessageSender) {
        self.messageSender = messageSender
    }
    func userDidTapOnFailIcon(viewModel: DemoMessageViewModelProtocol) {
        print("userDidTapOnFailIcon")
    }

    func userDidTapOnAvatar(viewModel: MessageViewModelProtocol) {
        print("userDidTapOnAvatar")
    }

    func userDidTapOnBubble(viewModel: DemoMessageViewModelProtocol) {
        print("userDidTapOnBubble")
    }

    func userDidBeginLongPressOnBubble(viewModel: DemoMessageViewModelProtocol) {
        print("userDidBeginLongPressOnBubble")
    }

    func userDidEndLongPressOnBubble(viewModel: DemoMessageViewModelProtocol) {
        print("userDidEndLongPressOnBubble")
    }
}
