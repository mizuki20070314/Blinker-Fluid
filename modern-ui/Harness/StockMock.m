// A stand-in for the stock ContentShellWindowDelegate with the same Objective-C surface (every entry of BKContract.inc) and the
// stock behaviour of the methods the modern UI touches, minus the C++ engine.  The list/tab classes are the real stock code,
// cut out of shell_platform_delegate_ios.mm by extract_stock.py.
#import <UIKit/UIKit.h>
#import "StockSupport.h"

// ----------------------------------------------------------------------------------------------- a fake web page

@interface MockWebView : UIView
@property(nonatomic, copy) NSString *pageTitle;
@property(nonatomic) UIColor *accentColor;
@end

@implementation MockWebView
- (void)drawRect:(CGRect)rect {
  CGFloat w = self.bounds.size.width;
  [[UIColor whiteColor] setFill];
  UIRectFill(self.bounds);
  [(self.accentColor ?: [UIColor colorWithRed:0.1 green:0.4 blue:0.9 alpha:1]) setFill];
  UIRectFill(CGRectMake(0, 0, w, 88));
  [(self.pageTitle ?: @"Example Domain") drawInRect:CGRectMake(16, 30, w - 32, 36)
                                     withAttributes:@{NSFontAttributeName : [UIFont boldSystemFontOfSize:24], NSForegroundColorAttributeName : UIColor.whiteColor}];
  NSDictionary *body = @{NSFontAttributeName : [UIFont systemFontOfSize:15], NSForegroundColorAttributeName : [UIColor colorWithWhite:0.2 alpha:1]};
  NSString *text = @"This is a stand-in for a web page. The browser chrome around it - the address bar on top, the toolbar below - is what the simulator run is looking at.";
  [text drawInRect:CGRectMake(16, 104, w - 32, 120) withAttributes:body];
  [[UIColor colorWithWhite:0.93 alpha:1] setFill];
  UIRectFill(CGRectMake(16, 232, w - 32, 120));
  [[UIColor colorWithRed:1 green:0.6 blue:0.2 alpha:1] setFill];
  UIRectFill(CGRectMake(16, 232, 90, 120));
  [text drawInRect:CGRectMake(16, 366, w - 32, 90) withAttributes:body];
  [[UIColor colorWithWhite:0.9 alpha:1] setFill];
  for (int i = 0; i < 6; i++) {
    UIRectFill(CGRectMake(16, 470 + i * 26, (i % 2) ? w - 90 : w - 32, 12));
  }
}
@end

// ------------------------------------------------------------------------------------------------------ stock helpers

@interface BlinkerStartPageView : UIView
@property(nonatomic, copy) void (^onNavigate)(NSString*);
@end
@implementation BlinkerStartPageView
@end

#include "StockExtract.inc"

// -------------------------------------------------------------------------------------------- the mock controller

@interface ContentShellWindowDelegate : UIViewController <UITextFieldDelegate, UIPopoverPresentationControllerDelegate>
@property(nonatomic, strong) UIStackView* toolbarBackgroundView;
@property(nonatomic, strong) UIView* toolbarPaintView;
@property(nonatomic, strong) NSArray<NSLayoutConstraint*>* topPosConstraints;
@property(nonatomic, strong) NSArray<NSLayoutConstraint*>* bottomPosConstraints;
@property(nonatomic, strong) NSArray<NSLayoutConstraint*>* contentHorizontalConstraints;
@property(nonatomic, strong) NSArray<NSLayoutConstraint*>* fullscreenConstraints;
@property(nonatomic, assign) CGFloat keyboardViewportInset;
@property(nonatomic, strong) BlinkerStartPageView* startPage;
@property(nonatomic, strong) UIStackView* toolbarContentView;
@property(nonatomic, strong) UIButton* backButton;
@property(nonatomic, strong) UIButton* forwardButton;
@property(nonatomic, strong) UIButton* reloadOrStopButton;
@property(nonatomic, strong) UIButton* menuButton;
@property(nonatomic, strong) UITextField* urlField;
@property(nonatomic, strong) UIView* contentView;
@property(nonatomic, strong) UIProgressView* loadingProgressView;
@property(nonatomic, strong) NSArray<NSLayoutConstraint*>* loadingProgressConstraints;
@property(nonatomic, copy) NSString* harnessURL;
@property(nonatomic, assign) NSInteger harnessTabCount;
@property(nonatomic, weak) UINavigationController* lastStockMenuNav;
@property(nonatomic, strong) MockWebView* harnessWeb;
@end

static NSMutableArray<NSString*>* gLog;
NSArray<NSString*>* HarnessLog(void) { return gLog ?: @[]; }
static void Note(NSString* line) {
  if (!gLog) {
    gLog = [NSMutableArray array];
  }
  [gLog addObject:line];
}

@implementation ContentShellWindowDelegate {
  void* _shell;
}
@synthesize toolbarBackgroundView = _toolbarBackgroundView;
@synthesize backButton = _backButton;
@synthesize forwardButton = _forwardButton;
@synthesize reloadOrStopButton = _reloadOrStopButton;
@synthesize menuButton = _menuButton;
@synthesize urlField = _urlField;
@synthesize contentView = _contentView;
@synthesize loadingProgressView = _loadingProgressView;
@synthesize toolbarContentView = _toolbarContentView;

- (void*)shell {
  return (void*)0x1000;
}

- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = [UIColor colorWithWhite:0.09 alpha:1.0];
  self.contentView = [[UIView alloc] init];
  [self.view addSubview:_contentView];

  self.toolbarBackgroundView = [self createToolbarBackgroundView];
  self.toolbarContentView = [self createToolbarContentView];
  self.backButton = [self makeButton:@"ic_back" action:@selector(back)];
  self.forwardButton = [self makeButton:@"ic_forward" action:@selector(forward)];
  self.reloadOrStopButton = [self makeButton:@"ic_reload" action:@selector(reloadOrStop)];
  self.menuButton = [self makeButton:@"ic_menu" action:@selector(showMainMenu)];
  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateDownloadAttentionBadge) name:@"BlinkDownloadAttentionChanged" object:nil];
  [self updateDownloadAttentionBadge];
  self.urlField = [self makeURLBar];
  [self.view addSubview:_toolbarBackgroundView];
  [_toolbarBackgroundView addArrangedSubview:_toolbarContentView];
  [_toolbarContentView addArrangedSubview:_backButton];
  [_toolbarContentView addArrangedSubview:_forwardButton];
  [_toolbarContentView addArrangedSubview:_reloadOrStopButton];
  [_toolbarContentView addArrangedSubview:_menuButton];
  [_toolbarContentView addArrangedSubview:_urlField];

  self.loadingProgressView = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleBar];
  _loadingProgressView.translatesAutoresizingMaskIntoConstraints = NO;
  _loadingProgressView.progressTintColor = BlinkerAccentColor();
  _loadingProgressView.trackTintColor = UIColor.clearColor;
  _loadingProgressView.hidden = YES;
  [self.view addSubview:_loadingProgressView];

  _toolbarBackgroundView.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[
    [_toolbarBackgroundView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [_toolbarBackgroundView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
  ]];
  _toolbarContentView.translatesAutoresizingMaskIntoConstraints = NO;
  [NSLayoutConstraint activateConstraints:@[ [_toolbarContentView.heightAnchor constraintEqualToAnchor:_backButton.heightAnchor multiplier:2.0] ]];

  _contentView.translatesAutoresizingMaskIntoConstraints = NO;
  self.contentHorizontalConstraints = @[
    [_contentView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor],
    [_contentView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor],
  ];
  [NSLayoutConstraint activateConstraints:_contentHorizontalConstraints];
  [self applyToolbarPosition];

  self.harnessWeb = [[MockWebView alloc] init];
  self.harnessWeb.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  [_contentView addSubview:self.harnessWeb];
  self.harnessWeb.frame = _contentView.bounds;

  [self setURL:self.harnessURL ?: @""];
}

- (UIButton*)makeButton:(NSString*)imageName action:(SEL)action {
  UIButton* button = [UIButton buttonWithType:UIButtonTypeSystem];
  UIImage* image = [UIImage imageNamed:imageName];
  if (image) {
    image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  } else {
    NSString* fallback = @"?";
    if ([imageName isEqualToString:@"ic_back"]) {
      fallback = @"‹";
    } else if ([imageName isEqualToString:@"ic_forward"]) {
      fallback = @"›";
    } else if ([imageName isEqualToString:@"ic_reload"]) {
      fallback = @"↻";
    } else if ([imageName isEqualToString:@"ic_stop"]) {
      fallback = @"×";
    } else if ([imageName isEqualToString:@"ic_menu"]) {
      fallback = @"⋮";
    }
    [button setTitle:fallback forState:UIControlStateNormal];
    button.titleLabel.font = [UIFont boldSystemFontOfSize:28.0];
  }
  [button setImage:image forState:UIControlStateNormal];
  button.tintColor = [UIColor whiteColor];
  button.imageView.tintColor = [UIColor whiteColor];
  [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
  [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
  return button;
}

- (UITextField*)makeURLBar {
  UITextField* field = [[UITextField alloc] init];
  field.placeholder = @"Search or type URL";
  field.borderStyle = UITextBorderStyleRoundedRect;
  field.keyboardType = UIKeyboardTypeWebSearch;
  field.delegate = self;
  return field;
}

- (UIStackView*)createToolbarBackgroundView {
  UIStackView* stack = [[UIStackView alloc] init];
  stack.backgroundColor = BlinkerThemeColor();
  UIView* paint = [[UIView alloc] init];
  paint.translatesAutoresizingMaskIntoConstraints = NO;
  paint.backgroundColor = BlinkerThemeColor();
  [stack addSubview:paint];
  [NSLayoutConstraint activateConstraints:@[
    [paint.topAnchor constraintEqualToAnchor:stack.topAnchor],
    [paint.bottomAnchor constraintEqualToAnchor:stack.bottomAnchor],
    [paint.leadingAnchor constraintEqualToAnchor:stack.leadingAnchor],
    [paint.trailingAnchor constraintEqualToAnchor:stack.trailingAnchor],
  ]];
  self.toolbarPaintView = paint;
  stack.alignment = UIStackViewAlignmentBottom;
  stack.axis = UILayoutConstraintAxisHorizontal;
  stack.layoutMarginsRelativeArrangement = YES;
  stack.preservesSuperviewLayoutMargins = YES;
  return stack;
}

- (UIStackView*)createToolbarContentView {
  UIStackView* stack = [[UIStackView alloc] init];
  stack.backgroundColor = BlinkerThemeColor();
  stack.alignment = UIStackViewAlignmentCenter;
  stack.axis = UILayoutConstraintAxisHorizontal;
  stack.spacing = 16.0;
  return stack;
}

- (void)applyToolbarPosition {
  if (!_contentView || !_loadingProgressView) {
    return;
  }
  [NSLayoutConstraint deactivateConstraints:_topPosConstraints];
  [NSLayoutConstraint deactivateConstraints:_bottomPosConstraints];
  BOOL bottom = [[NSUserDefaults standardUserDefaults] boolForKey:@"BlinkToolbarBottom"];
  [NSLayoutConstraint deactivateConstraints:_loadingProgressConstraints];
  _loadingProgressConstraints = @[
    [_loadingProgressView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [_loadingProgressView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    bottom ? [_loadingProgressView.bottomAnchor constraintEqualToAnchor:_toolbarBackgroundView.topAnchor]
           : [_loadingProgressView.topAnchor constraintEqualToAnchor:_toolbarBackgroundView.bottomAnchor],
    [_loadingProgressView.heightAnchor constraintEqualToConstant:2],
  ];
  [NSLayoutConstraint activateConstraints:_loadingProgressConstraints];
  _topPosConstraints = @[
    [_toolbarBackgroundView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
    [_contentView.topAnchor constraintEqualToAnchor:_toolbarBackgroundView.bottomAnchor],
    [_contentView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-_keyboardViewportInset],
  ];
  _bottomPosConstraints = @[
    [_toolbarBackgroundView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    [_contentView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
    [_contentView.bottomAnchor constraintEqualToAnchor:_toolbarBackgroundView.topAnchor],
  ];
  [NSLayoutConstraint activateConstraints:bottom ? _bottomPosConstraints : _topPosConstraints];
}

- (void)setKeyboardViewportInset:(CGFloat)inset {
  _keyboardViewportInset = MAX((CGFloat)0, inset);
  [self applyToolbarPosition];
}

- (void)setPageLoading:(BOOL)loading {
  if (!_loadingProgressView) {
    return;
  }
  _loadingProgressView.hidden = !loading;
}

- (void)setURL:(NSString*)url {
  BOOL isStartPage = (url.length == 0) || [url isEqualToString:@"about:blank"];
  [self showStartPage:isStartPage];
  _urlField.text = isStartPage ? @"" : url;
  self.harnessURL = url;
  self.harnessWeb.pageTitle = [NSURL URLWithString:url].host ?: @"Example Domain";
  [self.harnessWeb setNeedsDisplay];
}

- (void)ensureStartPage {
  if (_startPage || !_contentView) {
    return;
  }
  _startPage = [[BlinkerStartPageView alloc] initWithFrame:_contentView.bounds];
  _startPage.backgroundColor = [UIColor colorWithWhite:0.06 alpha:1];
  [_contentView addSubview:_startPage];
}

- (void)showStartPage:(BOOL)show {
  [self ensureStartPage];
  _startPage.hidden = !show;
  if (show) {
    [_contentView bringSubviewToFront:_startPage];
  }
}

- (void)updateDownloadAttentionBadge {
  if (!_menuButton) {
    return;
  }
  UIView* old = [_menuButton viewWithTag:0xB11D];
  if (![[NSUserDefaults standardUserDefaults] boolForKey:@"BlinkDownloadAttention"]) {
    [old removeFromSuperview];
  }
}

- (void)back { Note(@"back"); }
- (void)forward { Note(@"forward"); }
- (void)reloadOrStop { Note(@"reload"); }
- (void)showTabWindow:(void*)shell { Note(@"showTabWindow"); }
- (void)openNewTab { Note(@"openNewTab"); }
- (void)closeCurrentTab { Note(@"closeCurrentTab"); }
- (void)handleURLBarSwipe:(id)gesture { Note(@"swipe"); }
- (void)presentSearchEngineMenu { Note(@"searchEngineMenu"); }
- (void)switchToTab:(void*)shell direction:(NSInteger)direction { Note(@"switchToTab"); }
- (void)applyWebColorScheme:(NSInteger)style { Note(@"applyWebColorScheme"); }

- (void)openUserInput:(NSString*)input {
  Note([@"open " stringByAppendingString:input ?: @""]);
  NSString* url = [input containsString:@"://"] ? input : [@"https://" stringByAppendingString:input];
  [self setURL:url];
}

- (void)presentList:(BlinkListVC*)vc {
  UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:vc];
  [self presentViewController:nav animated:YES completion:nil];
}

// Copied from the stock showMainMenu (the data and the popover presentation), with the engine-derived values fixed.
- (void)showMainMenu {
  __weak ContentShellWindowDelegate* weakSelf = self;
  BlinkListVC* vc = [[BlinkListVC alloc] init];
  vc.title = BlinkL(@"Menu");
  vc.compactRows = YES;
  vc.dismissOnSelect = NO;
  vc.titles = [@[
    @"Google Account", BlinkL(@"Reload"), BlinkL(@"New Tab"), @"Tabs (4)", BlinkL(@"Home"), BlinkL(@"Private Browsing"), BlinkL(@"Bookmarks"),
    BlinkL(@"Downloads"), BlinkL(@"Request Desktop Page"), @"Page Zoom (100%)", BlinkL(@"Find in Page"), BlinkL(@"Share Link"), BlinkL(@"Settings"),
    BlinkL(@"Check for Updates")
  ] mutableCopy];
  vc.subtitles = [@[
    @"Add or manage your saved sign-in", @"", @"", @"", @"", BlinkL(@"Off"), @"", @"", @"", @"", @"", @"", @"", BlinkL(@"Latest GitHub release")
  ] mutableCopy];
  vc.imageNames = @[
    @"person.crop.circle.badge.plus", @"arrow.clockwise", @"plus", @"square.on.square", @"house", @"eye.slash", @"bookmark", @"arrow.down.circle",
    @"desktopcomputer", @"textformat.size", @"magnifyingglass", @"square.and.arrow.up", @"gearshape", @"arrow.triangle.2.circlepath"
  ];
  vc.rowImages = @[
    [NSNull null], [NSNull null], [NSNull null], [NSNull null], [NSNull null], [NSNull null], [NSNull null], [NSNull null], [NSNull null],
    [NSNull null], [NSNull null], [NSNull null], [NSNull null], [NSNull null]
  ];
  vc.sectionTitles = @[ @"ACCOUNT", BlinkL(@"BROWSER"), BlinkL(@"LIBRARY"), BlinkL(@"APP") ];
  vc.sectionStarts = @[ @0, @1, @6, @12 ];
  vc.badgedRows = [NSIndexSet indexSetWithIndex:7];
  __weak BlinkListVC* weakMenu = vc;
  vc.onSelect = ^(NSInteger row) {
    void (^dismissThen)(dispatch_block_t) = ^(dispatch_block_t action) {
      [weakMenu.navigationController dismissViewControllerAnimated:YES completion:action];
    };
    Note([NSString stringWithFormat:@"menu row %ld", (long)row]);
    if (row == 2) {
      dismissThen(^{
        [weakSelf openNewTab];
      });
    } else if (row == 6 || row == 7 || row == 11) {
      dismissThen(^{
        Note(@"menu action done");
      });
    }
  };
  UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:vc];
  self.lastStockMenuNav = nav;
  nav.modalPresentationStyle = UIModalPresentationPopover;
  nav.preferredContentSize = CGSizeMake(MIN(340, self.view.bounds.size.width - 36), MIN(500, self.view.bounds.size.height - 130));
  UIColor* menuChrome = [UIColor colorWithWhite:0.09 alpha:1.0];
  vc.tableView.backgroundColor = menuChrome;
  vc.tableView.contentInset = UIEdgeInsetsMake(0, 0, 14, 0);
  vc.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 14)];
  UIPopoverPresentationController* popover = nav.popoverPresentationController;
  popover.delegate = self;
  popover.sourceView = _menuButton;
  popover.sourceRect = _menuButton.bounds;
  popover.backgroundColor = menuChrome;
  [self presentViewController:nav animated:YES completion:nil];
}

- (UIModalPresentationStyle)adaptivePresentationStyleForPresentationController:(UIPresentationController*)controller {
  return UIModalPresentationNone;
}

// Same shape as the stock showTabSwitcher: a BlinkTabsVC with titles / urls / previews and the four callbacks.
- (void)showTabSwitcher {
  UICollectionViewFlowLayout* layout = [[UICollectionViewFlowLayout alloc] init];
  CGFloat cardWidth = floor((MIN(self.view.bounds.size.width, 600) - 44) / 2);
  layout.itemSize = CGSizeMake(cardWidth, cardWidth * 1.34);
  BlinkTabsVC* vc = [[BlinkTabsVC alloc] initWithCollectionViewLayout:layout];
  vc.titles = [@[ @"Example Domain", @"GitHub", @"Wikipedia", @"New Tab" ] mutableCopy];
  vc.urls = [@[ @"https://example.com/", @"https://github.com/", @"https://ja.wikipedia.org/", @"about:blank" ] mutableCopy];
  if (self.harnessTabCount == 1) {
    [vc.titles removeObjectsInRange:NSMakeRange(1, 3)];
    [vc.urls removeObjectsInRange:NSMakeRange(1, 3)];
  }
  vc.previews = [NSMutableArray array];
  NSArray<UIColor*>* colors = @[ [UIColor colorWithRed:0.1 green:0.4 blue:0.9 alpha:1], [UIColor colorWithWhite:0.15 alpha:1], [UIColor colorWithWhite:0.96 alpha:1], [UIColor clearColor] ];
  CGSize size = self.view.bounds.size;
  for (NSUInteger i = 0; i < vc.titles.count; i++) {
    MockWebView* web = [[MockWebView alloc] initWithFrame:CGRectMake(0, 0, size.width, size.height)];
    web.accentColor = colors[i];
    web.pageTitle = vc.titles[i];
    UIGraphicsImageRenderer* renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(320, 320 * size.height / size.width)];
    UIImage* image = [renderer imageWithActions:^(UIGraphicsImageRendererContext* ctx) {
      CGContextScaleCTM(ctx.CGContext, 320 / size.width, 320 / size.width);
      [web.layer renderInContext:ctx.CGContext];
    }];
    [vc.previews addObject:image];
  }
  vc.onSelect = ^(NSInteger i) { Note([NSString stringWithFormat:@"select tab %ld", (long)i]); };
  vc.onAdd = ^{ Note(@"add tab"); };
  vc.onReorder = ^(NSInteger from, NSInteger to) { Note([NSString stringWithFormat:@"reorder %ld->%ld", (long)from, (long)to]); };
  vc.onClose = ^BOOL(NSInteger i) {
    Note([NSString stringWithFormat:@"close tab %ld", (long)i]);
    return i != 0;
  };
  UINavigationController* nav = [[UINavigationController alloc] initWithRootViewController:vc];
  nav.modalPresentationStyle = UIModalPresentationFullScreen;
  [self presentViewController:nav animated:YES completion:nil];
}

@end
