// Simulator harness: runs the real hook installer against the stock replica, walks through the screens and saves a picture of
// each one (plus a contact sheet).  Variants (launch argument  -bk-variant <name>):
//   light | dark | bottom | private | ja | landscape
#import <UIKit/UIKit.h>
#import <objc/message.h>
#import "BKChrome.h"
#import "BKCore.h"
#import "BKHooks.h"
#import "BKTheme.h"

extern NSArray<NSString *> *HarnessLog(void);

@protocol HarnessHost <BKStockHost>
- (void)setURL:(NSString *)url;
- (void)setPageLoading:(BOOL)loading;
- (UIButton *)backButton;
- (UIButton *)forwardButton;
- (void)presentList:(id)vc;
@end

// BlinkListVC comes from the stock code; build a settings-like list with it.
@interface UIViewController (HarnessList)
@end

@interface HarnessApp : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation HarnessApp {
  NSString *_variant;
  UIViewController<HarnessHost> *_host;
  NSMutableArray<NSString *> *_names;
  NSMutableArray<UIImage *> *_images;
  NSMutableArray<NSString *> *_checks;
  CGSize _size;
}

- (UIImage *)snapshot {
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:_size];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    [self.window drawViewHierarchyInRect:CGRectMake(0, 0, self->_size.width, self->_size.height) afterScreenUpdates:YES];
  }];
}

- (NSString *)shotsDirectory {
  NSString *dir = [BKDocumentsPath() stringByAppendingPathComponent:@"shots"];
  [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  return dir;
}

- (void)capture:(NSString *)name {
  UIImage *image = [self snapshot];
  [_names addObject:name];
  [_images addObject:image];
  NSString *file = [NSString stringWithFormat:@"%@-%02lu-%@.png", _variant, (unsigned long)_images.count, name];
  [UIImagePNGRepresentation(image) writeToFile:[[self shotsDirectory] stringByAppendingPathComponent:file] atomically:YES];
}

- (void)writeContactSheet {
  const CGFloat scale = 0.8;
  const NSInteger columns = _size.width > _size.height ? 3 : 4;
  const CGFloat cellW = _size.width * scale + 12, cellH = _size.height * scale + 30;
  const NSInteger rows = (NSInteger)((_images.count + columns - 1) / columns);
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
  format.scale = 1;
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(cellW * columns + 12, cellH * rows + 12) format:format];
  UIImage *sheet = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    [[UIColor colorWithWhite:0.5 alpha:1] setFill];
    UIRectFill(CGRectMake(0, 0, cellW * columns + 12, cellH * rows + 12));
    for (NSUInteger i = 0; i < self->_images.count; i++) {
      CGFloat x = 12 + (i % columns) * cellW, y = 12 + (i / columns) * cellH;
      [self->_names[i] drawAtPoint:CGPointMake(x, y) withAttributes:@{NSFontAttributeName : [UIFont boldSystemFontOfSize:13], NSForegroundColorAttributeName : UIColor.whiteColor}];
      [self->_images[i] drawInRect:CGRectMake(x, y + 20, self->_size.width * scale, self->_size.height * scale)];
    }
  }];
  [UIImagePNGRepresentation(sheet) writeToFile:[[self shotsDirectory] stringByAppendingPathComponent:[_variant stringByAppendingString:@"-sheet.png"]] atomically:YES];
}

- (void)check:(NSString *)name ok:(BOOL)ok detail:(NSString *)detail {
  [_checks addObject:[NSString stringWithFormat:@"%@ %@%@", ok ? @"PASS" : @"FAIL", name, detail.length ? [@" - " stringByAppendingString:detail] : @""]];
}

- (BOOL)near:(CGFloat)a to:(CGFloat)b {
  return fabs(a - b) < 1.0;
}

// The content view must sit exactly between the bars (or fill the screen when the chrome is hidden).
- (void)checkLayout:(NSString *)label {
  [_host.view layoutIfNeeded];
  BKChrome *chrome = [BKChrome chromeForHost:_host];
  UIView *content = [_host contentView];
  CGRect c = content.frame;
  CGFloat top = chrome.topBar.hidden ? 0 : CGRectGetMaxY(chrome.topBar.frame);
  CGFloat bottom = chrome.bottomBar.hidden ? _host.view.bounds.size.height : CGRectGetMinY(chrome.bottomBar.frame);
  [self check:[label stringByAppendingString:@": content between the bars"] ok:[self near:c.origin.y to:top] && [self near:CGRectGetMaxY(c) to:bottom] && [self near:c.size.width to:_host.view.bounds.size.width]
       detail:[NSString stringWithFormat:@"content %@ expected y %.0f..%.0f", NSStringFromCGRect(c), top, bottom]];
}

- (void)finish {
  [self writeContactSheet];
  [[_checks componentsJoinedByString:@"\n"] writeToFile:[[self shotsDirectory] stringByAppendingPathComponent:[_variant stringByAppendingString:@"-checks.txt"]] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  NSString *log = [HarnessLog() componentsJoinedByString:@"\n"];
  [log writeToFile:[[self shotsDirectory] stringByAppendingPathComponent:[_variant stringByAppendingString:@"-log.txt"]] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [@"done" writeToFile:[[self shotsDirectory] stringByAppendingPathComponent:[_variant stringByAppendingString:@".done"]] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ exit(0); });
}

- (void)seedDefaults {
  NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
  BOOL dark = [_variant isEqualToString:@"dark"];
  [d setInteger:dark ? 2 : 1 forKey:@"BlinkAppearance"];
  [d setBool:[_variant isEqualToString:@"bottom"] forKey:@"BlinkToolbarBottom"];
  [d setBool:[_variant isEqualToString:@"private"] forKey:@"BlinkPrivateBrowsing"];
  [d setObject:[_variant isEqualToString:@"ja"] ? @"ja-JP,ja,en" : @"en-US,en" forKey:@"BlinkLanguageAccept"];
  [d setBool:YES forKey:@"BlinkDownloadAttention"];
  [d setObject:@[ @"https://github.com/Nodesclock/Blinker-Fluid", @"https://ja.wikipedia.org/wiki/iPod_touch", @"https://news.ycombinator.com/",
                   @"https://www.reddit.com/r/jailbreak/", @"https://example.com/docs/index.html" ]
        forKey:@"BlinkHistory"];
  [d setObject:@[ @{@"title" : @"Blinker Fluid", @"url" : @"https://github.com/Nodesclock/Blinker-Fluid"},
                  @{@"title" : @"Folder", @"children" : @[ @{@"title" : @"GitHub Gist", @"url" : @"https://gist.github.com"} ]} ]
        forKey:@"BlinkBookmarks"];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  _variant = [[NSUserDefaults standardUserDefaults] stringForKey:@"bk-variant"] ?: @"light";
  _names = [NSMutableArray array];
  _images = [NSMutableArray array];
  _checks = [NSMutableArray array];
  if ([_variant isEqualToString:@"guardtest"]) {
    [self runGuardTest];
    return YES;
  }
  if ([_variant isEqualToString:@"imetest"]) {
    BKInstallHooks();
    [self runImeTest];
    return YES;
  }
  [self seedDefaults];
  [BKTheme cachePrivateSessionAtLaunch];
  BKInstallHooks();

  const BOOL landscape = [_variant isEqualToString:@"landscape"];
  _size = landscape ? CGSizeMake(568, 320) : CGSizeMake(320, 568);
  CGRect screen = UIScreen.mainScreen.bounds;
  self.window = [[UIWindow alloc] initWithFrame:CGRectMake(floor((screen.size.width - _size.width) / 2), floor((screen.size.height - _size.height) / 2), _size.width, _size.height)];
  self.window.backgroundColor = UIColor.blackColor;

  Class hostClass = NSClassFromString(@"ContentShellWindowDelegate");
  _host = [[hostClass alloc] init];
  if (!landscape) {
    _host.additionalSafeAreaInsets = UIEdgeInsetsMake(20, 0, 0, 0);  // the iPod's status bar
  }
  self.window.rootViewController = _host;
  [self.window makeKeyAndVisible];

  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.8 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{ [self runScenario]; });
  return YES;
}

// The crash guard, driven the way consecutive launches would drive it.
- (void)runGuardTest {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *docs = BKDocumentsPath(), *caches = BKSupportPath();
  for (NSString *name in @[ @"disable-modern-ui", @"enable-modern-ui", @"ModernUI-safe-mode.txt" ]) {
    [fm removeItemAtPath:[docs stringByAppendingPathComponent:name] error:nil];
  }
  for (NSString *name in @[ @"guard.plist", @"launch.marker" ]) {
    [fm removeItemAtPath:[caches stringByAppendingPathComponent:name] error:nil];
  }
  [self check:@"launch A (clean) turns the layer on" ok:BKGuardBeginLaunch() detail:nil];
  [self check:@"launch B after a launch that never became healthy: stock UI once" ok:!BKGuardBeginLaunch() detail:nil];
  [self check:@"launch C tries again" ok:BKGuardBeginLaunch() detail:nil];
  [self check:@"launch D after a second failed launch: off for good" ok:!BKGuardBeginLaunch() detail:nil];
  [self check:@"the safe-mode file explains it" ok:[fm fileExistsAtPath:[docs stringByAppendingPathComponent:@"ModernUI-safe-mode.txt"]] detail:nil];
  [self check:@"launch E stays off" ok:!BKGuardBeginLaunch() detail:nil];
  [@"" writeToFile:[docs stringByAppendingPathComponent:@"enable-modern-ui"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self check:@"enable-modern-ui resets the guard" ok:BKGuardBeginLaunch() detail:nil];
  BKGuardMarkLaunchHealthy();
  [self check:@"a healthy launch clears the marker" ok:![fm fileExistsAtPath:[caches stringByAppendingPathComponent:@"launch.marker"]] detail:nil];
  [self check:@"... and the next launch is normal again" ok:BKGuardBeginLaunch() detail:nil];
  [@"" writeToFile:[docs stringByAppendingPathComponent:@"disable-modern-ui"] atomically:YES encoding:NSUTF8StringEncoding error:nil];
  [self check:@"disable-modern-ui switches the layer off" ok:!BKGuardBeginLaunch() detail:nil];
  for (NSString *name in @[ @"disable-modern-ui", @"enable-modern-ui", @"ModernUI-safe-mode.txt" ]) {
    [fm removeItemAtPath:[docs stringByAppendingPathComponent:name] error:nil];
  }
  for (NSString *name in @[ @"guard.plist", @"launch.marker" ]) {
    [fm removeItemAtPath:[caches stringByAppendingPathComponent:name] error:nil];
  }
  [self finish];
}

// The input-method fix, driven the way the keyboard drives a text input while Japanese is being typed.
- (void)runImeTest {
  id view = [[NSClassFromString(@"RenderWidgetUIView") alloc] init];
  [self check:@"the mock behaves like the engine: no marked range before the fix is needed" ok:YES detail:nil];
  UITextRange *(*markedRange)(id, SEL) = (UITextRange * (*)(id, SEL))objc_msgSend;
  void (*setMarked)(id, SEL, NSString *, NSRange) = (void (*)(id, SEL, NSString *, NSRange))objc_msgSend;
  NSString *(*textIn)(id, SEL, UITextRange *) = (NSString * (*)(id, SEL, UITextRange *))objc_msgSend;
  NSInteger (*offset)(id, SEL, UITextPosition *, UITextPosition *) = (NSInteger(*)(id, SEL, UITextPosition *, UITextPosition *))objc_msgSend;
  UITextPosition *(*moved)(id, SEL, UITextPosition *, NSInteger) = (UITextPosition * (*)(id, SEL, UITextPosition *, NSInteger))objc_msgSend;
  NSInteger (*compare)(id, SEL, UITextPosition *, UITextPosition *) = (NSInteger(*)(id, SEL, UITextPosition *, UITextPosition *))objc_msgSend;
  CGRect (*caret)(id, SEL, UITextPosition *) = (CGRect(*)(id, SEL, UITextPosition *))objc_msgSend;
  CGRect (*firstRect)(id, SEL, UITextRange *) = (CGRect(*)(id, SEL, UITextRange *))objc_msgSend;
  UITextRange *(*rangeFrom)(id, SEL, UITextPosition *, UITextPosition *) = (UITextRange * (*)(id, SEL, UITextPosition *, UITextPosition *))objc_msgSend;

  [self check:@"before typing: no composition" ok:markedRange(view, @selector(markedTextRange)) == nil detail:nil];
  NSArray<NSString *> *steps = @[ @"あ", @"あい", @"あいう" ];   // the keyboard sends the whole composition each time
  NSUInteger n = 0;
  for (NSString *composition in steps) {
    n++;
    setMarked(view, @selector(setMarkedText:selectedRange:), composition, NSMakeRange(composition.length, 0));
    UITextRange *range = markedRange(view, @selector(markedTextRange));
    [self check:[NSString stringWithFormat:@"after key %lu: UIKit is told there is a composition", (unsigned long)n] ok:range != nil && !range.isEmpty detail:nil];
    [self check:[NSString stringWithFormat:@"after key %lu: the composition can be read back", (unsigned long)n]
             ok:[textIn(view, @selector(textInRange:), range) isEqualToString:composition]
         detail:textIn(view, @selector(textInRange:), range)];
    [self check:[NSString stringWithFormat:@"after key %lu: its length is consistent", (unsigned long)n]
             ok:offset(view, @selector(offsetFromPosition:toPosition:), range.start, range.end) == (NSInteger)composition.length
         detail:nil];
  }
  UITextRange *range = markedRange(view, @selector(markedTextRange));
  UITextPosition *inside = moved(view, @selector(positionFromPosition:offset:), range.start, 1);
  [self check:@"a position one character in" ok:offset(view, @selector(offsetFromPosition:toPosition:), range.start, inside) == 1 detail:nil];
  [self check:@"positions are ordered" ok:compare(view, @selector(comparePosition:toPosition:), range.start, inside) == NSOrderedAscending && compare(view, @selector(comparePosition:toPosition:), inside, range.end) == NSOrderedAscending detail:nil];
  UITextRange *tail = rangeFrom(view, @selector(textRangeFromPosition:toPosition:), inside, range.end);
  [self check:@"a range of the composition's tail" ok:[textIn(view, @selector(textInRange:), tail) isEqualToString:@"いう"] detail:textIn(view, @selector(textInRange:), tail)];
  [self check:@"the candidate bar is placed at the caret" ok:CGRectEqualToRect(caret(view, @selector(caretRectForPosition:), range.end), CGRectMake(100, 50, 1, 20)) detail:nil];
  [self check:@"... also by range" ok:CGRectEqualToRect(firstRect(view, @selector(firstRectForRange:), range), CGRectMake(100, 50, 1, 20)) detail:nil];
  UITextRange *stockRange = [view selectedTextRange];
  [self check:@"ordinary (non-composition) ranges still go to the engine" ok:textIn(view, @selector(textInRange:), stockRange) == nil && offset(view, @selector(offsetFromPosition:toPosition:), stockRange.start, stockRange.end) == 0 detail:nil];

  [view unmarkText];
  [self check:@"the confirm key: composition ends" ok:markedRange(view, @selector(markedTextRange)) == nil detail:nil];
  setMarked(view, @selector(setMarkedText:selectedRange:), @"か", NSMakeRange(1, 0));
  [view insertText:@"蚊"];
  [self check:@"a chosen candidate: composition ends" ok:markedRange(view, @selector(markedTextRange)) == nil detail:nil];
  setMarked(view, @selector(setMarkedText:selectedRange:), @"き", NSMakeRange(1, 0));
  [view replaceRange:markedRange(view, @selector(markedTextRange)) withText:@"木"];
  [self check:@"replacing the composition: it ends" ok:markedRange(view, @selector(markedTextRange)) == nil detail:nil];
  [self finish];
}

- (id)findSubview:(NSString *)className in:(UIView *)root {
  if ([NSStringFromClass([root class]) isEqualToString:className]) {
    return root;
  }
  for (UIView *child in root.subviews) {
    id found = [self findSubview:className in:child];
    if (found) {
      return found;
    }
  }
  return nil;
}

- (UIViewController *)topPresented {
  UIViewController *top = _host;
  while (top.presentedViewController) {
    top = top.presentedViewController;
  }
  return top;
}

- (void)runScenario {
  __weak HarnessApp *weakSelf = self;
  NSMutableArray<NSDictionary *> *steps = [NSMutableArray array];
#define STEP(label, wait, ...) [steps addObject:@{@"name" : label, @"wait" : @(wait), @"do" : ^{ __strong HarnessApp *s = weakSelf; (void)s; __VA_ARGS__ }}]
  STEP(@"start", 0.8, {
    [s checkLayout:@"start"];
    BKChrome *chrome = [BKChrome chromeForHost:s->_host];
    [s check:@"chrome installed" ok:chrome != nil detail:nil];
    [s check:@"engine glue gets our back button" ok:[NSStringFromClass([[s->_host backButton] class]) isEqualToString:@"BKBarButton"] detail:NSStringFromClass([[s->_host backButton] class])];
    [s check:@"fullscreen code gets the stand-in view" ok:[NSStringFromClass([[(id)s->_host valueForKey:@"toolbarBackgroundView"] class]) isEqualToString:@"BKToggleProxy"] detail:nil];
    [s check:@"the start page is ours" ok:[s findSubview:@"BKStartPageView" in:[s->_host contentView]] != nil detail:nil];
    [s check:@"the stock toolbar is off screen" ok:[(UIView *)[s->_host valueForKey:@"toolbarContentView"] window] == nil detail:nil];
  });
  STEP(@"page", 0.6, {
    [s->_host setURL:@"https://example.com/docs/index.html"];
    [s->_host.backButton setEnabled:YES];
    [s checkLayout:@"page"];
    [s check:@"the start page is hidden on a real page" ok:((UIView *)[s findSubview:@"BKStartPageView" in:[s->_host contentView]]).hidden detail:nil];
  });
  STEP(@"loading", 1.2, { [s->_host setPageLoading:YES]; });
  STEP(@"omnibox", 0.9, {
    [s->_host setPageLoading:NO];
    [[BKChrome chromeForHost:s->_host] showOmnibox];
    [s check:@"the omnibox opens over the page" ok:[s findSubview:@"BKOmniboxView" in:s->_host.view] != nil detail:nil];
  });
  STEP(@"typing", 0.7, {
    UIView *box = [s findSubview:@"BKOmniboxView" in:s->_host.view];
    UITextField *field = [s findSubview:@"UITextField" in:box];
    field.text = @"git";
    [field sendActionsForControlEvents:UIControlEventEditingChanged];
  });
  STEP(@"page-again", 0.6, {
    [[BKChrome chromeForHost:s->_host] hideOmnibox];
  });
  STEP(@"keyboard", 0.6, {
    [s check:@"the omnibox is gone after Cancel" ok:[s findSubview:@"BKOmniboxView" in:s->_host.view] == nil detail:nil];
    ((void (*)(id, SEL, CGFloat))objc_msgSend)(s->_host, NSSelectorFromString(@"setKeyboardViewportInset:"), 250);
    [s->_host.view layoutIfNeeded];
    CGRect c = [s->_host contentView].frame;
    [s check:@"keyboard: the page ends at the keyboard" ok:[s near:CGRectGetMaxY(c) to:s->_host.view.bounds.size.height - 250] detail:NSStringFromCGRect(c)];
  });
  STEP(@"keyboard-off", 0.5, {
    ((void (*)(id, SEL, CGFloat))objc_msgSend)(s->_host, NSSelectorFromString(@"setKeyboardViewportInset:"), 0);
    [s checkLayout:@"keyboard gone"];
  });
  STEP(@"fullscreen", 0.7, {
    // the same sequence as ShellPlatformDelegate::ToggleFullscreenModeForTab (entering)
    UIViewController<HarnessHost> *h = s->_host;
    UIView *root = h.view, *content = [h contentView];
    [(UIView *)[(id)h valueForKey:@"toolbarBackgroundView"] setHidden:YES];
    [NSLayoutConstraint deactivateConstraints:[(id)h valueForKey:@"fullscreenConstraints"] ?: @[]];
    [NSLayoutConstraint deactivateConstraints:[(id)h valueForKey:@"topPosConstraints"]];
    [NSLayoutConstraint deactivateConstraints:[(id)h valueForKey:@"bottomPosConstraints"]];
    [NSLayoutConstraint deactivateConstraints:[(id)h valueForKey:@"contentHorizontalConstraints"]];
    NSArray *pins = @[ [content.leadingAnchor constraintEqualToAnchor:root.leadingAnchor], [content.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
                       [content.topAnchor constraintEqualToAnchor:root.topAnchor], [content.bottomAnchor constraintEqualToAnchor:root.bottomAnchor] ];
    [(id)h setValue:pins forKey:@"fullscreenConstraints"];
    [NSLayoutConstraint activateConstraints:pins];
    [root layoutIfNeeded];
    BKChrome *chrome = [BKChrome chromeForHost:h];
    [s check:@"fullscreen: all bars hidden" ok:chrome.topBar.hidden && chrome.bottomBar.hidden && chrome.progress.hidden detail:nil];
    [s check:@"fullscreen: the page fills the screen" ok:CGRectEqualToRect(content.frame, root.bounds) detail:NSStringFromCGRect(content.frame)];
  });
  STEP(@"fullscreen-off", 0.7, {
    // ... and leaving it
    UIViewController *h = s->_host;
    [(UIView *)[(id)h valueForKey:@"toolbarBackgroundView"] setHidden:NO];
    [NSLayoutConstraint deactivateConstraints:[(id)h valueForKey:@"fullscreenConstraints"] ?: @[]];
    [(id)h setValue:nil forKey:@"fullscreenConstraints"];
    [NSLayoutConstraint activateConstraints:[(id)h valueForKey:@"contentHorizontalConstraints"]];
    [(id)h applyToolbarPosition];
    [s checkLayout:@"after fullscreen"];
    BKChrome *chrome = [BKChrome chromeForHost:h];
    [s check:@"after fullscreen: bars are back (bottom bar hidden only in landscape)" ok:!chrome.topBar.hidden && (chrome.bottomBar.hidden == [s->_variant isEqualToString:@"landscape"]) detail:nil];
  });
  STEP(@"tabs", 1.3, {
    [s->_host showTabSwitcher];
    [s check:@"the tab switcher is ours" ok:[NSStringFromClass([[s topPresented] class]) isEqualToString:@"BKTabGridViewController"] detail:NSStringFromClass([[s topPresented] class])];
  });
  STEP(@"closed-tabs", 0.5, { [s->_host dismissViewControllerAnimated:NO completion:nil]; });
  STEP(@"menu", 1.3, {
    [s->_host showMainMenu];
    UIViewController *top = [s topPresented];
    [s check:@"the menu is a bottom sheet" ok:top.modalPresentationStyle == UIModalPresentationCustom && [top isKindOfClass:[UINavigationController class]] && ((UINavigationController *)top).navigationBarHidden detail:NSStringFromClass([top class])];
  });
  STEP(@"closed-menu", 0.5, {
    [s check:@"the menu is shown by a fresh navigation controller, not the stock popover one" ok:[s topPresented] != (UIViewController *)[(id)s->_host valueForKey:@"lastStockMenuNav"] detail:nil];
    [s->_host dismissViewControllerAnimated:NO completion:nil];
  });
  STEP(@"only-tab", 1.2, {
    [(id)s->_host setValue:@1 forKey:@"harnessTabCount"];
    [s->_host showTabSwitcher];
  });
  STEP(@"closed-only-tab", 1.6, {
    // tap the cross on the only card, like a finger would
    UIView *grid = [s topPresented].view;
    UIButton *cross = nil;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:grid];
    while (queue.count) {
      UIView *v = queue.firstObject;
      [queue removeObjectAtIndex:0];
      if ([v isKindOfClass:[UIButton class]] && [v.accessibilityLabel isEqualToString:BKL(@"Close Tab")]) {
        cross = (UIButton *)v;
        break;
      }
      [queue addObjectsFromArray:v.subviews];
    }
    [s check:@"the only tab has a close button" ok:cross != nil detail:nil];
    [cross sendActionsForControlEvents:UIControlEventTouchUpInside];
  });
  STEP(@"after-only-tab", 0.3, {
    NSArray<NSString *> *log = HarnessLog();
    NSUInteger openIndex = [log indexOfObject:@"openNewTab"], closeIndex = [log indexOfObject:@"closeCurrentTab"];
    [s check:@"closing the only tab opens a new one and then closes the old one" ok:openIndex != NSNotFound && closeIndex != NSNotFound && openIndex < closeIndex detail:[log componentsJoinedByString:@","]];
    [s check:@"the tab grid went away" ok:![NSStringFromClass([[s topPresented] class]) isEqualToString:@"BKTabGridViewController"] detail:nil];
    [(id)s->_host setValue:@0 forKey:@"harnessTabCount"];
  });
  STEP(@"list", 1.2, {
    Class listClass = NSClassFromString(@"BlinkListVC");
    id list = [[listClass alloc] init];
    [list setValue:@"Settings" forKey:@"title"];
    [list setValue:@NO forKey:@"dismissOnSelect"];
    [list setValue:[@[ @"Search Engine", @"Appearance", @"Toolbar Position", @"Languages", @"Ad & Tracker Blocking", @"Tor / Proxy", @"Clear Browsing Data", @"About" ] mutableCopy] forKey:@"titles"];
    [list setValue:[@[ @"Google", @"System", @"Top", @"English", @"On · 12 blocked", @"Off", @"", @"v0.3.1" ] mutableCopy] forKey:@"subtitles"];
    [list setValue:@[ @"magnifyingglass", @"circle.lefthalf.filled", @"rectangle.bottomthird.inset.filled", @"globe", @"checkmark.shield", @"lock.shield", @"trash", @"info.circle" ] forKey:@"imageNames"];
    [list setValue:[NSIndexSet indexSetWithIndex:1] forKey:@"checkedRows"];
    [s->_host presentList:list];
  });
  STEP(@"closed-list", 0.4, { [s->_host dismissViewControllerAnimated:NO completion:nil]; });
  STEP(@"start-again", 0.7, { [s->_host setURL:@"about:blank"]; });
#undef STEP
  [self runSteps:steps index:0];
}

- (void)runSteps:(NSArray<NSDictionary *> *)steps index:(NSUInteger)index {
  if (index >= steps.count) {
    [self finish];
    return;
  }
  NSDictionary *step = steps[index];
  void (^action)(void) = step[@"do"];
  @try {
    action();
  } @catch (NSException *exception) {
    NSLog(@"[Harness] step %@ threw %@ %@", step[@"name"], exception.name, exception.reason);
  }
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)([step[@"wait"] doubleValue] * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    NSString *name = step[@"name"];
    if (![name hasPrefix:@"closed-"]) {
      [self capture:name];
    }
    [self runSteps:steps index:index + 1];
  });
}

@end

int main(int argc, char *argv[]) {
  @autoreleasepool {
    return UIApplicationMain(argc, argv, nil, NSStringFromClass([HarnessApp class]));
  }
}
