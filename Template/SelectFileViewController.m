//
//  ViewController.m
//  iOS_App_Template
//
//  Created by mxm on 2023/10/1.
//  Copyright © 2023 mxm. All rights reserved.
//

#import <UIKit/UIKit.h>

@import UniformTypeIdentifiers;

@interface UIViewController (SelectFile) <UIDocumentPickerDelegate>

@end

@implementation UIViewController (SelectFile)

- (void)selectFile
{
    UIDocumentPickerViewController *vc;
    if (@available(iOS 14.0, *)) {
        vc = [[UIDocumentPickerViewController alloc] initForOpeningContentTypes:@[
            [UTType typeWithFilenameExtension:@"zip"],
            [UTType typeWithFilenameExtension:@"txt"]
        ]];
    } else {
        // 官方类型：https://developer.apple.com/library/archive/documentation/Miscellaneous/Reference/UTIRef/Articles/System-DeclaredUniformTypeIdentifiers.html#//apple_ref/doc/uid/TP40009259-SW1
        // 如果类型找不到或不知道怎么填，可以在高版本上这么打印:
        // NSLog(@"%@", [UTType typeWithFilenameExtension:@"apk"]);
        // 根据后缀打印得到的就是类型
        vc = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[
            @"public.data",
            @"public.text"] inMode:UIDocumentPickerModeImport];
    }
    vc.delegate = self;
    if (@available(iOS 13.0, *)) {
        vc.shouldShowFileExtensions = YES;
    }
    [self presentViewController:vc animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray <NSURL *>*)urls
{
    [controller dismissViewControllerAnimated:YES completion:NULL];
    NSURL *url = urls.firstObject;
    BOOL fileUrlAuthozied = [url startAccessingSecurityScopedResource];
    if (!fileUrlAuthozied) {
        // 授权失败
        return;
    }
    
    // 通过文件协调工具来得到新的文件地址，以此得到文件保护功能
    NSFileCoordinator *fileCoordinator = [NSFileCoordinator new];
    NSError *error;
    __weak __typeof(self) weakSelf = self;
    [fileCoordinator coordinateReadingItemAtURL:url options:kNilOptions error:&error byAccessor:^(NSURL *newURL) {
        __strong __typeof(weakSelf) self = weakSelf;
        if (nil == self) return;
        
        // 把 newURL 传递给你要用到的地方，注意，不能使用 newURL.absoluteString 获取文件，必须用newURL获取文件，否则获取不到文件
        
        // 获取文件信息
        NSDictionary *fileAttr = [NSFileManager.defaultManager attributesOfItemAtPath:newURL.path error:nil];
        // 文件大小
        NSUInteger fileSize = [fileAttr fileSize];
        // 文件流
        [NSInputStream inputStreamWithURL:newURL];
    }];
    [url stopAccessingSecurityScopedResource];
}

@end
