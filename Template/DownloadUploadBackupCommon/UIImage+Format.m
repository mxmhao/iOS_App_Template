//
//  UIImage+Format.m

#import "UIImage+Format.h"
#import <Photos/Photos.h>

@implementation UIImage (Format)

//根据文件扩展名获取图片
+ (UIImage *)imageForPathExtension:(NSString *)extension
{
    if (nil == extension) return nil;
    
    extension = [extension lowercaseString];
    UIImage *image = [UIImage imageNamed:extension];
    extension = [@"." stringByAppendingString:extension];
    if (nil == image) {
        static NSDictionary<NSString *, NSArray *> *pathExt = nil;
//        static NSMutableDictionary<NSString *, NSString *> *dict = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            NSString *path = [[NSBundle mainBundle] pathForResource:@"PathExtension" ofType:@"plist"];
            pathExt = [NSDictionary dictionaryWithContentsOfFile:path];
//            dict = [NSMutableDictionary dictionaryWithCapacity:pathExt.count];
//            [pathExt enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
//                dict[key] = [((NSArray *)obj) componentsJoinedByString:@""];
//            }];
        });
        __block NSString *name = nil;
//        [dict enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSString * _Nonnull key, NSString * _Nonnull obj, BOOL * _Nonnull stop) {
//            if ([obj containsString:extension]) {
//                name = key;
//                *stop = YES;
//            }
//        }];
        [pathExt enumerateKeysAndObjectsWithOptions:NSEnumerationConcurrent usingBlock:^(NSString * _Nonnull key, NSArray * _Nonnull obj, BOOL * _Nonnull stop) {
            if ([obj containsObject:extension]) {
                name = key;
                *stop = YES;
            }
        }];
        image = [UIImage imageNamed:name];
    }
    if (nil == image) image = [UIImage imageNamed:@"unknown.png"];
    
    return image;
}

+ (BOOL)isHEIF:(PHAsset *)asset
{
    BOOL isHEIF = NO;
    if ([UIDevice currentDevice].systemVersion.floatValue > 9.0) {
        NSArray *resourceList = [PHAssetResource assetResourcesForAsset:asset];
        NSString *UTI;
        for (PHAssetResource *resource in resourceList) {
            UTI = resource.uniformTypeIdentifier;
            if ([UTI isEqualToString:AVFileTypeHEIF] || [UTI isEqualToString:AVFileTypeHEIC]) {
                isHEIF = YES;
                break;
            }
        }
    } else {
        NSString *UTI = [asset valueForKey:@"uniformTypeIdentifier"];
        isHEIF = [UTI isEqualToString:@"public.heif"] || [UTI isEqualToString:@"public.heic"];
    }
    return isHEIF;
}

@end
