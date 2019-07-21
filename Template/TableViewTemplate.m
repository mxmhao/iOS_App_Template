//
//  TableViewTemplate.m
//
//  Created by mxm on 2017/5/13.
//  Copyright © 2017年 mxm. All rights reserved.
//
//  tableView模板使用

#import <UIKit/UIKit.h>

@interface TableViewTemplate: UIViewController <UITableViewDataSource, UITableViewDelegate, UIActionSheetDelegate>

@end

@implementation TableViewTemplate
{
    
    UITableView *_tableView;
    NSArray *_arr;
    UIBarButtonItem *_selectAllItem;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    if (!_tableView.editing) {//不编辑的时候
        self.toolbarItems = nil;
        _selectAllItem = nil;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(pushToAdd)];
    
    _tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStyleGrouped];
    _tableView.dataSource = self;
    _tableView.delegate = self;
    _tableView.sectionFooterHeight = 0;
    _tableView.estimatedSectionHeaderHeight = 20;
    _tableView.allowsMultipleSelectionDuringEditing = YES;//用系统的多选形式
    [self.view addSubview:_tableView];
    
    _arr = @[@"老大", @"12312"];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.navigationController setToolbarHidden:YES animated:NO];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self cancelAction];
}

- (void)pushToAdd {}

- (void)showEditing
{
    if (_tableView.isEditing) return;
    if (nil == self.toolbarItems) {
        UIBarButtonItem *deleteItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash target:self action:@selector(deletePrompt)];
        UIBarButtonItem *spaceItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];//自动调节间距
        _selectAllItem = [[UIBarButtonItem alloc] initWithTitle:@"全选" style:UIBarButtonItemStylePlain target:self action:@selector(selectAllCell)];
        self.toolbarItems = @[_selectAllItem, spaceItem, deleteItem];
    } else {
        _selectAllItem.title = @"全选";
    }
    
    _tableView.editing = YES;
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancelAction)];
    [self.navigationController setToolbarHidden:NO animated:YES];
    
    [_tableView reloadData];
}

- (void)cancelAction
{
    _tableView.editing = NO;
    self.navigationItem.rightBarButtonItem = nil;
    [_tableView reloadData];
    
    [self.navigationController setToolbarHidden:YES animated:YES];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(pushToAdd)];
}

//删除多个前的提示
- (void)deletePrompt
{
    NSUInteger count = _tableView.indexPathsForSelectedRows.count;
    if (0 == count) return;
    //这里写自定义逻辑
}

//全选
- (void)selectAllCell
{
    NSUInteger count = _arr.count;
    if (_tableView.indexPathsForSelectedRows.count != count) {//不是全选
        for (int i = 0; i < count; ++i) {
            [_tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:i inSection:0] animated:YES scrollPosition:UITableViewScrollPositionNone];
        }
        _selectAllItem.title = @"取消全选";
    } else {
        [_tableView reloadData];
        _selectAllItem.title = @"全选";
    }
}

#pragma mark - tableview代理
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _arr.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *identify = @"kIdentify";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identify];
    if (nil == cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identify];
    }
    cell.textLabel.text = _arr[indexPath.row];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!tableView.editing) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        //这里自定义逻辑
    } else {
        if (_arr.count == tableView.indexPathsForSelectedRows.count) {//已全选
            _selectAllItem.title = @"取消全选";
        }
    }
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (!tableView.isEditing) return;
    if (_arr.count != tableView.indexPathsForSelectedRows.count) {//没有全选
        _selectAllItem.title = @"全选";
    }
}

#pragma mark - Cell侧滑删除
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleDelete;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    [arr removeObjectAtIndex:indexPath.row];//删除数据
    [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationBottom];//删除行cell
}

#pragma mark - Cell长按触发
//这下面3这个方法少一个都不行，长按会触发
/*
 本来这3个方法是用来给UITableViewCell弹出Menu的，这里被我禁用了，
 只是借用了一下长按触发事件
 */
- (BOOL)tableView:(UITableView *)tableView shouldShowMenuForRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self showEditing];
    [tableView selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionNone];
    return NO;
}
- (BOOL)tableView:(UITableView *)tableView canPerformAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(nullable id)sender
{
    return NO;
}
- (void)tableView:(UITableView *)tableView performAction:(SEL)action forRowAtIndexPath:(NSIndexPath *)indexPath withSender:(nullable id)sender {}

@end
