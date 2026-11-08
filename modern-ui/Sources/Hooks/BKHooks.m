// SPDX-License-Identifier: GPL-3.0-or-later
//
// The hooks: how the modern UI attaches itself to the stock classes.  Nothing here is installed unless every entry of
// BKContract.inc is present with the expected signature in the running binary.

#import "BKHooks.h"
#import "BKChrome.h"
#import "BKCore.h"
#import "BKListStyle.h"
#import "BKSettings.h"
#import "BKStartPageView.h"
#import "BKTabGrid.h"
#import "BKTheme.h"
#import <objc/message.h>
#import <objc/runtime.h>

// ---------------------------------------------------------------------------------------------------- the contract

typedef struct {
  const char *cls;
  const char *sel;
  const char *shape;
} BKMethodRequirement;
typedef struct {
  const char *cls;
  const char *name;
} BKIvarRequirement;

static const BKMethodRequirement kMethodRequirements[] = {
#define BK_METHOD(c, s, sh) {c, s, sh},
#define BK_IVAR(c, n)
#include "BKContract.inc"
#undef BK_METHOD
#undef BK_IVAR
};

static const BKIvarRequirement kIvarRequirements[] = {
#define BK_METHOD(c, s, sh)
#define BK_IVAR(c, n) {c, n},
#include "BKContract.inc"
#undef BK_METHOD
#undef BK_IVAR
};

static NSString *BKShape(const char *types) {
  NSMutableString *shape = [NSMutableString string];
  for (const char *p = types; p && *p; p++) {
    if (!(*p >= '0' && *p <= '9')) {
      [shape appendFormat:@"%c", *p];
    }
  }
  return shape;
}

static BOOL BKContractHolds(void) {
  BOOL ok = YES;
  for (size_t i = 0; i < sizeof(kMethodRequirements) / sizeof(kMethodRequirements[0]); i++) {
    const BKMethodRequirement *r = &kMethodRequirements[i];
    Class cls = objc_getClass(r->cls);
    Method m = cls ? class_getInstanceMethod(cls, sel_registerName(r->sel)) : NULL;
    if (!m) {
      BKLog(@"contract: -[%s %s] is missing", r->cls, r->sel);
      ok = NO;
    } else if (![BKShape(method_getTypeEncoding(m)) isEqualToString:@(r->shape)]) {
      BKLog(@"contract: -[%s %s] is %@ but %s was expected", r->cls, r->sel, BKShape(method_getTypeEncoding(m)), r->shape);
      ok = NO;
    }
  }
  for (size_t i = 0; i < sizeof(kIvarRequirements) / sizeof(kIvarRequirements[0]); i++) {
    const BKIvarRequirement *r = &kIvarRequirements[i];
    Class cls = objc_getClass(r->cls);
    if (!cls || !class_getInstanceVariable(cls, r->name)) {
      BKLog(@"contract: ivar %s.%s is missing", r->cls, r->name);
      ok = NO;
    }
  }
  return ok;
}

// --------------------------------------------------------------------------------------------- original implementations

static void (*orig_viewDidLoad)(id, SEL);
static void (*orig_applyToolbarPosition)(id, SEL);
static void (*orig_setURL)(id, SEL, NSString *);
static void (*orig_setPageLoading)(id, SEL, BOOL);
static id (*orig_backButton)(id, SEL);
static id (*orig_forwardButton)(id, SEL);
static id (*orig_reloadOrStopButton)(id, SEL);
static id (*orig_menuButton)(id, SEL);
static id (*orig_toolbarBackgroundView)(id, SEL);
static void (*orig_updateDownloadAttentionBadge)(id, SEL);
static void (*orig_ensureStartPage)(id, SEL);
static void (*orig_showStartPage)(id, SEL, BOOL);
static id (*orig_startPage)(id, SEL);
static void (*orig_switchToTab)(id, SEL, void *, NSInteger);
static void (*orig_showTabWindow)(id, SEL, void *);
static void (*orig_openNewTab)(id, SEL);
static void (*orig_closeCurrentTab)(id, SEL);
static void (*orig_applyWebColorScheme)(id, SEL, NSInteger);
static NSInteger (*orig_statusBarStyle)(id, SEL);
static void (*orig_viewDidLayoutSubviews)(id, SEL);
static void (*orig_traitCollectionDidChange)(id, SEL, UITraitCollection *);
static void (*orig_present)(id, SEL, UIViewController *, BOOL, void (^)(void));

static Class gHostClass;
static Class gTabsClass;

static const void *kStartPageKey = &kStartPageKey;

// ------------------------------------------------------------------------------------------------------------ helpers

static void BKRefreshAllTabCounts(void) {
  if (!gHostClass) {
    return;
  }
  for (UIWindow *window in UIApplication.sharedApplication.windows) {
    UIViewController *root = window.rootViewController;
    if ([root isKindOfClass:gHostClass]) {
      [[BKChrome chromeForHost:root] refreshTabCount];
    }
  }
}

// ---------------------------------------------------------------------------------------------------------- the hooks

static void hook_viewDidLoad(id self, SEL _cmd) {
  orig_viewDidLoad(self, _cmd);
  @try {
    [BKChrome installOnHost:self];
  } @catch (NSException *exception) {
    BKLog(@"chrome install threw: %@ - %@", exception.name, exception.reason);
    @try {
      [BKChrome rollbackHost:self];
    } @catch (NSException *again) {
      BKLog(@"rollback threw: %@", again);
    }
  }
}

static void hook_applyToolbarPosition(id self, SEL _cmd) {
  BKChrome *chrome = [BKChrome chromeForHost:self];
  if (!chrome) {
    orig_applyToolbarPosition(self, _cmd);  // stock layout (not installed, or not installable on this tab)
    return;
  }
  @try {
    [chrome applyLayout];
  } @catch (NSException *exception) {
    BKLog(@"applyLayout threw: %@ - %@", exception.name, exception.reason);
  }
}

static void hook_setURL(id self, SEL _cmd, NSString *url) {
  orig_setURL(self, _cmd, url);
  [[BKChrome chromeForHost:self] setURLString:url];
}

static void hook_setPageLoading(id self, SEL _cmd, BOOL loading) {
  orig_setPageLoading(self, _cmd, loading);
  [[BKChrome chromeForHost:self] setLoading:loading];
}

#define BK_BUTTON_HOOK(name, property)                        \
  static id hook_##name(id self, SEL _cmd) {                  \
    BKChrome *chrome = [BKChrome chromeForHost:self];         \
    return chrome ? chrome.property : orig_##name(self, _cmd); \
  }
BK_BUTTON_HOOK(backButton, backButton)
BK_BUTTON_HOOK(forwardButton, forwardButton)
BK_BUTTON_HOOK(reloadOrStopButton, reloadButton)
BK_BUTTON_HOOK(menuButton, menuButton)
BK_BUTTON_HOOK(toolbarBackgroundView, toggleProxy)

static void hook_updateDownloadAttentionBadge(id self, SEL _cmd) {
  BKChrome *chrome = [BKChrome chromeForHost:self];
  if (chrome) {
    [chrome updateDownloadBadge];
  } else {
    orig_updateDownloadAttentionBadge(self, _cmd);
  }
}

// ---- the start page: our own view replaces BlinkerStartPageView entirely

static BKStartPageView *BKStartPageOf(id host) {
  return objc_getAssociatedObject(host, kStartPageKey);
}

static void BKEnsureStartPage(id host) {
  if (BKStartPageOf(host)) {
    return;
  }
  UIView *content = [(id<BKStockHost>)host contentView];
  if (!content) {
    return;
  }
  BKStartPageView *page = [[BKStartPageView alloc] initWithFrame:content.bounds];
  page.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
  __weak id weakHost = host;
  page.onNavigate = ^(NSString *input) { [(id<BKStockHost>)weakHost openUserInput:input]; };
  page.onSearchTapped = ^{ [[BKChrome chromeForHost:weakHost] showOmnibox]; };
  [content addSubview:page];
  objc_setAssociatedObject(host, kStartPageKey, page, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void hook_ensureStartPage(id self, SEL _cmd) {
  if (![BKChrome chromeForHost:self] && !BKStartPageOf(self)) {
    orig_ensureStartPage(self, _cmd);  // chrome not installed on this tab: keep the stock page
    return;
  }
  BKEnsureStartPage(self);
}

static void hook_showStartPage(id self, SEL _cmd, BOOL show) {
  BKChrome *chrome = [BKChrome chromeForHost:self];
  // During the stock viewDidLoad the chrome does not exist yet but will in a moment: decide by "is this a controller we manage".
  BOOL managed = chrome != nil || BKStartPageOf(self) != nil || BKGetIvar(self, "_toolbarBackgroundView") != nil;
  if (!managed) {
    orig_showStartPage(self, _cmd, show);
    return;
  }
  BKEnsureStartPage(self);
  BKStartPageView *page = BKStartPageOf(self);
  page.hidden = !show;
  if (show) {
    [[(id<BKStockHost>)self contentView] bringSubviewToFront:page];
  }
}

static id hook_startPage(id self, SEL _cmd) {
  return BKStartPageOf(self) ?: orig_startPage(self, _cmd);
}

// ---- tabs

static void hook_switchToTab(id self, SEL _cmd, void *shell, NSInteger direction) {
  BKChrome *chrome = [BKChrome chromeForHost:self];
  void *current = ((void *(*)(id, SEL))objc_msgSend)(self, @selector(shell));
  if (!chrome || !shell || shell == current) {
    orig_switchToTab(self, _cmd, shell, direction);
    return;
  }
  [chrome slidePillOutToward:direction
                  completion:^{
                    ((void (*)(id, SEL, void *))objc_msgSend)(self, @selector(showTabWindow:), shell);
                    UIViewController *incoming = UIApplication.sharedApplication.keyWindow.rootViewController;
                    [[BKChrome chromeForHost:incoming] slidePillInFrom:direction];
                  }];
}

static void hook_showTabWindow(id self, SEL _cmd, void *shell) {
  orig_showTabWindow(self, _cmd, shell);
  BKRefreshAllTabCounts();
}

static void hook_openNewTab(id self, SEL _cmd) {
  orig_openNewTab(self, _cmd);
  BKRefreshAllTabCounts();
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ BKRefreshAllTabCounts(); });
}

static void hook_closeCurrentTab(id self, SEL _cmd) {
  orig_closeCurrentTab(self, _cmd);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ BKRefreshAllTabCounts(); });
}

// ---- appearance

static void hook_applyWebColorScheme(id self, SEL _cmd, NSInteger style) {
  orig_applyWebColorScheme(self, _cmd, style);
  dispatch_async(dispatch_get_main_queue(), ^{ [BKTheme notifyChanged]; });
}

static NSInteger hook_statusBarStyle(id self, SEL _cmd) {
  if ([BKChrome chromeForHost:self]) {
    return [BKTheme statusBarStyle];
  }
  return orig_statusBarStyle ? orig_statusBarStyle(self, _cmd) : UIStatusBarStyleDefault;
}

static void hook_viewDidLayoutSubviews(id self, SEL _cmd) {
  orig_viewDidLayoutSubviews(self, _cmd);
  [[BKChrome chromeForHost:self] layoutDidChange];
}

static void hook_traitCollectionDidChange(id self, SEL _cmd, UITraitCollection *previous) {
  orig_traitCollectionDidChange(self, _cmd, previous);
  if ([BKChrome chromeForHost:self]) {
    dispatch_async(dispatch_get_main_queue(), ^{ [BKTheme notifyChanged]; });
  }
}

// ---- presentations: the stock menu and tab switcher are turned into the modern ones

static UIViewController *BKReplacementForPresentation(id host, UIViewController *presented, void (^__autoreleasing *completion)(void)) {
  if (![presented isKindOfClass:[UINavigationController class]]) {
    return nil;
  }
  UINavigationController *nav = (UINavigationController *)presented;
  UIViewController *root = nav.viewControllers.firstObject;
  BKChrome *chrome = [BKChrome chromeForHost:host];
  if (!root || !chrome) {
    return nil;
  }
  if (gTabsClass && [root isKindOfClass:gTabsClass] && BKFeatureAllowed(@"tabgrid")) {
    UIView *window = [host view].window ?: [host view];
    CGFloat height = MAX(window.bounds.size.height, 1);
    CGFloat top = chrome.topBar.superview ? CGRectGetMaxY(chrome.topBar.frame) / height : 0;
    CGFloat bottom = chrome.bottomBar.superview ? (height - CGRectGetMinY(chrome.bottomBar.frame)) / height : 0;
    BKFeatureBegin(@"tabgrid");
    void (^previous)(void) = *completion;
    *completion = ^{
      if (previous) {
        previous();
      }
      BKFeatureEnd(@"tabgrid");
    };
    return [[BKTabGridViewController alloc] initWithStockTabs:root currentURL:chrome.urlString cropTop:top cropBottom:bottom];
  }
  if ([BKListStyle isMainMenuList:root] && BKFeatureAllowed(@"menu")) {
    BKFeatureBegin(@"menu");
    [BKListStyle prepareMenuNavigation:nav];
    void (^previous)(void) = *completion;
    *completion = ^{
      if (previous) {
        previous();
      }
      BKFeatureEnd(@"menu");
    };
    return nav;
  }
  return nil;
}

static void hook_present(id self, SEL _cmd, UIViewController *presented, BOOL animated, void (^completion)(void)) {
  UIViewController *replacement = nil;
  void (^wrapped)(void) = completion;
  @try {
    replacement = BKReplacementForPresentation(self, presented, &wrapped);
  } @catch (NSException *exception) {
    BKLog(@"presentation replacement threw: %@ - %@", exception.name, exception.reason);
    replacement = nil;
    wrapped = completion;
  }
  orig_present(self, _cmd, replacement ?: presented, animated, replacement ? wrapped : completion);
}

// ------------------------------------------------------------------------------------------------------------ install

void BKInstallHooks(void) {
  if (!BKContractHolds()) {
    BKLog(@"hooks: the stock binary does not match the contract - the stock UI stays in charge");
    return;
  }
  gHostClass = objc_getClass("ContentShellWindowDelegate");
  gTabsClass = objc_getClass("BlinkTabsVC");

  int installed = 0, total = 0;
#define BK_HOOK(cls, selector, shape, fn, orig)                                         \
  do {                                                                                  \
    total++;                                                                            \
    if (BKHookInstance(cls, NSSelectorFromString(selector), shape, (IMP)fn, (IMP *)&orig)) { \
      installed++;                                                                      \
    }                                                                                   \
  } while (0)
  BK_HOOK(gHostClass, @"viewDidLoad", "v@:", hook_viewDidLoad, orig_viewDidLoad);
  BK_HOOK(gHostClass, @"applyToolbarPosition", "v@:", hook_applyToolbarPosition, orig_applyToolbarPosition);
  BK_HOOK(gHostClass, @"setURL:", "v@:@", hook_setURL, orig_setURL);
  BK_HOOK(gHostClass, @"setPageLoading:", "v@:B", hook_setPageLoading, orig_setPageLoading);
  BK_HOOK(gHostClass, @"backButton", "@@:", hook_backButton, orig_backButton);
  BK_HOOK(gHostClass, @"forwardButton", "@@:", hook_forwardButton, orig_forwardButton);
  BK_HOOK(gHostClass, @"reloadOrStopButton", "@@:", hook_reloadOrStopButton, orig_reloadOrStopButton);
  BK_HOOK(gHostClass, @"menuButton", "@@:", hook_menuButton, orig_menuButton);
  BK_HOOK(gHostClass, @"toolbarBackgroundView", "@@:", hook_toolbarBackgroundView, orig_toolbarBackgroundView);
  BK_HOOK(gHostClass, @"updateDownloadAttentionBadge", "v@:", hook_updateDownloadAttentionBadge, orig_updateDownloadAttentionBadge);
  BK_HOOK(gHostClass, @"ensureStartPage", "v@:", hook_ensureStartPage, orig_ensureStartPage);
  BK_HOOK(gHostClass, @"showStartPage:", "v@:B", hook_showStartPage, orig_showStartPage);
  BK_HOOK(gHostClass, @"startPage", "@@:", hook_startPage, orig_startPage);
  BK_HOOK(gHostClass, @"switchToTab:direction:", "v@:^vq", hook_switchToTab, orig_switchToTab);
  BK_HOOK(gHostClass, @"showTabWindow:", "v@:^v", hook_showTabWindow, orig_showTabWindow);
  BK_HOOK(gHostClass, @"openNewTab", "v@:", hook_openNewTab, orig_openNewTab);
  BK_HOOK(gHostClass, @"closeCurrentTab", "v@:", hook_closeCurrentTab, orig_closeCurrentTab);
  BK_HOOK(gHostClass, @"applyWebColorScheme:", "v@:q", hook_applyWebColorScheme, orig_applyWebColorScheme);
  // inherited from UIViewController: BKHookInstance adds our version to the class and keeps UIKit's as the original
  BK_HOOK(gHostClass, @"preferredStatusBarStyle", "q@:", hook_statusBarStyle, orig_statusBarStyle);
  BK_HOOK(gHostClass, @"viewDidLayoutSubviews", "v@:", hook_viewDidLayoutSubviews, orig_viewDidLayoutSubviews);
  BK_HOOK(gHostClass, @"traitCollectionDidChange:", "v@:@", hook_traitCollectionDidChange, orig_traitCollectionDidChange);
  BK_HOOK(gHostClass, @"presentViewController:animated:completion:", "v@:@B@?", hook_present, orig_present);
#undef BK_HOOK
  BKLog(@"hooks: %d of %d installed on ContentShellWindowDelegate", installed, total);
  [BKListStyle installHooks];
}
