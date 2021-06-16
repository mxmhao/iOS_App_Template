//
//  EventKitTemplate.m
//  iOS_App_Template
//
//  Created by macmini on 2021/6/16.
//  Copyright © 2021 mxm. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <EventKit/EventKit.h>
#import <UIKit/UIColor.h>

typedef void(^EKEventStoreRequestAccessCompletionHandler)(BOOL granted, NSError * __nullable error);

NS_ASSUME_NONNULL_BEGIN

@interface EventKitTemplate : NSObject

+ (BOOL)hasAuthorized;

+ (void)requestAccess:(EKEventStoreRequestAccessCompletionHandler)completion;

+ (NSArray<NSDictionary *> *)queryEvents:(NSString *)eventId;

+ (BOOL)addOrUpdateEventNotifyWithEventId:(NSString *)eventId
                                    title:(NSString *)title
                                    notes:(NSString*)notes
                                startDate:(NSUInteger)startDate
                                     freq:(NSString *)freq
                                 interval:(NSInteger)interval;

+ (BOOL)removeEvent:(NSString *)eventId;

@end

NS_ASSUME_NONNULL_END

@implementation EventKitTemplate

static EKEventStore *es;
static EKCalendar *myCal;

+ (void)shared
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        es = [EKEventStore new];
        myCal = [self fetchCalendar:es];
    });
}

+ (BOOL)hasAuthorized
{
    return [EKEventStore  authorizationStatusForEntityType:EKEntityTypeEvent] == EKAuthorizationStatusAuthorized;
    //用户授权不允许
//    else if (eventStatus == EKAuthorizationStatusDenied){
//        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"当前日历服务不可用" message:@"您还没有授权本应用使用日历,请到 设置 > 隐私 > 日历 中授权" preferredStyle:UIAlertControllerStyleAlert];
//        UIAlertAction *action = [UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
//        }];
//        [alert addAction:action];
//        [self presentViewController:alert animated:YES completion:nil];
//    }
}

+ (void)requestAccess:(EKEventStoreRequestAccessCompletionHandler)completion
{
    //提示用户授权，调出授权弹窗
    [[EKEventStore new] requestAccessToEntityType:EKEntityTypeEvent completion:completion];
//    [es requestAccessToEntityType:EKEntityTypeEvent completion:^(BOOL granted, NSError * _Nullable error) {
//        if (granted) {
//            NSLog(@"允许");
//        } else {
//            NSLog(@"拒绝授权");
//        }
//    }];
}

//还有两种授权状态：
//EKAuthorizationStatusAuthorized用户已经允许授权
//EKAuthorizationStatusRestricted,未授权，且用户无法更新，如家长控制情况下


#define kEKCalendarTitle @"your calendar account name"

+ (EKCalendar *)fetchCalendar:(EKEventStore *)eventStore
{
    for (EKCalendar *ekcalendar in [eventStore calendarsForEntityType:EKEntityTypeEvent]) {
        if ([ekcalendar.title isEqualToString:kEKCalendarTitle] ) {
            return ekcalendar;
        }
    }
    EKSource *localSource = nil;//EKSource不能创建自己的，因为eventStore没有保存方法
    //真机
    for (EKSource *source in eventStore.sources){
        if (source.sourceType == EKSourceTypeCalDAV && [source.title isEqualToString:@"iCloud"]){//获取iCloud源
            localSource = source;
            break;
        }
    }
    
    if (localSource == nil) {
        //模拟器
        for (EKSource *source in eventStore.sources) {//获取本地Local源(就是上面说的模拟器中名为的Default的日历源)
            if (source.sourceType == EKSourceTypeLocal) {
                localSource = source;
                break;
            }
        }
    }
    EKCalendar *cal = [EKCalendar calendarForEntityType:EKEntityTypeEvent eventStore:eventStore];
    cal.source = localSource;
    cal.title = kEKCalendarTitle;//自定义日历标题
    cal.CGColor = [UIColor greenColor].CGColor;//自定义日历颜色
    NSError *error;
    [eventStore saveCalendar:cal commit:YES error:&error];//EKCalendar可以创建自己的，因为eventStore可以保存
    if (error) {
        NSLog(@"add EKCalendar error: %@", error);
    }
    
    return cal;
}

+ (NSArray *)queryEvents:(NSString *)eventId
{
    [self shared];
    NSArray<EKEvent *> *events;
    if (eventId) {
        EKEvent *et = [es eventWithIdentifier:eventId];
        if (et) {
            events = @[et];
        } else {
            return nil;
        }
    } else {
        NSPredicate *predicate = [es predicateForEventsWithStartDate:[NSDate dateWithTimeIntervalSinceNow:-31536000] endDate:[NSDate dateWithTimeIntervalSinceNow:31536000*2] calendars:@[myCal]];//iOS限制取4年范围内的
        events = [es eventsMatchingPredicate:predicate];
    }
    
    if (nil == events || events.count == 0) {
        return nil;
    }
    
    NSLog(@"%@", events);
    NSMutableArray *eventJsons = [NSMutableArray arrayWithCapacity:10];
    NSMutableDictionary *eventDic = [NSMutableDictionary dictionaryWithCapacity:10];
    for (EKEvent *event in events) {
        eventDic[@"id"] = event.eventIdentifier;
        eventDic[@"dtStart"] = @((UInt64)(event.startDate.timeIntervalSince1970 * 1000));
        eventDic[@"title"] = event.title;
        eventDic[@"notes"] = event.notes;
        EKRecurrenceRule *rrule = event.recurrenceRules.firstObject;
        if (rrule) {
            eventDic[@"interval"] = @(rrule.interval);
            switch (rrule.frequency) {
                case EKRecurrenceFrequencyDaily:
                    eventDic[@"freq"] = @"daily";
                    break;
                case EKRecurrenceFrequencyWeekly:
                    eventDic[@"freq"] = @"weekly";
                    break;
                case EKRecurrenceFrequencyMonthly:
                    eventDic[@"freq"] = @"monthly";
                    break;
                case EKRecurrenceFrequencyYearly:
                    eventDic[@"freq"] = @"yearly";
                    break;
                default:
                    break;
            }
        }
        
        [eventJsons addObject:eventDic];
    }
    return eventJsons;
}

+ (BOOL)addOrUpdateEventNotifyWithEventId:(NSString *)eventId
                                    title:(NSString *)title
                                    notes:(NSString*)notes
                                startDate:(NSUInteger)startDate
                                     freq:(NSString *)freq
                                 interval:(NSInteger)interval   //时间戳,毫秒
{
    [self shared];
//    EKReminder *reminder = [EKReminder reminderWithEventStore:es];//没有reminderWithIdentifier方法
    //创建一个新事件
    EKEvent *event;
    if (eventId) {
        event = [es eventWithIdentifier:eventId];
    } else {
        event = [EKEvent eventWithEventStore:es];
    }
    event.title = title;//标题
    event.notes = notes;//备注
    event.startDate = [NSDate dateWithTimeIntervalSince1970:startDate * 1.0 / 1000];//开始时间
    //重复规则
    if ([freq caseInsensitiveCompare:@"Daily"] == NSOrderedSame) {
        event.recurrenceRules = @[[[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyDaily interval:interval end:nil]];
    } else if ([freq caseInsensitiveCompare:@"Weekly"] == NSOrderedSame) {
        event.recurrenceRules = @[[[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyWeekly interval:interval end:nil]];
        
//        NSDateComponents *comps = [NSCalendar.currentCalendar components:NSCalendarUnitWeekday fromDate:event.startDate];
//        NSInteger weekdey = [comps weekday];//1、2、3、4、5、6、7 分别对应 周日、周一、周二、周三、周四、周五、周六
//        EKRecurrenceRule *rule = [[EKRecurrenceRule alloc]
//                                   initRecurrenceWithFrequency:EKRecurrenceFrequencyWeekly
//                                   interval:interval
//                                   daysOfTheWeek:@[[EKRecurrenceDayOfWeek dayOfWeek:weekdey]]
//                                   daysOfTheMonth:nil
//                                   monthsOfTheYear:nil
//                                   weeksOfTheYear:nil
//                                   daysOfTheYear:nil
//                                   setPositions:nil
//                                   end:nil];
//        event.recurrenceRules = @[rule];
    } else if ([freq caseInsensitiveCompare:@"Monthly"] == NSOrderedSame) {
        event.recurrenceRules = @[[[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyMonthly interval:interval end:nil]];
    } else if ([freq caseInsensitiveCompare:@"Yearly"] == NSOrderedSame) {
        event.recurrenceRules = @[[[EKRecurrenceRule alloc] initRecurrenceWithFrequency:EKRecurrenceFrequencyYearly interval:interval end:nil]];
    }
    
    //设置提醒
    [event addAlarm:[EKAlarm alarmWithRelativeOffset:0]];

    [event setCalendar:myCal];//设置日历类型
    //保存事件
    NSError *err = nil;
    if ([es saveEvent:event span:EKSpanFutureEvents commit:YES error:&err]) {//注意这里是no，在外部调用完这个add方法之后一定要commit
        NSLog(@"创建事件到系统日历成功!,%@", title);
    } else {
        NSLog(@"创建失败%@", err);
    }
    return nil == err;
}

+ (BOOL)removeEvent:(NSString *)eventId
{
    [self shared];
    return [es removeEvent:[es eventWithIdentifier:eventId] span:EKSpanFutureEvents error:nil];
}

@end
