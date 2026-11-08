// SPDX-License-Identifier: GPL-3.0-or-later
#import "BKListStyle.h"
#import "BKCore.h"
#import "BKIcons.h"
#import "BKSheet.h"
#import "BKTheme.h"
#import <objc/message.h>
#import <objc/runtime.h>

static Class gListClass;

static UIColor *BKRGB(CGFloat r, CGFloat g, CGFloat b) {
  return [UIColor colorWithRed:r / 255.0 green:g / 255.0 blue:b / 255.0 alpha:1.0];
}

static UIColor *BKTileColorForIcon(BKIcon icon) {
  switch (icon) {
    case BKIconReload:
    case BKIconDownload:
    case BKIconShare:
    case BKIconPerson:
    case BKIconCompass:
    case BKIconInfo:
      return BKRGB(10, 132, 255);
    case BKIconPlus:
    case BKIconCheck:
    case BKIconLocation:
      return BKRGB(52, 199, 89);
    case BKIconTabs:
    case BKIconCode:
      return BKRGB(94, 92, 230);
    case BKIconHouse:
    case BKIconBookmark:
    case BKIconBolt:
      return BKRGB(255, 149, 0);
    case BKIconPrivate:
    case BKIconShield:
      return BKRGB(130, 62, 190);
    case BKIconTrash:
    case BKIconExit:
      return BKRGB(255, 69, 58);
    case BKIconGlobe:
    case BKIconCamera:
    case BKIconMic:
      return BKRGB(48, 176, 199);
    default:
      return BKRGB(142, 142, 147);
  }
}

// ------------------------------------------------------------------------------------------------- quick actions

@interface BKMenuHeader : UIView
- (instancetype)initWithList:(UIViewController *)list;
@end

@implementation BKMenuHeader {
  __weak UIViewController *_list;
  UIView *_grabber;
  NSArray<UIControl *> *_buttons;
  NSArray<NSNumber *> *_rows;
}

- (instancetype)initWithList:(UIViewController *)list {
  if ((self = [super initWithFrame:CGRectMake(0, 0, 320, 132)])) {
    _list = list;
    self.backgroundColor = UIColor.clearColor;
    _grabber = [[UIView alloc] init];
    _grabber.layer.cornerRadius = 2;
    [self addSubview:_grabber];
    NSArray<NSString *> *titles = [list valueForKey:@"titles"];
    // Rows of the stock menu (see showMainMenu): 2 = New Tab, 6 = Bookmarks, 7 = Downloads, 11 = Share Link.
    NSArray<NSDictionary *> *spec = @[
      @{@"row" : @2, @"icon" : @(BKIconPlus)},
      @{@"row" : @6, @"icon" : @(BKIconBookmark)},
      @{@"row" : @7, @"icon" : @(BKIconDownload)},
      @{@"row" : @11, @"icon" : @(BKIconShare)},
    ];
    NSMutableArray *buttons = [NSMutableArray array];
    NSMutableArray *rows = [NSMutableArray array];
    for (NSDictionary *item in spec) {
      NSInteger row = [item[@"row"] integerValue];
      if (row >= (NSInteger)titles.count) {
        continue;
      }
      UIControl *button = [[UIControl alloc] init];
      button.tag = row;
      UIView *tile = [[UIView alloc] init];
      tile.tag = 1;
      tile.userInteractionEnabled = NO;
      tile.layer.cornerRadius = 16;
      [button addSubview:tile];
      UIImageView *glyph = [[UIImageView alloc] initWithImage:[BKIcons image:(BKIcon)[item[@"icon"] integerValue] size:26]];
      glyph.tag = 2;
      glyph.contentMode = UIViewContentModeCenter;
      glyph.userInteractionEnabled = NO;
      [button addSubview:glyph];
      UILabel *caption = [[UILabel alloc] init];
      caption.tag = 3;
      caption.text = titles[row];
      caption.textAlignment = NSTextAlignmentCenter;
      caption.font = [BKTheme font:11 weight:UIFontWeightMedium];
      caption.lineBreakMode = NSLineBreakByTruncatingTail;
      caption.userInteractionEnabled = NO;
      [button addSubview:caption];
      [button addTarget:self action:@selector(tapped:) forControlEvents:UIControlEventTouchUpInside];
      [self addSubview:button];
      [buttons addObject:button];
      [rows addObject:@(row)];
    }
    _buttons = buttons;
    _rows = rows;
    [self applyTheme];
  }
  return self;
}

- (void)applyTheme {
  _grabber.backgroundColor = [BKTheme tertiaryText];
  for (UIControl *button in _buttons) {
    [button viewWithTag:1].backgroundColor = [BKTheme cellBackground];
    [button viewWithTag:2].tintColor = [BKTheme accent];
    ((UILabel *)[button viewWithTag:3]).textColor = [BKTheme secondaryText];
  }
}

- (void)tapped:(UIControl *)button {
  [[[UISelectionFeedbackGenerator alloc] init] selectionChanged];
  UIViewController *list = _list;
  void (^onSelect)(NSInteger) = [list valueForKey:@"onSelect"];
  if (onSelect) {
    onSelect(button.tag);
  }
}

- (void)layoutSubviews {
  [super layoutSubviews];
  const CGFloat width = self.bounds.size.width;
  _grabber.frame = CGRectMake((width - 36) / 2, 8, 36, 4);
  const NSUInteger count = _buttons.count;
  if (!count) {
    return;
  }
  const CGFloat side = 16, gap = 10;
  const CGFloat cell = (width - 2 * side - gap * (count - 1)) / count;
  for (NSUInteger i = 0; i < count; i++) {
    UIControl *button = _buttons[i];
    button.frame = CGRectMake(side + i * (cell + gap), 22, cell, 92);
    CGRect tile = CGRectMake(0, 0, cell, 62);
    [button viewWithTag:1].frame = tile;
    [button viewWithTag:2].frame = tile;
    [button viewWithTag:3].frame = CGRectMake(0, 68, cell, 16);
  }
}

@end

// ------------------------------------------------------------------------------------------------ list hooks

static void (*orig_listViewDidLoad)(id, SEL);
static void (*orig_listApplyNav)(id, SEL);
static UITableViewCell *(*orig_listCell)(id, SEL, UITableView *, NSIndexPath *);

static void hook_listApplyNav(id self, SEL _cmd) {
  UINavigationBar *bar = [[(UIViewController *)self navigationController] navigationBar];
  if (bar) {
    [BKListStyle styleNavigationBar:bar];
  } else if (orig_listApplyNav) {
    orig_listApplyNav(self, _cmd);
  }
}

static void hook_listViewDidLoad(id self, SEL _cmd) {
  orig_listViewDidLoad(self, _cmd);
  @try {
    UITableViewController *list = self;
    list.tableView.backgroundColor = [BKTheme groupedBackground];
    list.tableView.separatorColor = [BKTheme separator];
    list.tableView.separatorInset = UIEdgeInsetsMake(0, 58, 0, 0);
    list.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 12)];
    if ([BKListStyle isMainMenuList:list]) {
      BKMenuHeader *header = [[BKMenuHeader alloc] initWithList:list];
      header.frame = CGRectMake(0, 0, list.tableView.bounds.size.width, 132);
      list.tableView.tableHeaderView = header;
      list.tableView.separatorInset = UIEdgeInsetsMake(0, 58, 0, 0);
    }
  } @catch (NSException *exception) {
    BKLog(@"list viewDidLoad restyle failed: %@", exception);
  }
}

static UITableViewCell *hook_listCell(id self, SEL _cmd, UITableView *table, NSIndexPath *path) {
  UITableViewCell *cell = orig_listCell(self, _cmd, table, path);
  @try {
    NSInteger row = ((NSInteger (*)(id, SEL, NSIndexPath *))objc_msgSend)(self, NSSelectorFromString(@"globalRowForIndexPath:"), path);
    cell.backgroundColor = [BKTheme cellBackground];
    UIView *selected = [[UIView alloc] init];
    selected.backgroundColor = [BKTheme cellSelected];
    cell.selectedBackgroundView = selected;
    cell.tintColor = [BKTheme accent];
    cell.textLabel.font = [BKTheme font:16 weight:UIFontWeightRegular];
    cell.detailTextLabel.font = [BKTheme font:12 weight:UIFontWeightRegular];
    cell.detailTextLabel.textColor = [BKTheme secondaryText];

    NSArray *titleColors = [self valueForKey:@"titleColors"];
    UIColor *explicit = (row < (NSInteger)titleColors.count && [titleColors[row] isKindOfClass:[UIColor class]]) ? titleColors[row] : nil;
    cell.textLabel.textColor = explicit ?: [BKTheme primaryText];

    NSArray *rowImages = [self valueForKey:@"rowImages"];
    NSArray<NSString *> *imageNames = [self valueForKey:@"imageNames"];
    BOOL hasRowImage = row < (NSInteger)rowImages.count && [rowImages[row] isKindOfClass:[UIImage class]];
    if (hasRowImage) {
      // avatars come pre-rounded from the stock code
    } else if (row < (NSInteger)imageNames.count && [imageNames[row] isKindOfClass:[NSString class]]) {
      BOOL found = NO;
      BKIcon icon = [BKIcons iconForSymbolName:imageNames[row] found:&found];
      cell.imageView.image = found ? [BKIcons tileWithIcon:icon size:30 color:BKTileColorForIcon(icon)] : nil;
      cell.imageView.contentMode = UIViewContentModeCenter;
    }
    if ([self valueForKey:@"badgedRows"] && cell.accessoryView) {
      cell.accessoryView.backgroundColor = [BKTheme destructive];
    }
  } @catch (NSException *exception) {
    BKLog(@"list cell restyle failed: %@", exception);
  }
  return cell;
}

// Added to BlinkListVC (the stock class does not implement it) so section titles match the theme.
static void hook_listWillDisplayHeader(id self, SEL _cmd, UITableView *table, UIView *view, NSInteger section) {
  if ([view isKindOfClass:[UITableViewHeaderFooterView class]]) {
    UITableViewHeaderFooterView *header = (UITableViewHeaderFooterView *)view;
    header.textLabel.textColor = [BKTheme secondaryText];
    header.textLabel.font = [BKTheme font:12 weight:UIFontWeightSemibold];
    header.contentView.backgroundColor = [BKTheme groupedBackground];
    header.backgroundView.backgroundColor = [BKTheme groupedBackground];
  }
}

static void (*orig_editorViewDidLoad)(id, SEL);
static void hook_editorViewDidLoad(id self, SEL _cmd) {
  orig_editorViewDidLoad(self, _cmd);
  @try {
    UIViewController *editor = self;
    editor.view.backgroundColor = [BKTheme groupedBackground];
    for (NSString *key in @[ @"nameField", @"urlField" ]) {
      UITextField *field = [editor valueForKey:key];
      if ([field isKindOfClass:[UITextField class]]) {
        field.textColor = [BKTheme primaryText];
        field.backgroundColor = [BKTheme cellBackground];
        field.layer.borderColor = [BKTheme separator].CGColor;
        field.keyboardAppearance = [BKTheme isDark] ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
      }
    }
  } @catch (NSException *exception) {
    BKLog(@"editor restyle failed: %@", exception);
  }
}

static void (*orig_stylableWillAppear)(id, SEL, BOOL);
static void hook_stylableWillAppear(id self, SEL _cmd, BOOL animated) {
  orig_stylableWillAppear(self, _cmd, animated);
  UINavigationBar *bar = [[(UIViewController *)self navigationController] navigationBar];
  if (bar) {
    [BKListStyle styleNavigationBar:bar];
  }
}

@implementation BKListStyle

+ (void)styleNavigationBar:(UINavigationBar *)bar {
  UIColor *background = [BKTheme chromeBackground];
  UIColor *text = [BKTheme primaryText];
  bar.tintColor = [BKTheme accent];
  bar.barStyle = [BKTheme isDark] ? UIBarStyleBlack : UIBarStyleDefault;
  NSDictionary *titleAttributes = @{NSForegroundColorAttributeName : text, NSFontAttributeName : [BKTheme font:17 weight:UIFontWeightSemibold]};
  if (@available(iOS 13.0, *)) {
    UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
    [appearance configureWithOpaqueBackground];
    appearance.backgroundColor = background;
    appearance.titleTextAttributes = titleAttributes;
    appearance.shadowColor = [BKTheme separator];
    bar.standardAppearance = appearance;
    bar.scrollEdgeAppearance = appearance;
    bar.compactAppearance = appearance;
  } else {
    bar.translucent = NO;
    bar.barTintColor = background;
    bar.titleTextAttributes = titleAttributes;
  }
}

+ (BOOL)isMainMenuList:(UIViewController *)vc {
  if (!gListClass || ![vc isKindOfClass:gListClass]) {
    return NO;
  }
  @try {
    BOOL compact = [[vc valueForKey:@"compactRows"] boolValue];
    NSArray *starts = [vc valueForKey:@"sectionStarts"];
    NSArray *titles = [vc valueForKey:@"titles"];
    return compact && starts.count == 4 && titles.count == 14;
  } @catch (NSException *exception) {
    return NO;
  }
}

+ (void)prepareMenuNavigation:(UINavigationController *)nav {
  // The stock showMainMenu paints the table dark grey and pads it for the popover arrow after the list has loaded.
  UIViewController *root = nav.viewControllers.firstObject;
  if ([root isKindOfClass:[UITableViewController class]]) {
    UITableView *table = ((UITableViewController *)root).tableView;
    table.backgroundColor = [BKTheme groupedBackground];
    table.contentInset = UIEdgeInsetsZero;
    table.tableFooterView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 1, 12)];
    UIView *header = table.tableHeaderView;
    if ([header isKindOfClass:[BKMenuHeader class]]) {
      [(BKMenuHeader *)header applyTheme];
    }
  }
  nav.navigationBarHidden = YES;
  CGFloat screen = UIScreen.mainScreen.bounds.size.height;
  nav.preferredContentSize = CGSizeMake(0, floor(MIN(screen * 0.76, 640)));
  [BKSheetTransition applyToController:nav];
  nav.view.backgroundColor = [BKTheme groupedBackground];
}

+ (void)installHooks {
  gListClass = objc_getClass("BlinkListVC");
  if (gListClass) {
    BKHookInstance(gListClass, @selector(viewDidLoad), "v@:", (IMP)hook_listViewDidLoad, (IMP *)&orig_listViewDidLoad);
    BKHookInstance(gListClass, NSSelectorFromString(@"applyNavigationBarAppearance"), "v@:", (IMP)hook_listApplyNav, (IMP *)&orig_listApplyNav);
    BKHookInstance(gListClass, @selector(tableView:cellForRowAtIndexPath:), "@@:@@", (IMP)hook_listCell, (IMP *)&orig_listCell);
    // not implemented by the stock class: add (class_addMethod through BKHookInstance is not possible without an existing method)
    class_addMethod(gListClass, @selector(tableView:willDisplayHeaderView:forSection:), (IMP)hook_listWillDisplayHeader, "v@:@@q");
  }
  Class editor = objc_getClass("BlinkBookmarkEditorVC");
  if (editor) {
    BKHookInstance(editor, @selector(viewDidLoad), "v@:", (IMP)hook_editorViewDidLoad, (IMP *)&orig_editorViewDidLoad);
  }
  // The find bar and the bookmark editor leave the navigation bar at its default look.
  static IMP sharedOriginal;
  for (NSString *name in @[ @"BlinkFindInPageController", @"BlinkBookmarkEditorVC" ]) {
    Class cls = objc_getClass(name.UTF8String);
    if (cls) {
      IMP original = NULL;
      if (BKHookInstance(cls, @selector(viewWillAppear:), "v@:B", (IMP)hook_stylableWillAppear, &original)) {
        if (!orig_stylableWillAppear) {
          orig_stylableWillAppear = (void (*)(id, SEL, BOOL))original;  // both fall back to UIViewController's implementation
        }
      }
    }
  }
  (void)sharedOriginal;
}

@end
