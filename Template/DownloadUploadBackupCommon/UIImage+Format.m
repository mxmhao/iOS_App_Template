//
//  UIImage+Format.m

#import "UIImage+Format.h"
#import <Photos/Photos.h>

@implementation UIImage (Format)

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
