//
//  ViewController.swift
//  Morse
//
//  Created by Oleksandr Deundiak on 10/17/17.
//  Copyright © 2017 VirgilSecurity. All rights reserved.
//

import UIKit
import CoreData

class ViewController: UIViewController {
    var topBarHeight: CGFloat {
        let statusBarHeight = UIApplication.shared.statusBarFrame.size.height
        let navBarHeight = self.navigationController?.navigationBar.frame.height ?? 0.0
        let offset = self.navigationController?.navigationBar.frame.origin.y ?? 0.0
        
        return statusBarHeight + navBarHeight + offset
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    var isRootViewController: Bool {
        return self.navigationController?.viewControllers.count ?? 1 == 1
    }

    deinit {
        Log.debug(self.description)
    }

    func switchNavigationStack(to name: String) {
        let storyboard = UIStoryboard(name: name, bundle: Bundle.main)
        let controller = storyboard.instantiateInitialViewController() as! UINavigationController

        let window = UIApplication.shared.keyWindow!
        window.rootViewController = controller

        UIView.transition(with: window,
                          duration: UIConstants.TransitionAnimationDuration,
                          options: .transitionCrossDissolve,
                          animations: nil)
    }
}
