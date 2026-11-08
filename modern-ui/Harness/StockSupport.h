// Stand-ins for the helpers the stock file defines privately (see the top of shell_platform_delegate_ios.mm).
// They behave like the iOS 12 build: no SF Symbols, no icon assets.
#import <UIKit/UIKit.h>

#define BLINKER_DIAG(x) \
  do {                  \
  } while (0)
#define BLINKER_DIAGF(...) \
  do {                     \
  } while (0)

static inline NSString* BlinkL(NSString* english) { return english; }
static inline UIImage* BlinkSystemImage(NSString* name) { return nil; }

static inline UIColor* BlinkerThemeColor(void) {
  return [UIColor colorWithRed:224 / 255.0 green:71 / 255.0 blue:40 / 255.0 alpha:1.0];
}
static inline UIColor* BlinkerAccentColor(void) { return BlinkerThemeColor(); }
