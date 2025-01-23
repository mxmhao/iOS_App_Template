//
//  SwiftTemplate.swift
//  iOS_App_Template
//
//  Created by macmini on 2025/1/9.
//  Copyright © 2025 mxm. All rights reserved.
//

import UIKit

extension UIButton {
    /*
     给 storyboard 或者 xib 添加可设置国际化key，而不是将 storyboard 或者 xib 直接国际化，
     方便国际化 Localizable.strings 文件的管理。
     可以在 storyboard 或者 xib 的 属性面板上看到此填空
     */
    @IBInspectable public var normalTitleLocalizedKey: String {
        get {
            return ""
        }
        set {
            setTitle(NSLocalizedString(newValue, comment: ""), for: .normal)
        }
    }
}

extension UILabel {
    // 给 storyboard 或者 xib 添加可设置国际化key
    @IBInspectable public var textLocalizedKey: String {
        get {
            return ""
        }
        set {
            text = NSLocalizedString(newValue, comment: "")
        }
    }
}

extension UIViewController {
    func adjustNavigationBarAppearance() {
        let barBgColor = UIColor(named: "view_bg")!
        let titleColor = UIColor(named: "title1_color")!
        let titleTextAttributes = [NSAttributedString.Key.foregroundColor : titleColor]
        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = barBgColor
            // 设置title颜色
            appearance.titleTextAttributes = titleTextAttributes;
//            let itemAppearance = UIBarButtonItemAppearance(style: .plain)
//            itemAppearance.normal.titleTextAttributes = titleTextAttributes
//            appearance.backButtonAppearance = itemAppearance
            navigationController?.navigationBar.standardAppearance = appearance
            navigationController?.navigationBar.scrollEdgeAppearance = appearance
        } else {
            navigationController?.navigationBar.titleTextAttributes = titleTextAttributes
            navigationController?.navigationBar.barTintColor = barBgColor
        }
        // 设置item的颜色，包括字体颜色和图片颜色: topItem, backItem, rightBarButtonItem
        navigationController?.navigationBar.tintColor = titleColor
    }
}
