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

#ifdef DEBUG    //调试阶段
#define NSLog(...) printf("第%d行 %s\n%s\n\n", __LINE__, __func__, [NSString stringWithFormat:__VA_ARGS__].UTF8String)
#else   //发布
#define NSLog(...)
#endif

#endif /* Const_h */
