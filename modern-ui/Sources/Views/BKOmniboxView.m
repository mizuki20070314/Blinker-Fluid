// SPDX-License-Identifier: GPL-3.0-or-later
#import "BKOmniboxView.h"
#import "BKCore.h"
#import "BKIcons.h"
#import "BKSettings.h"
#import "BKTheme.h"

typedef NS_ENUM(NSInteger, BKSuggestionKind) {
  BKSuggestionPaste,
  BKSuggestionGo,
  BKSuggestionSearch,
  BKSuggestionBookmark,
  BKSuggestionHistory,
  BKSuggestionRemote,
};

@interface BKSuggestion : NSObject
@property(nonatomic) BKSuggestionKind kind;
@property(nonatomic, copy) NSString *title;
@property(nonatomic, copy, nullable) NSString *subtitle;
@property(nonatomic, copy, nullable) NSString *input;   // what -openUserInput: receives (nil for paste: read on tap)
@end
@implementation BKSuggestion
@end

@interface BKSuggestionCell : UITableViewCell
@property(nonatomic, strong) UIImageView *glyph;
@property(nonatomic, strong) UILabel *primary;
@property(nonatomic, strong) UILabel *secondary;
@property(nonatomic, strong) UIButton *fill;       // "put this text into the field"
@end

@implementation BKSuggestionCell

- (instancetype)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
  if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier])) {
    self.backgroundColor = UIColor.clearColor;
    self.selectionStyle = UITableViewCellSelectionStyleNone;
    _glyph = [[UIImageView alloc] init];
    _glyph.contentMode = UIViewContentModeCenter;
    _glyph.layer.cornerRadius = 8;
    [self.contentView addSubview:_glyph];
    _primary = [[UILabel alloc] init];
    _primary.font = [BKTheme font:16 weight:UIFontWeightRegular];
    [self.contentView addSubview:_primary];
    _secondary = [[UILabel alloc] init];
    _secondary.font = [BKTheme font:13 weight:UIFontWeightRegular];
    [self.contentView addSubview:_secondary];
    _fill = [UIButton buttonWithType:UIButtonTypeCustom];
    [_fill setImage:[BKIcons image:BKIconArrowUpRight size:18] forState:UIControlStateNormal];
    [self.contentView addSubview:_fill];
  }
  return self;
}

- (void)setHighlighted:(BOOL)highlighted animated:(BOOL)animated {
  [super setHighlighted:highlighted animated:animated];
  self.contentView.backgroundColor = highlighted ? [BKTheme cellSelected] : UIColor.clearColor;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  const CGFloat width = self.contentView.bounds.size.width;
  const CGFloat height = self.contentView.bounds.size.height;
  _glyph.frame = CGRectMake(14, (height - 32) / 2, 32, 32);
  const CGFloat fillWidth = _fill.hidden ? 0 : 44;
  const CGFloat textX = 58;
  const CGFloat textWidth = width - textX - fillWidth - 8;
  if (_secondary.text.length) {
    _primary.frame = CGRectMake(textX, 8, textWidth, 22);
    _secondary.frame = CGRectMake(textX, 30, textWidth, 18);
  } else {
    _primary.frame = CGRectMake(textX, (height - 22) / 2, textWidth, 22);
    _secondary.frame = CGRectZero;
  }
  _fill.frame = CGRectMake(width - fillWidth, 0, fillWidth, height);
}

@end

// ------------------------------------------------------------------------------------------------------- the view

@interface BKOmniboxView () <UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate>
@end

@implementation BKOmniboxView {
  UIView *_header;
  UIView *_fieldBox;
  UIImageView *_fieldIcon;
  UITextField *_field;
  UIButton *_cancel;
  UIView *_headerHairline;
  UITableView *_table;
  NSArray<BKSuggestion *> *_rows;
  NSArray<BKSuggestion *> *_remote;
  NSURLSessionDataTask *_task;
  int64_t _generation;
  CGFloat _keyboardHeight;
  BOOL _fromStartPage;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _rows = @[];
    _remote = @[];

    _header = [[UIView alloc] init];
    [self addSubview:_header];
    _headerHairline = [[UIView alloc] init];
    [_header addSubview:_headerHairline];

    _fieldBox = [[UIView alloc] init];
    [_header addSubview:_fieldBox];
    _fieldIcon = [[UIImageView alloc] initWithImage:[BKIcons image:BKIconSearch size:16]];
    _fieldIcon.contentMode = UIViewContentModeCenter;
    [_fieldBox addSubview:_fieldIcon];

    _field = [[UITextField alloc] init];
    _field.delegate = self;
    _field.placeholder = BKL(@"Search or enter address");
    _field.font = [BKTheme font:16 weight:UIFontWeightRegular];
    _field.returnKeyType = UIReturnKeyGo;
    _field.keyboardType = UIKeyboardTypeWebSearch;
    _field.autocapitalizationType = UITextAutocapitalizationTypeNone;
    _field.autocorrectionType = UITextAutocorrectionTypeNo;
    _field.spellCheckingType = UITextSpellCheckingTypeNo;
    _field.clearButtonMode = UITextFieldViewModeWhileEditing;
    _field.enablesReturnKeyAutomatically = YES;
    [_field addTarget:self action:@selector(textChanged) forControlEvents:UIControlEventEditingChanged];
    [_fieldBox addSubview:_field];
    UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(fieldHeld:)];
    [_fieldBox addGestureRecognizer:hold];

    _cancel = [UIButton buttonWithType:UIButtonTypeCustom];
    [_cancel setTitle:BKL(@"Cancel") forState:UIControlStateNormal];
    _cancel.titleLabel.font = [BKTheme font:16 weight:UIFontWeightRegular];
    [_cancel addTarget:self action:@selector(cancelTapped) forControlEvents:UIControlEventTouchUpInside];
    [_header addSubview:_cancel];

    _table = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    _table.dataSource = self;
    _table.delegate = self;
    _table.rowHeight = 56;
    _table.tableFooterView = [[UIView alloc] init];
    _table.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    _table.separatorInset = UIEdgeInsetsMake(0, 58, 0, 0);
    _table.backgroundColor = UIColor.clearColor;
    _table.alwaysBounceVertical = YES;
    [self insertSubview:_table belowSubview:_header];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardChanged:) name:UIKeyboardWillChangeFrameNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:BKThemeDidChangeNotification object:nil];
    [self applyTheme];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
  [_task cancel];
}

- (BOOL)fromStartPage {
  return _fromStartPage;
}

- (void)applyTheme {
  self.backgroundColor = [BKTheme pageBackground];
  _header.backgroundColor = [BKTheme chromeBackground];
  _headerHairline.backgroundColor = [BKTheme separator];
  _fieldBox.backgroundColor = [BKTheme pillBackground];
  _fieldIcon.tintColor = [BKTheme secondaryText];
  _field.textColor = [BKTheme primaryText];
  _field.tintColor = [BKTheme accent];
  _field.keyboardAppearance = [BKTheme isDark] ? UIKeyboardAppearanceDark : UIKeyboardAppearanceLight;
  [_cancel setTitleColor:[BKTheme accent] forState:UIControlStateNormal];
  _table.separatorColor = [BKTheme separator];
  [_table reloadData];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  const UIEdgeInsets safe = self.safeAreaInsets;
  const CGFloat width = self.bounds.size.width;
  const CGFloat rowHeight = (self.bounds.size.width > self.bounds.size.height) ? 48 : 56;
  const CGFloat headerHeight = safe.top + rowHeight;
  _header.frame = CGRectMake(0, 0, width, headerHeight);
  _headerHairline.frame = CGRectMake(0, headerHeight - 0.5, width, 0.5);
  CGSize cancelSize = [_cancel sizeThatFits:CGSizeMake(200, 40)];
  const CGFloat cancelWidth = cancelSize.width + 12;
  const CGFloat left = MAX(12, safe.left + 8);
  const CGFloat right = MAX(8, safe.right + 4);
  _cancel.frame = CGRectMake(width - right - cancelWidth, safe.top, cancelWidth, rowHeight);
  _fieldBox.frame = CGRectMake(left, safe.top + (rowHeight - 40) / 2, CGRectGetMinX(_cancel.frame) - left - 4, 40);
  _fieldBox.layer.cornerRadius = 20;
  _fieldIcon.frame = CGRectMake(8, 0, 28, 40);
  _field.frame = CGRectMake(38, 0, _fieldBox.bounds.size.width - 38 - 6, 40);
  const CGFloat bottomInset = MAX(_keyboardHeight, safe.bottom);
  _table.frame = CGRectMake(0, headerHeight, width, MAX(self.bounds.size.height - headerHeight - bottomInset, 0));
}

// -------------------------------------------------------------------------------------------------------------- flow

- (void)beginWithText:(NSString *)text fromStartPage:(BOOL)fromStartPage {
  _fromStartPage = fromStartPage;
  _field.text = text ?: @"";
  self.alpha = 0;
  [self layoutIfNeeded];
  [self rebuildRows];
  [UIView animateWithDuration:0.18 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{ self.alpha = 1; } completion:nil];
  [_field becomeFirstResponder];
  dispatch_async(dispatch_get_main_queue(), ^{
    [self->_field selectAll:nil];
  });
}

- (void)endEditing {
  [_task cancel];
  [_field resignFirstResponder];
}

- (void)cancelTapped {
  [self endEditing];
  if (self.onCancel) {
    self.onCancel();
  }
}

- (void)fieldHeld:(UILongPressGestureRecognizer *)gesture {
  if (gesture.state == UIGestureRecognizerStateBegan && self.onLongPressField) {
    self.onLongPressField();
  }
}

- (void)submit:(NSString *)input {
  NSString *trimmed = [input stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  if (!trimmed.length) {
    return;
  }
  [self endEditing];
  if (self.onSubmit) {
    self.onSubmit(trimmed);
  }
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
  [self submit:textField.text ?: @""];
  return NO;
}

- (void)keyboardChanged:(NSNotification *)note {
  if (!self.window) {
    return;
  }
  CGRect end = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
  CGRect local = [self convertRect:[self.window convertRect:end fromWindow:nil] fromView:self.window];
  _keyboardHeight = MAX(0, CGRectGetMaxY(self.bounds) - CGRectGetMinY(local));
  NSTimeInterval duration = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
  [UIView animateWithDuration:duration animations:^{ [self layoutIfNeeded]; }];
}

// ------------------------------------------------------------------------------------------------------- suggestions

static BOOL BKLooksLikeAddress(NSString *text) {
  if ([text containsString:@" "]) {
    return NO;
  }
  if ([text containsString:@"://"]) {
    return YES;
  }
  return [text containsString:@"."] || [text hasPrefix:@"localhost"];
}

static NSString *BKReadable(NSString *url) {
  NSString *value = url;
  for (NSString *prefix in @[ @"https://", @"http://" ]) {
    if ([value hasPrefix:prefix]) {
      value = [value substringFromIndex:prefix.length];
      break;
    }
  }
  if ([value hasPrefix:@"www."]) {
    value = [value substringFromIndex:4];
  }
  if ([value hasSuffix:@"/"]) {
    value = [value substringToIndex:value.length - 1];
  }
  return value;
}

- (void)textChanged {
  [self rebuildRows];
  NSString *term = [_field.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  [_task cancel];
  _task = nil;
  _remote = @[];
  if (!_fromStartPage || term.length < 2 || BKLooksLikeAddress(term)) {
    return;
  }
  NSURL *url = [BKSettings suggestionURLForTerm:term];
  if (!url) {
    return;
  }
  const int64_t generation = ++_generation;
  __weak BKOmniboxView *weakSelf = self;
  _task = [[NSURLSession sharedSession] dataTaskWithURL:url
                                      completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                                        if (error || !data) {
                                          return;
                                        }
                                        id parsed = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                                        if (![parsed isKindOfClass:[NSArray class]] || [parsed count] < 2 || ![parsed[1] isKindOfClass:[NSArray class]]) {
                                          return;
                                        }
                                        NSMutableArray<BKSuggestion *> *items = [NSMutableArray array];
                                        for (id entry in parsed[1]) {
                                          if ([entry isKindOfClass:[NSString class]] && items.count < 5) {
                                            BKSuggestion *s = [[BKSuggestion alloc] init];
                                            s.kind = BKSuggestionRemote;
                                            s.title = entry;
                                            s.input = entry;
                                            [items addObject:s];
                                          }
                                        }
                                        dispatch_async(dispatch_get_main_queue(), ^{
                                          BKOmniboxView *strong = weakSelf;
                                          if (!strong || generation != strong->_generation) {
                                            return;
                                          }
                                          strong->_remote = items;
                                          [strong rebuildRows];
                                        });
                                      }];
  [_task resume];
}

- (void)rebuildRows {
  NSString *term = [_field.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
  NSMutableArray<BKSuggestion *> *rows = [NSMutableArray array];
  NSMutableSet<NSString *> *seen = [NSMutableSet set];

  if (term.length == 0) {
    UIPasteboard *board = [UIPasteboard generalPasteboard];
    if (board.hasStrings || board.hasURLs) {
      BKSuggestion *paste = [[BKSuggestion alloc] init];
      paste.kind = BKSuggestionPaste;
      paste.title = BKL(@"Paste and Go");
      [rows addObject:paste];
    }
    NSInteger shownHistory = 0;
    for (NSString *url in [BKSettings historyURLs]) {
      NSString *readable = BKReadable(url);
      if ([seen containsObject:readable]) {
        continue;
      }
      [seen addObject:readable];
      BKSuggestion *s = [[BKSuggestion alloc] init];
      s.kind = BKSuggestionHistory;
      NSURL *parsed = [NSURL URLWithString:url];
      s.title = parsed.host.length ? (([parsed.host hasPrefix:@"www."]) ? [parsed.host substringFromIndex:4] : parsed.host) : readable;
      s.subtitle = readable;
      s.input = url;
      [rows addObject:s];
      if (++shownHistory >= 8) {
        break;
      }
    }
  } else {
    BKSuggestion *first = [[BKSuggestion alloc] init];
    if (BKLooksLikeAddress(term)) {
      first.kind = BKSuggestionGo;
      first.title = [NSString stringWithFormat:BKL(@"Go to %@"), term];
    } else {
      first.kind = BKSuggestionSearch;
      first.title = [NSString stringWithFormat:BKL(@"Search for \"%@\""), term];
      first.subtitle = [BKSettings searchEngineName];
    }
    first.input = term;
    [rows addObject:first];

    NSString *needle = term.lowercaseString;
    NSInteger bookmarkCount = 0;
    for (NSDictionary *bookmark in [BKSettings flatBookmarks]) {
      NSString *title = bookmark[@"title"], *url = bookmark[@"url"];
      if ([title.lowercaseString containsString:needle] || [url.lowercaseString containsString:needle]) {
        NSString *readable = BKReadable(url);
        if ([seen containsObject:readable]) {
          continue;
        }
        [seen addObject:readable];
        BKSuggestion *s = [[BKSuggestion alloc] init];
        s.kind = BKSuggestionBookmark;
        s.title = title.length ? title : readable;
        s.subtitle = readable;
        s.input = url;
        [rows addObject:s];
        if (++bookmarkCount >= 3) {
          break;
        }
      }
    }
    NSInteger historyCount = 0;
    for (NSString *url in [BKSettings historyURLs]) {
      if (![url.lowercaseString containsString:needle]) {
        continue;
      }
      NSString *readable = BKReadable(url);
      if ([seen containsObject:readable]) {
        continue;
      }
      [seen addObject:readable];
      BKSuggestion *s = [[BKSuggestion alloc] init];
      s.kind = BKSuggestionHistory;
      s.title = readable;
      s.input = url;
      [rows addObject:s];
      if (++historyCount >= 4) {
        break;
      }
    }
    for (BKSuggestion *remote in _remote) {
      if (![seen containsObject:remote.title]) {
        [seen addObject:remote.title];
        [rows addObject:remote];
      }
    }
  }
  _rows = rows;
  [_table reloadData];
}

// ---------------------------------------------------------------------------------------------------------- table

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
  return _rows.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
  BKSuggestionCell *cell = [tableView dequeueReusableCellWithIdentifier:@"s"];
  if (!cell) {
    cell = [[BKSuggestionCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"s"];
  }
  BKSuggestion *s = _rows[indexPath.row];
  BKIcon icon = BKIconSearch;
  UIColor *tile = [BKTheme pillBackground];
  UIColor *tint = [BKTheme secondaryText];
  switch (s.kind) {
    case BKSuggestionPaste: icon = BKIconPaste; tint = [BKTheme accent]; break;
    case BKSuggestionGo: icon = BKIconGlobe; tint = [BKTheme accent]; break;
    case BKSuggestionSearch: icon = BKIconSearch; tint = [BKTheme accent]; break;
    case BKSuggestionBookmark: icon = BKIconBookmark; break;
    case BKSuggestionHistory: icon = BKIconClock; break;
    case BKSuggestionRemote: icon = BKIconSearch; break;
  }
  cell.glyph.image = [BKIcons image:icon size:17];
  cell.glyph.tintColor = tint;
  cell.glyph.backgroundColor = tile;
  cell.primary.text = s.title;
  cell.primary.textColor = [BKTheme primaryText];
  cell.secondary.text = s.subtitle;
  cell.secondary.textColor = [BKTheme secondaryText];
  cell.fill.hidden = !(s.kind == BKSuggestionRemote || s.kind == BKSuggestionHistory || s.kind == BKSuggestionBookmark);
  cell.fill.tintColor = [BKTheme tertiaryText];
  [cell.fill removeTarget:nil action:NULL forControlEvents:UIControlEventAllEvents];
  cell.fill.tag = indexPath.row;
  [cell.fill addTarget:self action:@selector(fillTapped:) forControlEvents:UIControlEventTouchUpInside];
  [cell setNeedsLayout];
  return cell;
}

- (void)fillTapped:(UIButton *)button {
  if (button.tag < 0 || button.tag >= (NSInteger)_rows.count) {
    return;
  }
  BKSuggestion *s = _rows[button.tag];
  _field.text = s.input ?: s.title;
  [self textChanged];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
  [tableView deselectRowAtIndexPath:indexPath animated:NO];
  BKSuggestion *s = _rows[indexPath.row];
  if (s.kind == BKSuggestionPaste) {
    NSString *text = [UIPasteboard generalPasteboard].string;
    if (!text.length) {
      text = [UIPasteboard generalPasteboard].URL.absoluteString;
    }
    if (text.length) {
      [self submit:text];
    }
    return;
  }
  [self submit:s.input ?: s.title];
}

@end
