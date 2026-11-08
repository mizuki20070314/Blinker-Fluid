// SPDX-License-Identifier: GPL-3.0-or-later
#import "BKChrome.h"
#import "BKCore.h"
#import "BKOmniboxView.h"
#import "BKSettings.h"
#import "BKTheme.h"
#import <objc/runtime.h>

static const void *kChromeKey = &kChromeKey;
static const NSInteger kBadgeTag = 0xB11E;

static NSHashTable<UIViewController *> *BKAllHosts(void) {
  static NSHashTable *table;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    table = [NSHashTable weakObjectsHashTable];
  });
  return table;
}

// What the stock fullscreen code gets from -toolbarBackgroundView: a stand-in whose hidden flag hides the whole chrome.
@interface BKToggleProxy : UIView
@property(nonatomic, weak) BKChrome *chrome;
@end

@implementation BKToggleProxy
- (void)setHidden:(BOOL)hidden {
  [super setHidden:hidden];
  [self.chrome setChromeHidden:hidden];
}
@end

// -handleURLBarSwipe: only reads .state and .direction, so a plain object does for a gesture recogniser.
@interface BKSwipeShim : NSObject
@property(nonatomic) NSInteger state;
@property(nonatomic) NSUInteger direction;
@end
@implementation BKSwipeShim
@end

@interface BKChrome () <UIGestureRecognizerDelegate>
@end

@implementation BKChrome {
  __weak UIViewController<BKStockHost> *_host;
  NSArray<NSLayoutConstraint *> *_ownConstraints;
  BOOL _compact;
  BOOL _atBottom;
  BKOmniboxView *_omnibox;
  BOOL _installed;
  NSString *_urlString;
  BOOL _chromeHidden;
  UIImageView *_edgeBubble;
}

@synthesize host = _host;

+ (BKChrome *)chromeForHost:(id)host {
  return host ? objc_getAssociatedObject(host, kChromeKey) : nil;
}

+ (NSInteger)openTabCountForHostClass:(Class)hostClass {
  NSInteger count = 0;
  for (UIViewController *controller in BKAllHosts().allObjects) {
    if ([controller isKindOfClass:hostClass] && controller.isViewLoaded && controller.view.window) {
      count++;
    }
  }
  return MAX(count, 1);
}

+ (void)refreshAllTabCounts {
  for (UIViewController *controller in BKAllHosts().allObjects) {
    [[self chromeForHost:controller] refreshTabCount];
  }
}

+ (BOOL)installOnHost:(UIViewController<BKStockHost> *)host {
  if ([self chromeForHost:host]) {
    return YES;
  }
  UIView *stockBar = BKGetIvar(host, "_toolbarBackgroundView");
  if (![stockBar isKindOfClass:[UIView class]] || !host.isViewLoaded || ![host respondsToSelector:@selector(contentView)] || ![host contentView]) {
    BKLog(@"chrome: nothing to replace on %@ (hidden toolbar mode?)", NSStringFromClass([host class]));
    return NO;
  }
  BKChrome *chrome = [[BKChrome alloc] init];
  chrome->_host = host;
  objc_setAssociatedObject(host, kChromeKey, chrome, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  [BKAllHosts() addObject:host];
  [chrome build];
  // A problem in this layer shows up in the first moments after the first chrome exists; engine crashes while loading pages come
  // later and must not count against it, so the launch is declared healthy a few seconds after the first install.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    BKGuardMarkLaunchHealthy();
  });
  BKLog(@"chrome: installed (tabs now %ld)", (long)[self openTabCountForHostClass:[host class]]);
  return YES;
}

+ (void)rollbackHost:(UIViewController<BKStockHost> *)host {
  BKChrome *chrome = [self chromeForHost:host];
  if (chrome) {
    [NSLayoutConstraint deactivateConstraints:chrome->_ownConstraints ?: @[]];
    [chrome->_topBar removeFromSuperview];
    [chrome->_bottomBar removeFromSuperview];
    [chrome->_progress removeFromSuperview];
    objc_setAssociatedObject(host, kChromeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  }
  UIView *view = host.view;
  UIView *stockBar = BKGetIvar(host, "_toolbarBackgroundView");
  UIView *stockProgress = BKGetIvar(host, "_loadingProgressView");
  if ([stockBar isKindOfClass:[UIView class]] && stockBar.superview != view) {
    [view addSubview:stockBar];
    stockBar.translatesAutoresizingMaskIntoConstraints = NO;
    [NSLayoutConstraint activateConstraints:@[
      [stockBar.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
      [stockBar.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
    ]];
  }
  if ([stockProgress isKindOfClass:[UIView class]] && stockProgress.superview != view) {
    [view addSubview:stockProgress];
  }
  [host applyToolbarPosition];  // the hook sees no chrome and runs the stock layout
  BKLog(@"chrome: rolled back to the stock toolbar");
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)urlString {
  return _urlString ?: @"";
}

// ------------------------------------------------------------------------------------------------------------ build

- (void)build {
  UIViewController<BKStockHost> *host = _host;
  UIView *view = host.view;

  // 1. Retire the stock toolbar and loading bar.  The objects stay alive (the controller owns them) so every stock code path
  //    that still touches them keeps working on views that are simply not on screen.
  UIView *stockBar = BKGetIvar(host, "_toolbarBackgroundView");
  UIView *stockProgress = BKGetIvar(host, "_loadingProgressView");
  UITextField *stockField = BKGetIvar(host, "_urlField");
  UIButton *stockBack = BKGetIvar(host, "_backButton");
  UIButton *stockForward = BKGetIvar(host, "_forwardButton");
  NSString *stockURL = stockField.text;
  [stockBar removeFromSuperview];
  [stockProgress removeFromSuperview];

  // 2. Our views.
  _topBar = [[BKTopBar alloc] init];
  _bottomBar = [[BKBottomBar alloc] init];
  _pill = [[BKAddressPill alloc] init];
  _progress = [[BKProgressView alloc] init];
  BKToggleProxy *proxy = [[BKToggleProxy alloc] init];
  proxy.chrome = self;
  _toggleProxy = proxy;
  for (UIView *v in @[ _topBar, _bottomBar, _progress ]) {
    v.translatesAutoresizingMaskIntoConstraints = NO;
    [view addSubview:v];
  }

  // 3. Wiring.  The engine glue enables/disables back & forward through -backButton / -forwardButton (hooked to return ours).
  _bottomBar.backButton.enabled = stockBack.enabled;
  _bottomBar.forwardButton.enabled = stockForward.enabled;
  [_bottomBar.backButton addTarget:host action:@selector(back) forControlEvents:UIControlEventTouchUpInside];
  [_bottomBar.forwardButton addTarget:host action:@selector(forward) forControlEvents:UIControlEventTouchUpInside];
  [_bottomBar.addTabButton addTarget:host action:@selector(openNewTab) forControlEvents:UIControlEventTouchUpInside];
  [_bottomBar.tabsButton addTarget:host action:@selector(showTabSwitcher) forControlEvents:UIControlEventTouchUpInside];
  [_bottomBar.menuButton addTarget:host action:@selector(showMainMenu) forControlEvents:UIControlEventTouchUpInside];
  [_pill.reloadButton addTarget:self action:@selector(reloadTapped) forControlEvents:UIControlEventTouchUpInside];
  __weak BKChrome *weakSelf = self;
  _pill.onTap = ^{ [weakSelf showOmnibox]; };
  _pill.onLongPress = ^{ [weakSelf.host presentSearchEngineMenu]; };
  _pill.onSwipe = ^(UISwipeGestureRecognizerDirection direction) {
    BKSwipeShim *shim = [[BKSwipeShim alloc] init];
    shim.state = UIGestureRecognizerStateEnded;
    shim.direction = direction;
    [weakSelf.host handleURLBarSwipe:shim];
  };

  // 4. First state.
  _installed = YES;
  [self setURLString:stockURL];
  [self applyTheme];
  [self applyLayout];
  [self refreshTabCount];
  [self updateDownloadBadge];
  [self installEdgeGestures];
  view.accessibilityElements = @[ _topBar, [host contentView], _bottomBar ];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:BKThemeDidChangeNotification object:nil];
  [host setNeedsStatusBarAppearanceUpdate];
}

- (void)reloadTapped {
  [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
  [_host reloadOrStop];
}

- (BKBarButton *)backButton { return _bottomBar.backButton; }
- (BKBarButton *)forwardButton { return _bottomBar.forwardButton; }
- (BKBarButton *)reloadButton { return _pill.reloadButton; }
- (BKBarButton *)menuButton { return _bottomBar.menuButton; }

// ----------------------------------------------------------------------------------------------------------- layout

- (BOOL)isCompact {
  CGSize size = _host.view.bounds.size;
  return size.width > size.height && size.height < 500;
}

- (void)applyLayout {
  UIViewController<BKStockHost> *host = _host;
  if (!_installed || !host || !host.isViewLoaded) {
    return;
  }
  UIView *view = host.view;
  UIView *content = [host contentView];
  if (!content) {
    return;
  }
  const BOOL compact = [self isCompact];
  const BOOL bottom = [BKSettings toolbarAtBottom] && !compact;   // landscape has no room for a second bar
  _atBottom = bottom;
  _compact = compact;
  const CGFloat pillRow = compact ? 44 : 56;
  const CGFloat buttonsHeight = compact ? 0 : 49;
  _topBar.contentHeight = bottom ? 0 : pillRow;
  _bottomBar.buttonsHeight = buttonsHeight;
  _bottomBar.pillRowHeight = bottom ? pillRow : 0;

  // Landscape: back / forward / tabs / menu sit beside the address pill in the top bar and the bottom bar goes away.
  NSArray<UIView *> *leading = @[ _bottomBar.backButton, _bottomBar.forwardButton ];
  NSArray<UIView *> *trailing = @[ _bottomBar.tabsButton, _bottomBar.menuButton ];
  UIView *buttonParent = compact ? (UIView *)_topBar : (UIView *)_bottomBar;
  for (UIView *button in [leading arrayByAddingObjectsFromArray:trailing]) {
    if (button.superview != buttonParent) {
      [button removeFromSuperview];
      [buttonParent addSubview:button];
    }
  }
  _topBar.leadingButtons = compact ? leading : nil;
  _topBar.trailingButtons = compact ? trailing : nil;
  _bottomBar.hidden = compact || _chromeHidden;
  UIView *parent = bottom ? (UIView *)_bottomBar : (UIView *)_topBar;
  if (_pill.superview != parent) {
    [_pill removeFromSuperview];
    [parent addSubview:_pill];
  }
  _topBar.pillView = _pill;
  _bottomBar.pillView = _pill;

  [NSLayoutConstraint deactivateConstraints:_ownConstraints ?: @[]];
  [NSLayoutConstraint deactivateConstraints:[host topPosConstraints] ?: @[]];
  [NSLayoutConstraint deactivateConstraints:[host bottomPosConstraints] ?: @[]];

  UILayoutGuide *safe = view.safeAreaLayoutGuide;
  double inset = MAX([host keyboardViewportInset], 0);
  NSMutableArray<NSLayoutConstraint *> *own = [NSMutableArray array];
  [own addObjectsFromArray:@[
    [_topBar.topAnchor constraintEqualToAnchor:view.topAnchor],
    [_topBar.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
    [_topBar.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
    [_topBar.bottomAnchor constraintEqualToAnchor:safe.topAnchor constant:_topBar.contentHeight],
    [_bottomBar.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
    [_bottomBar.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
    [_bottomBar.bottomAnchor constraintEqualToAnchor:view.bottomAnchor],
    [_bottomBar.topAnchor constraintEqualToAnchor:safe.bottomAnchor constant:-(buttonsHeight + _bottomBar.pillRowHeight)],
    [_progress.leadingAnchor constraintEqualToAnchor:view.leadingAnchor],
    [_progress.trailingAnchor constraintEqualToAnchor:view.trailingAnchor],
    [_progress.heightAnchor constraintEqualToConstant:2],
    bottom ? [_progress.topAnchor constraintEqualToAnchor:_bottomBar.topAnchor] : [_progress.bottomAnchor constraintEqualToAnchor:_topBar.bottomAnchor],
  ]];
  NSArray<NSLayoutConstraint *> *vertical = @[
    [content.topAnchor constraintEqualToAnchor:_topBar.bottomAnchor],
    // (with no bottom bar - landscape - the page reaches the true bottom edge, like the stock layout does)
    (inset > 0 || compact) ? [content.bottomAnchor constraintEqualToAnchor:view.bottomAnchor constant:-inset]
                           : [content.bottomAnchor constraintEqualToAnchor:_bottomBar.topAnchor],
  ];
  [NSLayoutConstraint activateConstraints:own];
  [NSLayoutConstraint activateConstraints:vertical];
  _ownConstraints = own;
  // The stock fullscreen code deactivates these two arrays, so the content's vertical constraints must live in them.
  [host setTopPosConstraints:vertical];
  [host setBottomPosConstraints:@[]];
  [view bringSubviewToFront:_progress];
}

- (void)layoutDidChange {
  if (!_installed) {
    return;
  }
  // (the bottom position only applies when there is room for it - compare what -applyLayout would decide, or landscape with the
  //  "bottom" setting would re-layout on every pass)
  const BOOL compact = [self isCompact];
  if (compact != _compact || ([BKSettings toolbarAtBottom] && !compact) != _atBottom) {
    [self applyLayout];
  }
}

- (void)setChromeHidden:(BOOL)hidden {
  _chromeHidden = hidden;
  _topBar.hidden = hidden;
  _bottomBar.hidden = hidden || _compact;
  _progress.hidden = hidden;
}

// ------------------------------------------------------------------------------------------------------------ state

- (void)setURLString:(NSString *)url {
  _urlString = [url copy] ?: @"";
  _blank = _urlString.length == 0 || [_urlString isEqualToString:@"about:blank"];
  [_pill setURLString:_urlString];
  [self refreshTabCount];
}

- (void)setLoading:(BOOL)loading {
  [_pill setLoading:loading];
  if (loading) {
    [_progress start];
  } else {
    [_progress finish];
  }
}

- (void)refreshTabCount {
  UIViewController *host = _host;
  if (host) {
    _bottomBar.tabsButton.count = [BKChrome openTabCountForHostClass:[host class]];
  }
}

- (void)updateDownloadBadge {
  BKBarButton *menu = _bottomBar.menuButton;
  UIView *badge = [menu viewWithTag:kBadgeTag];
  BOOL wanted = [[NSUserDefaults standardUserDefaults] boolForKey:@"BlinkDownloadAttention"];
  if (!wanted) {
    [badge removeFromSuperview];
    return;
  }
  if (badge) {
    return;
  }
  badge = [[UIView alloc] init];
  badge.tag = kBadgeTag;
  badge.userInteractionEnabled = NO;
  badge.backgroundColor = [BKTheme destructive];
  badge.layer.cornerRadius = 5;
  badge.layer.borderWidth = 1.5;
  badge.layer.borderColor = [BKTheme chromeBackground].CGColor;
  badge.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin;
  badge.frame = CGRectMake(menu.bounds.size.width / 2 + 7, menu.bounds.size.height / 2 - 14, 10, 10);
  [menu addSubview:badge];
}

- (void)applyTheme {
  UIViewController *host = _host;
  host.view.backgroundColor = [BKTheme pageBackground];
  [_topBar applyTheme];
  [_bottomBar applyTheme];
  [_pill applyTheme];
  [_progress applyTheme];
  [_omnibox applyTheme];
  [[_bottomBar viewWithTag:kBadgeTag] removeFromSuperview];
  [self updateDownloadBadge];
  [host setNeedsStatusBarAppearanceUpdate];
}

// ---------------------------------------------------------------------------------------------------------- omnibox

- (void)showOmnibox {
  UIViewController<BKStockHost> *host = _host;
  if (_omnibox || !host.isViewLoaded || !host.view.window) {
    return;
  }
  if (!BKFeatureAllowed(@"omnibox")) {
    [self showFallbackAddressPrompt];
    return;
  }
  BKFeatureBegin(@"omnibox");
  BKOmniboxView *box = [[BKOmniboxView alloc] initWithFrame:host.view.bounds];
  __weak BKChrome *weakSelf = self;
  box.onSubmit = ^(NSString *input) {
    BKChrome *strong = weakSelf;
    [strong hideOmnibox];
    [strong.host openUserInput:input];
  };
  box.onCancel = ^{ [weakSelf hideOmnibox]; };
  box.onLongPressField = ^{ [weakSelf.host presentSearchEngineMenu]; };
  [host.view addSubview:box];
  _omnibox = box;
  [box beginWithText:(_blank ? @"" : _urlString) fromStartPage:_blank];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    BKFeatureEnd(@"omnibox");
  });
}

- (void)hideOmnibox {
  BKOmniboxView *box = _omnibox;
  if (!box) {
    return;
  }
  _omnibox = nil;
  [box endEditing];
  [UIView animateWithDuration:0.15
      animations:^{ box.alpha = 0; }
      completion:^(BOOL finished) { [box removeFromSuperview]; }];
}

// Used only when the omnibox itself keeps failing (see BKGuard): a plain alert with a text field.
- (void)showFallbackAddressPrompt {
  UIViewController<BKStockHost> *host = _host;
  UIAlertController *alert = [UIAlertController alertControllerWithTitle:BKL(@"Address") message:nil preferredStyle:UIAlertControllerStyleAlert];
  [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
    field.text = self->_blank ? @"" : self->_urlString;
    field.keyboardType = UIKeyboardTypeURL;
    field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    field.autocorrectionType = UITextAutocorrectionTypeNo;
  }];
  [alert addAction:[UIAlertAction actionWithTitle:BKL(@"Cancel") style:UIAlertActionStyleCancel handler:nil]];
  [alert addAction:[UIAlertAction actionWithTitle:BKL(@"Search")
                                            style:UIAlertActionStyleDefault
                                          handler:^(UIAlertAction *action) {
                                            NSString *text = alert.textFields.firstObject.text;
                                            if (text.length) {
                                              [host openUserInput:text];
                                            }
                                          }]];
  [host presentViewController:alert animated:YES completion:nil];
}

// ----------------------------------------------------------------------------------------------------- tab swiping

- (void)slidePillOutToward:(NSInteger)direction completion:(void (^)(void))completion {
  UIView *pill = _pill;
  const CGFloat distance = MAX(pill.bounds.size.width * 0.45, 80);
  [UIView animateWithDuration:0.12
      delay:0
      options:UIViewAnimationOptionCurveEaseIn
      animations:^{
        pill.transform = CGAffineTransformMakeTranslation(direction > 0 ? -distance : distance, 0);
        pill.alpha = 0;
      }
      completion:^(BOOL finished) {
        pill.transform = CGAffineTransformIdentity;
        pill.alpha = 1;
        completion();
      }];
}

- (void)slidePillInFrom:(NSInteger)direction {
  UIView *pill = _pill;
  const CGFloat distance = MAX(pill.bounds.size.width * 0.45, 80);
  pill.transform = CGAffineTransformMakeTranslation(direction > 0 ? distance : -distance, 0);
  pill.alpha = 0;
  [UIView animateWithDuration:0.2
                        delay:0
       usingSpringWithDamping:0.88
        initialSpringVelocity:0.25
                      options:UIViewAnimationOptionCurveEaseOut
                   animations:^{
                     pill.transform = CGAffineTransformIdentity;
                     pill.alpha = 1;
                   }
                   completion:nil];
}

// ------------------------------------------------------------------------------------------------- edge swipes

// Swipe in from the left edge = back, from the right edge = forward (the engine has no gesture of its own).
- (void)installEdgeGestures {
  UIView *view = _host.view;
  const UIRectEdge edges[2] = {UIRectEdgeLeft, UIRectEdgeRight};
  for (int i = 0; i < 2; i++) {
    UIScreenEdgePanGestureRecognizer *pan = [[UIScreenEdgePanGestureRecognizer alloc] initWithTarget:self action:@selector(edgePanned:)];
    pan.edges = edges[i];
    pan.delegate = self;
    pan.cancelsTouchesInView = NO;
    [view addGestureRecognizer:pan];
  }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
  if (![gesture isKindOfClass:[UIScreenEdgePanGestureRecognizer class]]) {
    return YES;
  }
  if (_omnibox || _chromeHidden || _host.presentedViewController) {
    return NO;
  }
  const BOOL back = ((UIScreenEdgePanGestureRecognizer *)gesture).edges == UIRectEdgeLeft;
  return back ? _bottomBar.backButton.enabled : _bottomBar.forwardButton.enabled;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gesture shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)other {
  return YES;
}

- (void)placeEdgeBubbleForBack:(BOOL)back distance:(CGFloat)dx threshold:(CGFloat)threshold {
  UIView *view = _host.view;
  const CGFloat travel = MIN(dx * 0.6, 72);
  const CGFloat x = back ? -22 + travel : view.bounds.size.width + 22 - travel;
  _edgeBubble.center = CGPointMake(x, view.bounds.size.height / 2);
  _edgeBubble.alpha = MIN(dx / 40.0, 1.0);
  _edgeBubble.tintColor = dx >= threshold ? [BKTheme accent] : [BKTheme iconTint];
}

- (void)edgePanned:(UIScreenEdgePanGestureRecognizer *)pan {
  UIView *view = _host.view;
  const BOOL back = pan.edges == UIRectEdgeLeft;
  const CGFloat dx = fabs([pan translationInView:view].x);
  const CGFloat threshold = 84;
  switch (pan.state) {
    case UIGestureRecognizerStateBegan: {
      [_edgeBubble removeFromSuperview];
      UIImageView *bubble = [[UIImageView alloc] initWithImage:[BKIcons image:back ? BKIconBack : BKIconForward size:22]];
      bubble.contentMode = UIViewContentModeCenter;
      bubble.frame = CGRectMake(0, 0, 44, 44);
      bubble.layer.cornerRadius = 22;
      bubble.backgroundColor = [BKTheme chromeBackground];
      bubble.layer.shadowColor = UIColor.blackColor.CGColor;
      bubble.layer.shadowOpacity = 0.25;
      bubble.layer.shadowRadius = 6;
      bubble.layer.shadowOffset = CGSizeMake(0, 2);
      bubble.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:bubble.bounds].CGPath;
      bubble.alpha = 0;
      [view addSubview:bubble];
      _edgeBubble = bubble;
      [self placeEdgeBubbleForBack:back distance:dx threshold:threshold];
      break;
    }
    case UIGestureRecognizerStateChanged:
      [self placeEdgeBubbleForBack:back distance:dx threshold:threshold];
      break;
    case UIGestureRecognizerStateEnded: {
      const CGFloat velocity = fabs([pan velocityInView:view].x);
      UIImageView *bubble = _edgeBubble;
      _edgeBubble = nil;
      const BOOL go = dx >= threshold || (dx > 40 && velocity > 700);
      [UIView animateWithDuration:0.18
          animations:^{
            bubble.alpha = 0;
            bubble.transform = CGAffineTransformMakeScale(go ? 1.15 : 0.8, go ? 1.15 : 0.8);
          }
          completion:^(BOOL finished) { [bubble removeFromSuperview]; }];
      if (go) {
        [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
        if (back) {
          [_host back];
        } else {
          [_host forward];
        }
      }
      break;
    }
    default: {
      UIImageView *bubble = _edgeBubble;
      _edgeBubble = nil;
      [UIView animateWithDuration:0.15 animations:^{ bubble.alpha = 0; } completion:^(BOOL finished) { [bubble removeFromSuperview]; }];
      break;
    }
  }
}

@end
