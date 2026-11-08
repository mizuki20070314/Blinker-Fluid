// Simulator harness: runs the real hook installer against the stock replica, walks through the screens and saves a picture of
// each one (plus a contact sheet).  Variants (launch argument  -bk-variant <name>):
//   light | dark | bottom | private | ja | landscape
#import <UIKit/UIKit.h>
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

- (void)finish {
  [self writeContactSheet];
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
  STEP(@"start", 0.8, );
  STEP(@"page", 0.6, {
    [s->_host setURL:@"https://example.com/docs/index.html"];
    [s->_host.backButton setEnabled:YES];
  });
  STEP(@"loading", 1.2, { [s->_host setPageLoading:YES]; });
  STEP(@"omnibox", 0.9, {
    [s->_host setPageLoading:NO];
    [[BKChrome chromeForHost:s->_host] showOmnibox];
  });
  STEP(@"typing", 0.7, {
    UIView *box = [s findSubview:@"BKOmniboxView" in:s->_host.view];
    UITextField *field = [s findSubview:@"UITextField" in:box];
    field.text = @"git";
    [field sendActionsForControlEvents:UIControlEventEditingChanged];
  });
  STEP(@"page-again", 0.6, { [[BKChrome chromeForHost:s->_host] hideOmnibox]; });
  STEP(@"tabs", 1.3, { [s->_host showTabSwitcher]; });
  STEP(@"closed-tabs", 0.5, { [s->_host dismissViewControllerAnimated:NO completion:nil]; });
  STEP(@"menu", 1.3, { [s->_host showMainMenu]; });
  STEP(@"closed-menu", 0.5, { [s->_host dismissViewControllerAnimated:NO completion:nil]; });
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
