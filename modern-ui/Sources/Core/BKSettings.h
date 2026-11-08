// SPDX-License-Identifier: GPL-3.0-or-later
// Read-only access to the stock app's preferences (NSUserDefaults) and the privacy rules the stock UI already follows.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface BKSettings : NSObject

+ (BOOL)toolbarAtBottom;                                   // "BlinkToolbarBottom"
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)shortcuts;   // "BlinkShortcuts" {title,url}, 8 entries (defaults when unset)
+ (NSArray<NSDictionary<NSString *, NSString *> *> *)flatBookmarks;  // "BlinkBookmarks" flattened to {title,url}
+ (NSArray<NSString *> *)historyURLs;                      // "BlinkHistory" (newest first, empty in a private session)

// Network rules copied from the stock start page: nothing leaves the device while a proxy (Tor) is configured, and typed text
// is only ever sent to the search provider for a normal (non-private) session with suggestions switched on.
+ (BOOL)proxyConfigured;                                   // "BlinkProxy"
+ (BOOL)searchSuggestionsAllowed;
+ (nullable NSURL *)suggestionURLForTerm:(NSString *)term;
+ (NSString *)searchEngineName;

@end

NS_ASSUME_NONNULL_END
