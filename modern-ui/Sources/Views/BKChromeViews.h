// SPDX-License-Identifier: GPL-3.0-or-later
// The small building blocks of the browser chrome: icon buttons, the address pill, the progress line and the two bars.

#import <UIKit/UIKit.h>
#import "BKIcons.h"

NS_ASSUME_NONNULL_BEGIN

// A flat icon button.  The stock engine glue keeps calling -setEnabled: (back/forward) and -setImage:forState: (reload/stop) on
// the buttons it knows about; those calls land here, so the enabled state follows the engine and stray images are ignored.
@interface BKBarButton : UIButton
@property(nonatomic) BKIcon icon;
@property(nonatomic) CGFloat iconSize;
@property(nonatomic, copy, nullable) void (^enabledDidChange)(BOOL enabled);
- (instancetype)initWithIcon:(BKIcon)icon iconSize:(CGFloat)size;
- (void)applyTheme;
@end

// The tab button: a rounded square with the number of open tabs inside.
@interface BKTabsButton : BKBarButton
@property(nonatomic) NSInteger count;
@end

// The thin loading line under the top bar.
@interface BKProgressView : UIView
- (void)start;
- (void)finish;
- (void)reset;
- (void)applyTheme;
@end

typedef NS_ENUM(NSInteger, BKSecurityState) { BKSecurityNone = 0, BKSecuritySecure, BKSecurityInsecure };

// The rounded address field of the top (or bottom) bar.  It never edits text itself: tapping it asks the chrome to open the
// omnibox, which is where typing happens.
@interface BKAddressPill : UIView
@property(nonatomic, copy, nullable) void (^onTap)(void);
@property(nonatomic, copy, nullable) void (^onLongPress)(void);
@property(nonatomic, copy, nullable) void (^onSwipe)(UISwipeGestureRecognizerDirection direction);
@property(nonatomic, strong, readonly) BKBarButton *reloadButton;
@property(nonatomic, copy, readonly) NSString *shownText;
- (void)setURLString:(nullable NSString *)url;   // nil / "" / about:blank = placeholder
- (void)setLoading:(BOOL)loading;
- (void)applyTheme;
@end

@interface BKTopBar : UIView
@property(nonatomic) CGFloat contentHeight;      // below the status bar; 0 = only the status-bar strip
// Landscape: the toolbar buttons move up next to the pill (they must be subviews of this bar to be laid out).
@property(nonatomic, copy, nullable) NSArray<UIView *> *leadingButtons;
@property(nonatomic, copy, nullable) NSArray<UIView *> *trailingButtons;
@property(nonatomic, weak, nullable) UIView *pillView;
- (void)applyTheme;
@end

@interface BKBottomBar : UIView
@property(nonatomic, strong, readonly) BKBarButton *backButton;
@property(nonatomic, strong, readonly) BKBarButton *forwardButton;
@property(nonatomic, strong, readonly) BKBarButton *addTabButton;
@property(nonatomic, strong, readonly) BKTabsButton *tabsButton;
@property(nonatomic, strong, readonly) BKBarButton *menuButton;
@property(nonatomic) CGFloat buttonsHeight;      // height of the icon row (above the safe-area inset)
@property(nonatomic) CGFloat pillRowHeight;      // > 0 when the address pill lives in this bar (bottom mode)
@property(nonatomic, weak, nullable) UIView *pillView;
- (void)applyTheme;
@end

NS_ASSUME_NONNULL_END
