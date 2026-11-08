// SPDX-License-Identifier: GPL-3.0-or-later
// Vector icons drawn in code.  iOS 12 has no SF Symbols and the stock IPA carries no icon images at all, so every glyph the
// chrome needs is a small UIBezierPath on a 24 x 24 grid, rendered once per size into a template image.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, BKIcon) {
  BKIconBack = 0,
  BKIconForward,
  BKIconReload,
  BKIconStop,
  BKIconPlus,
  BKIconTabs,          // outline of a tab (the count is a label on top)
  BKIconMenu,          // three dots
  BKIconLock,
  BKIconWarning,
  BKIconSearch,
  BKIconShare,
  BKIconBookmark,
  BKIconBookmarkFill,
  BKIconStar,
  BKIconClock,
  BKIconDownload,
  BKIconGear,
  BKIconHouse,
  BKIconPrivate,       // hat and glasses
  BKIconDesktop,
  BKIconTextSize,
  BKIconPerson,
  BKIconCheck,
  BKIconTrash,
  BKIconChevronRight,
  BKIconChevronDown,
  BKIconChevronUp,
  BKIconGlobe,
  BKIconArrowUpRight,
  BKIconCloseCircle,   // filled disc with a cut-out cross
  BKIconPaste,
  BKIconInfo,
  BKIconShield,
  BKIconBolt,
  BKIconCode,
  BKIconCamera,
  BKIconMic,
  BKIconLocation,
  BKIconFolder,
  BKIconHalfCircle,
  BKIconToolbarPosition,
  BKIconExit,
  BKIconCompass,
  BKIconHand,
  BKIconCount
};

@interface BKIcons : NSObject

// A template image (tint it with tintColor / imageView.tintColor) of `size` x `size` points.
+ (UIImage *)image:(BKIcon)icon size:(CGFloat)size;

// Maps the SF Symbol names the stock menus use (e.g. "square.on.square") to our icons; nil when there is no match.
+ (nullable UIImage *)imageForSymbolName:(NSString *)name size:(CGFloat)size;
+ (BKIcon)iconForSymbolName:(NSString *)name found:(BOOL *)found;

// A coloured, rounded-square tile with a glyph (used by menu rows).
+ (UIImage *)tileWithIcon:(BKIcon)icon size:(CGFloat)size color:(UIColor *)color;

@end

NS_ASSUME_NONNULL_END
