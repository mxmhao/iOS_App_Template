//
//  UIImage+Format.h

#import <UIKit/UIKit.h>

@class PHAsset;

@interface UIImage (Format)

+ (BOOL)isHEIF:(PHAsset *)asset;

@end
