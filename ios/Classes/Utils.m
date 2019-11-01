#import "Utils.h"

@implementation Utils

+(BOOL)stringIsNumeric:(NSString*)str {
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    NSNumber *number = [formatter numberFromString:str];
    return !!number; // If the string is not numeric, number will be nil
}

+(NSNumber*)getNumber:(NSString*)str {
    NSNumberFormatter *f = [[NSNumberFormatter alloc] init];
    f.numberStyle = NSNumberFormatterDecimalStyle;
    return [f numberFromString:str];
}

+ (id)alloc {
  [NSException raise:@"Cannot be instantiated!" format:@"Static class 'ClassName' cannot be instantiated!"];
  return nil;
}

@end
