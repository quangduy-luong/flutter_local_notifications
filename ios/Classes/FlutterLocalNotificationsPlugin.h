#import <Flutter/Flutter.h>
#import <UserNotifications/UserNotifications.h>
#import <CoreLocation/CoreLocation.h>

@interface FlutterLocalNotificationsPlugin : NSObject <FlutterPlugin, UNUserNotificationCenterDelegate> {
    CLLocationManager *locationManager;
}
@end
