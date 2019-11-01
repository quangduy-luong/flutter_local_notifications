#import <Foundation/Foundation.h>
#import "NotificationTime.h"

@interface NotificationDetails : NSObject
@property(nonatomic, strong) NSNumber *id;
@property(nonatomic, strong) NSString *title;
@property(nonatomic, strong) NSString *body;
@property(nonatomic, strong) NSString *payload;
@property(nonatomic) bool presentAlert;
@property(nonatomic) bool presentSound;
@property(nonatomic) bool presentBadge;
@property(nonatomic, strong) NSString *sound;
@property(nonatomic, strong) NSNumber *secondsSinceEpoch;
@property(nonatomic, strong) NSNumber *repeatInterval;
@property(nonatomic, strong) NotificationTime *repeatTime;
@property(nonatomic, strong) NSNumber *day;
@property(nonatomic, strong) NSString *categoryIdentifier;
@property(nonatomic, strong) NSString *firstActionTitle;
@property(nonatomic, strong) NSString *secondActionTitle;
@property(nonatomic, strong) NSString *thirdActionTitle;
@property(nonatomic, strong) NSString *firstActionPayload;
@property(nonatomic, strong) NSString *secondActionPayload;
@property(nonatomic, strong) NSString *thirdActionPayload;
@end
