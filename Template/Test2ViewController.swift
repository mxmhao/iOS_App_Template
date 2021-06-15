//
//  ViewController.swift
//  iOS_App_Template
//
//  Created by min on 2020/6/13.
//  Copyright © 2020 min. All rights reserved.
//
//  详细请看下面的注释

import UIKit

class Test2ViewController: UIViewController {
    let a = 123
    
//    convenience init() {//便利构造器
//        self.init()//此方法可能是从ObjC的UIKit bridge(桥接)过来的。
//        self.init(nibName: nil, bundle: nil)//用这个是不是会好点？
//        //.....
//    }
    /**
     https://swiftgg.gitbook.io/swift/swift-jiao-cheng/14_initialization#class-inheritance-and-initialization
     构造器的自动继承
     子类在默认情况下不会继承父类的构造器。但是如果满足特定条件，父类构造器是可以被自动继承的。事实上，这意味着对于许多常见场景你不必重写父类的构造器，并且可以在安全的情况下以最小的代价继承父类的构造器。
     假设你为子类中引入的所有新属性都提供了默认值，以下 2 个规则将适用：
     规则 1
        如果子类没有定义任何指定构造器，它将自动继承父类所有的指定构造器。
     规则 2
        如果子类提供了所有父类指定构造器的实现——无论是通过规则 1 继承过来的，还是提供了自定义实现——它将自动继承父类所有的便利构造器。
     即使你在子类中添加了更多的便利构造器，这两条规则仍然适用。
     注意
     子类可以将父类的指定构造器实现为便利构造器来满足规则 2。
     
     类类型的构造器代理
     为了简化指定构造器和便利构造器之间的调用关系，Swift 构造器之间的代理调用遵循以下三条规则：
     规则 1
        指定构造器必须调用其直接父类的的指定构造器。
     规则 2
        便利构造器必须调用同类中定义的其它构造器。
     规则 3
        便利构造器最后必须调用指定构造器。
     
     两段式构造过程：请查百度
     */
//    init() {
////        super.init()//根据上面👆规则，UIViewController没有继承init()方法，所以不能直接调用，而指定构造器必须调用其直接父类的的指定构造器。
////        init(name: "123")//指定构造器也不能调用自己其他的指定构造器
//        super.init(nibName: nil, bundle: nil)
////        init(name: "123")
//    }
//    required init?(coder: NSCoder) {//此方法来自NSCoding，可百度查询为什么必须重写
//        fatalError("init(coder:) has not been implemented")
//    }
//    init(name:String) {
//        super.init(nibName: nil, bundle: nil)
////        init()//指定构造器也不能调用自己其他的指定构造器
//    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let vc = Test2ViewController();//根据规则，父类没有继承init()，为啥还能用？原因可能是这个初始化方式是来自UIKit,也就是调用了ObjC下的UIViewController初始化方法，是ObjC bridge(桥接)过来的。
    }
}

