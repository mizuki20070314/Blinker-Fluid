// SPDX-License-Identifier: GPL-3.0-or-later
#import "BKTheme.h"
#import "BKCore.h"

static BOOL gPrivate = NO;
static BOOL gPrivateCached = NO;

static UIColor *BKRGB(CGFloat r, CGFloat g, CGFloat b) {
  return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

@implementation BKTheme

+ (void)cachePrivateSessionAtLaunch {
  if (!gPrivateCached) {
    gPrivate = [[NSUserDefaults standardUserDefaults] boolForKey:@"BlinkPrivateBrowsing"];
    gPrivateCached = YES;
  }
}

+ (BOOL)isPrivateSession {
  [self cachePrivateSessionAtLaunch];
  return gPrivate;
}

// Stock "Appearance": 0 = system, 1 = light, 2 = dark (the values of UIUserInterfaceStyle).
+ (BOOL)isDark {
  NSInteger forced = [[NSUserDefaults standardUserDefaults] integerForKey:@"BlinkAppearance"];
  if (forced == 1) {
    return NO;
  }
  if (forced == 2) {
    return YES;
  }
  if (@available(iOS 13.0, *)) {
    return UIScreen.mainScreen.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
  }
  return NO;
}

+ (UIStatusBarStyle)statusBarStyle {
  return [self isDark] ? UIStatusBarStyleLightContent : UIStatusBarStyleDefault;
}

+ (void)notifyChanged {
  [[NSNotificationCenter defaultCenter] postNotificationName:BKThemeDidChangeNotification object:nil];
}

+ (UIColor *)accent {
  return [self isPrivateSession] ? BKRGB(130, 62, 190) : BKRGB(224, 71, 40);
}

+ (UIColor *)onAccent {
  return UIColor.whiteColor;
}

+ (UIColor *)chromeBackground {
  return [self isDark] ? BKRGB(26, 26, 30) : BKRGB(248, 248, 250);
}

+ (UIColor *)pageBackground {
  return [self isDark] ? BKRGB(16, 16, 19) : BKRGB(255, 255, 255);
}

+ (UIColor *)pillBackground {
  return [self isDark] ? BKRGB(44, 44, 50) : BKRGB(233, 233, 238);
}

+ (UIColor *)primaryText {
  return [self isDark] ? BKRGB(244, 244, 246) : BKRGB(20, 20, 22);
}

+ (UIColor *)secondaryText {
  return [self isDark] ? BKRGB(160, 160, 170) : BKRGB(108, 108, 117);
}

+ (UIColor *)tertiaryText {
  return [self isDark] ? BKRGB(110, 110, 120) : BKRGB(163, 163, 171);
}

+ (UIColor *)separator {
  return [self isDark] ? [UIColor colorWithWhite:1 alpha:0.14] : [UIColor colorWithWhite:0 alpha:0.13];
}

+ (UIColor *)groupedBackground {
  return [self isDark] ? BKRGB(11, 11, 13) : BKRGB(242, 242, 246);
}

+ (UIColor *)cellBackground {
  return [self isDark] ? BKRGB(27, 27, 31) : BKRGB(255, 255, 255);
}

+ (UIColor *)cellSelected {
  return [self isDark] ? BKRGB(44, 44, 50) : BKRGB(224, 224, 230);
}

+ (UIColor *)tileBackground {
  return [self isDark] ? BKRGB(31, 31, 36) : BKRGB(255, 255, 255);
}

+ (UIColor *)sheetBackground {
  return [self isDark] ? BKRGB(23, 23, 26) : BKRGB(242, 242, 246);
}

+ (UIColor *)scrim {
  return [UIColor colorWithWhite:0 alpha:0.42];
}

+ (UIColor *)iconTint {
  return [self isDark] ? BKRGB(232, 232, 236) : BKRGB(38, 38, 43);
}

+ (UIColor *)destructive {
  return BKRGB(255, 69, 58);
}

+ (UIFont *)font:(CGFloat)size weight:(UIFontWeight)weight {
  return [UIFont systemFontOfSize:size weight:weight];
}

+ (UIColor *)colorForText:(NSString *)text {
  // A small fixed palette, picked by a hash of the text, so the same site always gets the same colour.
  static NSArray<UIColor *> *palette;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    palette = @[ BKRGB(94, 92, 230), BKRGB(10, 132, 255), BKRGB(48, 176, 199), BKRGB(52, 199, 89), BKRGB(255, 159, 10),
                 BKRGB(255, 99, 71), BKRGB(255, 55, 95), BKRGB(191, 90, 242), BKRGB(142, 142, 147), BKRGB(172, 142, 104) ];
  });
  NSUInteger hash = 5381;
  for (NSUInteger i = 0; i < text.length; i++) {
    hash = ((hash << 5) + hash) + [text characterAtIndex:i];
  }
  return palette[hash % palette.count];
}

@end
