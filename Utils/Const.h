//
//  Const.h

#ifndef Const_h
#define Const_h

#pragma mark - 空判断
NS_INLINE
BOOL IsEmptyString(NSString *string) {
    return nil == string || (id)kCFNull == string || string.length == 0;
}

NS_INLINE
BOOL IsTextEmptyString(NSString *string) {
    return nil == string || string.length == 0;
}

NS_INLINE
BOOL IsEmptyObj(id obj) {
    return nil == obj || (id)kCFNull == obj;
}

//调用C语言的API来获得文件的MIMEType
NS_INLINE
NSString * mimeTypeForFileAtPath(NSString *path)
{
    NSString *ext = [path pathExtension];
    if (IsTextEmptyString(ext)) {
        return nil;
    }
    //此函数需要引入 #import <MobileCoreServices/MobileCoreServices.h>
    // [path pathExtension] 获得文件的后缀名 MIME类型字符串转化为UTI字符串
    CFStringRef UTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)ext, NULL);
    // UTI字符串转化为后缀扩展名
    CFStringRef MIMEType = UTTypeCopyPreferredTagWithClass(UTI, kUTTagClassMIMEType);
    CFRelease(UTI);
    // application/octet-stream，此参数表示通用的二进制类型。
    if (!MIMEType) {
        return @"application/octet-stream";
    }
    return (__bridge NSString *)(MIMEType);
}

#ifdef DEBUG    //调试阶段
#define NSLog(...) printf("第%d行 %s\n%s\n\n", __LINE__, __func__, [NSString stringWithFormat:__VA_ARGS__].UTF8String)
#else   //发布
#define NSLog(...)
#endif

#endif /* Const_h */
