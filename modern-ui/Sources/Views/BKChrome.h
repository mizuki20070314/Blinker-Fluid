// SPDX-License-Identifier: GPL-3.0-or-later
// BKChrome owns the modern chrome of ONE stock tab controller (ContentShellWindowDelegate): the address bar, the toolbar, the
// loading line and the omnibox.  It is attached to the controller as an associated object and talks to the stock code only
// through its Objective-C selectors (listed in BKStockHost), so nothing here needs the engine's C++ headers.

#import <UIKit/UIKit.h>
#import "BKChromeViews.h"

NS_ASSUME_NONNULL_BEGIN

// The selectors of ContentShellWindowDelegate that the chrome calls or reads (all verified against the released binary by
// tools/check_contract.py).
@protocol BKStockHost <NSObject>
@optional
- (void)back;
- (void)forward;
- (void)reloadOrStop;
- (void)openNewTab;
- (void)showTabSwitcher;
- (void)showMainMenu;
- (void)openUserInput:(NSString *)input;
- (void)presentSearchEngineMenu;
- (void)handleURLBarSwipe:(id)gesture;
- (void)showTabWindow:(void *)shell;
- (void *)shell;
- (UIView *)contentView;
- (void)applyToolbarPosition;
- (NSArray<NSLayoutConstraint *> *)topPosConstraints;
- (NSArray<NSLayoutConstraint *> *)bottomPosConstraints;
- (void)setTopPosConstraints:(nullable NSArray<NSLayoutConstraint *> *)constraints;
- (void)setBottomPosConstraints:(nullable NSArray<NSLayoutConstraint *> *)constraints;
- (double)keyboardViewportInset;
@end

@interface BKChrome : NSObject

+ (nullable BKChrome *)chromeForHost:(id)host;
+ (BOOL)installOnHost:(UIViewController<BKStockHost> *)host;
// Undoes a half-finished install: removes our views and puts the stock toolbar back.
+ (void)rollbackHost:(UIViewController<BKStockHost> *)host;
+ (NSInteger)openTabCountForHostClass:(Class)hostClass;
+ (void)refreshAllTabCounts;   // every tab's chrome re-reads the number of open tabs

@property(nonatomic, weak, readonly, nullable) UIViewController<BKStockHost> *host;
@property(nonatomic, strong, readonly) BKTopBar *topBar;
@property(nonatomic, strong, readonly) BKBottomBar *bottomBar;
@property(nonatomic, strong, readonly) BKAddressPill *pill;
@property(nonatomic, strong, readonly) BKProgressView *progress;
@property(nonatomic, readonly) BKBarButton *backButton;
@property(nonatomic, readonly) BKBarButton *forwardButton;
@property(nonatomic, readonly) BKBarButton *reloadButton;
@property(nonatomic, readonly) BKBarButton *menuButton;
@property(nonatomic, strong, readonly) UIView *toggleProxy;     // what the stock fullscreen code hides (-toolbarBackgroundView)
@property(nonatomic, copy, readonly) NSString *urlString;
@property(nonatomic, readonly) BOOL blank;

- (void)applyLayout;                                  // the replacement of -applyToolbarPosition
- (void)layoutDidChange;                              // after the host laid out (rotation)
- (void)applyTheme;
- (void)setURLString:(nullable NSString *)url;
- (void)setLoading:(BOOL)loading;
- (void)refreshTabCount;
- (void)updateDownloadBadge;
- (void)showOmnibox;
- (void)hideOmnibox;
- (void)setChromeHidden:(BOOL)hidden;

// Tab-switch animation of the address pill (used by the stock swipe on the bar).
- (void)slidePillOutToward:(NSInteger)direction completion:(void (^)(void))completion;
- (void)slidePillInFrom:(NSInteger)direction;

@end

NS_ASSUME_NONNULL_END
