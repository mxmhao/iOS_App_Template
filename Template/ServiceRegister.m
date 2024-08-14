//
// ServiceRegister.m
// 组件注册
//

#import <UIKit/UIKit.h>

#import <dlfcn.h>
#import <mach-o/getsect.h>
#import <mach-o/ldsyms.h>
#import <mach-o/dyld.h>

// 策略来自 美团技术博客：美团外卖iOS App冷启动治理
// 可以规定此阶段 在 willFinishLaunchingWithOptions 中调用
#define STAGE_KEY_A @"STAGE_KEY_A"
// 可以规定此阶段 在 didFinishLaunchingWithOptions 中调用
#define STAGE_KEY_B @"STAGE_KEY_B"
// segname
#define SERVICE_SEGNAME "__DATA"

struct ServiceRegisterHeader {
    char *key;
    void (*function)(void);
};

#define XM_SERVICE_REGISTER(key) \
static void _xm##key(void); \
__attribute__((used, section(SERVICE_SEGNAME ",__" #key ".f"))) \
static const struct ServiceRegisterHeader __H##key = (struct ServiceRegisterHeader){(char *)(&#key), (void *)(&_xm##key)}; \
static void _xm##key(void) \

// 使用方法
XM_SERVICE_REGISTER(STAGE_KEY_A) { // (key)不能太长，否则 __attribute__ 会报错
    // 这里注册
}

@interface ServiceRegister : NSObject
@end

@implementation ServiceRegister

// 需要引入：
//#import <dlfcn.h>
//#import <mach-o/getsect.h>
//#import <mach-o/ldsyms.h>
void XMExecuteFunc(char *key) {
//============================================
//    Dl_info info;
//    // 非主程序代码使用 dladdr 获取到的 machHeader，getsectiondata 函数无法获取到数据
//    dladdr((const void *)&AXWLExecuteFunc, &info);
//    #ifdef __LP64__
//    const struct mach_header_64 *machHeader = (struct mach_header_64 *)info.dli_fbase;
//    #else
//    const struct mach_header *machHeader = (struct mach_header *)info.dli_fbase;
//    #endif
//    if (NULL == machHeader) {
//        return;
//    }
//============================================
    
    // 根据自己的业务选择时用此方式，还是使用 initProphet 的方式
    unsigned long byteCount = 0;
    // _mh_execute_header 不能在库、框架或包中使用，只能在主程序代码中使用，包含在<mach-o/ldsyms.h>头中
    uint8_t * data = (uint8_t *) getsectiondata(&_mh_execute_header, SERVICE_SEGNAME, key, &byteCount);
    NSUInteger counter = byteCount / sizeof(struct ServiceRegisterHeader);
    struct ServiceRegisterHeader *items = (struct ServiceRegisterHeader *)data;
    for (NSUInteger idx = 0; idx < counter; ++idx) {
        items[idx].function();
    }
}

+ (void)executeFuncsForKey:(NSString *)key
{
    NSString *fKey = [NSString stringWithFormat:@"__%@.f", key ?: @""];
    XMExecuteFunc((char *)[fKey UTF8String]);
}

static const struct mach_header *smh;
// 会被调用很多次
static void dyld_callback(const struct mach_header* mh, intptr_t vmaddr_slide)
{
    unsigned long byteCount = 0;
#ifndef __LP64__
    uintptr_t *data = (uintptr_t *) getsectiondata(mh, SEGNAME, key, &byteCount);
#else
    uintptr_t *data = (uintptr_t *) getsectiondata((const struct mach_header_64 *)mh, SERVICE_SEGNAME, "__STAGE_KEY_A.f", &byteCount);
#endif
    if (0 != byteCount) {
        NSLog(@"--%lu", byteCount);
        smh = mh; // 这里就能拿到正确的
    }
}

// 此方法在库、框架或包中使用，也能拿到正确的 mach_header。来自阿里的iOS组件化工具BeeHive
__attribute__((constructor))
void initProphet(void) {
    // 注册库加载时的回调，会有很多库加载，所以会回调很多次
    _dyld_register_func_for_add_image(dyld_callback);
}

@end
