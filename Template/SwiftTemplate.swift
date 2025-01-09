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
