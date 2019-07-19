//
//  TableViewCellAutoCalculate.m
//  
//
//  Created by mxm on 2018/7/17.
//  Copyright © 2016 mxm. All rights reserved.
//  cell高度自适应

#import <UIKit/UIKit.h>

@interface TableViewCellAutoCalculate : UIViewController <UITableViewDataSource, UITableViewDelegate>
{
    UITableView *_tableView;
}

@end

@implementation TableViewCellAutoCalculate

- (void)viewDidLoad
{
    [super viewDidLoad];
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _tableView.frame = self.view.bounds;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    _tableView.estimatedRowHeight = 44;  //这样设置可以让cell去自适应内容的高度, 配合autolayout，也能自适应高度；不宜过大或者过小，最好是一个大概的平均值
//    tableView.rowHeight = UITableViewAutomaticDimension;
    [self.view addSubview:_tableView];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 5;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identifier = @"";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
    if (nil == cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:identifier];
        cell.textLabel.numberOfLines = 0;
    }
    
    NSMutableString *txt = [NSMutableString stringWithString:@"沙悟净尬舞我；埃里克是点击发；历史的积分"];
    for (int i = 0; i < indexPath.row; ++i) {
        [txt appendString:@"沙悟净尬舞我；埃里克是点击发；历史的积分爱上"];
    }
    cell.textLabel.text = txt;
    
    //要视图自适应内容
//    [cell.contentView systemLayoutSizeFittingSize: UILayoutFittingCompressedSize];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView estimatedHeightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return 44.0;//过大过小都不行
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{//若不在当前方法线程中执行delete操作时，tableView的cell会有跳动bug，这个应该是系统bug，是autolayout产生的bug，固定cell的高度，不会有bug，esimatedRowHeight过大或者过小都有bug
    
    dispatch_async(dispatch_get_main_queue(), ^(void) {//测试tableView跳动bug
        [_tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
    });
}

@end
