// Blinker Fluid "Modern UI" - core helpers: logging, crash guard, runtime hooking, strings.
//
// Everything in modern-ui/ is plain Objective-C (ARC) that only talks to the stock UI through the Objective-C runtime, so it
// can be built either as a separate framework that is injected into the released IPA (see ../tools/package_ipa.sh) or
// compiled straight into content_shell_framework (add the files to content/shell/BUILD.gn).
//
// SPDX-License-Identifier: GPL-3.0-or-later

#import <UIKit/UIKit.h>
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

// ---------------------------------------------------------------------------------------------------------------- paths
NSString *BKDocumentsPath(void);   // visible in the Files app (the stock Info.plist sets UIFileSharingEnabled)
NSString *BKSupportPath(void);     // Library/Caches/ModernUI, created on demand

// ---------------------------------------------------------------------------------------------------------------- log
// Appends to Documents/ModernUI.log (kept under ~256 KB).  Cheap enough to call from UI code.
void BKLog(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);

// ------------------------------------------------------------------------------------------------------------- guard
// A crash-loop breaker.  The UI layer must never be the reason the browser cannot start:
//   * Documents/disable-modern-ui (a file the user can create) switches the whole layer off.
//   * A launch marker that is still present at the next launch means the previous run died early; the first time the layer
//     stays off for one launch, the second time it stays off until Documents/ModernUI-safe-mode.txt is deleted.
//   * Feature markers do the same per feature (omnibox, tab grid, menu sheet ...), so one broken screen falls back to the
//     stock screen without taking the others down.
BOOL BKGuardBeginLaunch(void);                    // NO = leave the stock UI alone for this launch
void BKGuardMarkLaunchHealthy(void);              // call a few seconds after the first screen is up
BOOL BKFeatureAllowed(NSString *feature);
void BKFeatureBegin(NSString *feature);           // write the marker just before something risky
void BKFeatureEnd(NSString *feature);             // ... and remove it once it worked

// ----------------------------------------------------------------------------------------------------------- runtime
// Replaces (or adds) an instance method after checking its signature.  `shape` is the type encoding without the frame
// offsets, e.g. "v@:" for -(void)foo, "v@:@" for -(void)foo:(id)x, "v@:B" for -(void)foo:(BOOL)b.  Returns NO (and logs) when the
// class/selector is missing or has a different signature, in which case nothing is changed.
BOOL BKHookInstance(Class cls, SEL sel, const char *shape, IMP imp, IMP _Nullable *_Nullable orig);

// Reads / writes an Objective-C object ivar by name (nil when the ivar does not exist).
id _Nullable BKGetIvar(id obj, const char *name);
void BKSetIvar(id obj, const char *name, id _Nullable value);

// ------------------------------------------------------------------------------------------------------------- strings
// Tiny localisation table following the stock language choice (NSUserDefaults "BlinkLanguageAccept", e.g. "ja-JP,ja,en").
NSString *BKL(NSString *english);
NSString *BKLanguageCode(void);                   // "en", "ja", ...

// --------------------------------------------------------------------------------------------------------- notifications
FOUNDATION_EXPORT NSNotificationName const BKThemeDidChangeNotification;

NS_ASSUME_NONNULL_END
