//
//  UIImage+Format.h

#import <UIKit/UIKit.h>

@class PHAsset;

@interface UIImage (Format)

+ (UIImage *)imageForPathExtension:(NSString *)extension;

+ (BOOL)isHEIF:(PHAsset *)asset;

@end
