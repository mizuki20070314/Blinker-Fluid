// SPDX-License-Identifier: GPL-3.0-or-later
// Colours, metrics and fonts of the modern chrome.  Light/dark is resolved by hand because iOS 12 has no system dark mode
// (iOS 13+ follows the system unless the stock Appearance setting forces light or dark).

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BKTheme : NSObject

// YES for a private (off-the-record) launch.  Read once: like the stock UI, a change only applies after a restart.
+ (BOOL)isPrivateSession;
+ (void)cachePrivateSessionAtLaunch;

+ (BOOL)isDark;
+ (UIStatusBarStyle)statusBarStyle;
+ (void)notifyChanged;

// The few places the user may point at the page: the accent follows the session type (orange/red, purple when private).
+ (UIColor *)accent;
+ (UIColor *)onAccent;

+ (UIColor *)chromeBackground;   // top / bottom bars
+ (UIColor *)pageBackground;     // start page, behind the web view
+ (UIColor *)pillBackground;     // address pill, search fields
+ (UIColor *)primaryText;
+ (UIColor *)secondaryText;
+ (UIColor *)tertiaryText;
+ (UIColor *)separator;
+ (UIColor *)groupedBackground;  // lists
+ (UIColor *)cellBackground;
+ (UIColor *)cellSelected;
+ (UIColor *)tileBackground;     // favourites tiles, tab cards
+ (UIColor *)sheetBackground;
+ (UIColor *)scrim;              // dim behind sheets
+ (UIColor *)iconTint;
+ (UIColor *)destructive;

+ (UIFont *)font:(CGFloat)size weight:(UIFontWeight)weight;

// A stable, pleasant colour for a host name (monogram tiles when there is no icon).
+ (UIColor *)colorForText:(NSString *)text;

@end

NS_ASSUME_NONNULL_END
