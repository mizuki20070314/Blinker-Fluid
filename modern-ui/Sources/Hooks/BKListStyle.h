// SPDX-License-Identifier: GPL-3.0-or-later
// Re-skins the stock list screens (menu, settings, bookmarks, history, downloads ...).  They are all one class, BlinkListVC, a
// data-driven UITableViewController; only its look is replaced here - rows, callbacks and navigation stay the stock ones.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BKListStyle : NSObject
+ (void)installHooks;                                    // BlinkListVC, BlinkBookmarkEditorVC, BlinkFindInPageController
+ (void)styleNavigationBar:(UINavigationBar *)bar;
+ (BOOL)isMainMenuList:(UIViewController *)vc;
// Turns the stock popover menu into a bottom sheet: custom presentation, no navigation bar, quick-action header.
+ (void)prepareMenuNavigation:(UINavigationController *)nav;
@end

NS_ASSUME_NONNULL_END
