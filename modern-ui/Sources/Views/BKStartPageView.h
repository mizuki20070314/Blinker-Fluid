// SPDX-License-Identifier: GPL-3.0-or-later
// The new-tab page: logo, a search field that opens the omnibox, the favourites grid (the stock "BlinkShortcuts") and the most
// recent sites.  A drop-in for the stock BlinkerStartPageView (same onNavigate / rebuildShortcutGrid surface).

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BKStartPageView : UIView
@property(nonatomic, copy, nullable) void (^onNavigate)(NSString *input);
@property(nonatomic, copy, nullable) void (^onSearchTapped)(void);
- (void)reloadContent;
- (void)rebuildShortcutGrid;   // stock name
- (void)applyTheme;
@end

NS_ASSUME_NONNULL_END
