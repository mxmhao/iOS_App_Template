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

extension UIImage {
    // 生成圆角矩形图片，可拉伸
    static func resizableRoundedRectImage(size: CGSize, color: UIColor, cornerRadius: CGFloat) -> UIImage? {
        let image = UIGraphicsImageRenderer(size: size).image { context in
            // 设置抗锯齿
            context.cgContext.setAllowsAntialiasing(true)
            context.cgContext.setShouldAntialias(true)
            // 高质量插值计算
            context.cgContext.interpolationQuality = .high
            let path = UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size.width, height: size.height), cornerRadius: cornerRadius)
            path.addClip()
            color.setFill()
            path.fill() // 区域内填充
        }
        return image.resizableImage(withCapInsets: UIEdgeInsets(top: 0, left: cornerRadius, bottom: 0, right: cornerRadius), resizingMode: .stretch)
    }
}
