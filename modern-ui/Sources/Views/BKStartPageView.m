// SPDX-License-Identifier: GPL-3.0-or-later
#import "BKStartPageView.h"
#import "BKCore.h"
#import "BKFavicon.h"
#import "BKIcons.h"
#import "BKSettings.h"
#import "BKTheme.h"

// ------------------------------------------------------------------------------------------------------------ tile

@interface BKTile : UIControl
@property(nonatomic, copy) NSString *url;
@property(nonatomic, copy) NSString *caption;
- (instancetype)initWithTitle:(NSString *)title url:(NSString *)url;
- (void)setIconImage:(nullable UIImage *)image;
- (void)applyTheme;
@end

@implementation BKTile {
  UIView *_plate;
  UIImageView *_icon;
  UILabel *_monogram;
  UILabel *_label;
  BOOL _hasImage;
}

- (instancetype)initWithTitle:(NSString *)title url:(NSString *)url {
  if ((self = [super initWithFrame:CGRectZero])) {
    _url = [url copy];
    _caption = [title copy];
    _plate = [[UIView alloc] init];
    _plate.userInteractionEnabled = NO;
    _plate.layer.cornerRadius = 16;
    _plate.layer.borderWidth = 0.5;
    [self addSubview:_plate];
    _icon = [[UIImageView alloc] init];
    _icon.contentMode = UIViewContentModeScaleAspectFit;
    _icon.layer.cornerRadius = 11;
    _icon.clipsToBounds = YES;
    [_plate addSubview:_icon];
    _monogram = [[UILabel alloc] init];
    _monogram.textAlignment = NSTextAlignmentCenter;
    _monogram.font = [BKTheme font:26 weight:UIFontWeightSemibold];
    NSString *seed = [NSURL URLWithString:url].host ?: title;
    NSString *letter = title.length ? [[title substringToIndex:1] uppercaseString] : @"•";
    _monogram.text = letter;
    _monogram.textColor = UIColor.whiteColor;
    _monogram.backgroundColor = [BKTheme colorForText:seed ?: letter];
    _monogram.layer.cornerRadius = 16;
    _monogram.clipsToBounds = YES;
    [_plate addSubview:_monogram];
    _label = [[UILabel alloc] init];
    _label.text = title;
    _label.textAlignment = NSTextAlignmentCenter;
    _label.font = [BKTheme font:12 weight:UIFontWeightRegular];
    _label.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:_label];
    self.accessibilityLabel = title;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self applyTheme];
  }
  return self;
}

- (void)setIconImage:(UIImage *)image {
  _hasImage = image != nil;
  _icon.image = image;
  _icon.hidden = !_hasImage;
  _monogram.hidden = _hasImage;
  [self applyTheme];
}

- (void)applyTheme {
  _plate.backgroundColor = _hasImage ? [BKTheme tileBackground] : [UIColor clearColor];
  _plate.layer.borderColor = (_hasImage ? [BKTheme separator] : UIColor.clearColor).CGColor;
  _label.textColor = [BKTheme primaryText];
}

- (void)setHighlighted:(BOOL)highlighted {
  [super setHighlighted:highlighted];
  self.alpha = highlighted ? 0.55 : 1.0;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  const CGFloat side = MIN(self.bounds.size.width - 8, 62);
  _plate.frame = CGRectMake((self.bounds.size.width - side) / 2, 0, side, side);
  _icon.frame = CGRectInset(_plate.bounds, 10, 10);
  _monogram.frame = _plate.bounds;
  _label.frame = CGRectMake(0, side + 6, self.bounds.size.width, 16);
}

@end

// ------------------------------------------------------------------------------------------------------------- row

@interface BKRecentRow : UIControl
@property(nonatomic, copy) NSString *url;
- (instancetype)initWithURL:(NSString *)url;
- (void)applyTheme;
@end

@implementation BKRecentRow {
  UIImageView *_glyph;
  UILabel *_title;
  UILabel *_subtitle;
}

- (instancetype)initWithURL:(NSString *)url {
  if ((self = [super initWithFrame:CGRectZero])) {
    _url = [url copy];
    NSURL *parsed = [NSURL URLWithString:url];
    NSString *host = parsed.host ?: url;
    if ([host hasPrefix:@"www."]) {
      host = [host substringFromIndex:4];
    }
    _glyph = [[UIImageView alloc] initWithImage:[BKIcons image:BKIconGlobe size:17]];
    _glyph.contentMode = UIViewContentModeCenter;
    _glyph.layer.cornerRadius = 8;
    [self addSubview:_glyph];
    _title = [[UILabel alloc] init];
    _title.text = host;
    _title.font = [BKTheme font:15 weight:UIFontWeightMedium];
    [self addSubview:_title];
    _subtitle = [[UILabel alloc] init];
    NSString *rest = parsed.path.length > 1 ? parsed.path : @"";
    _subtitle.text = rest;
    _subtitle.font = [BKTheme font:12 weight:UIFontWeightRegular];
    [self addSubview:_subtitle];
    self.accessibilityLabel = host;
    self.accessibilityTraits = UIAccessibilityTraitButton;
    [self applyTheme];
  }
  return self;
}

- (void)applyTheme {
  _glyph.tintColor = [BKTheme secondaryText];
  _glyph.backgroundColor = [BKTheme pillBackground];
  _title.textColor = [BKTheme primaryText];
  _subtitle.textColor = [BKTheme secondaryText];
}

- (void)setHighlighted:(BOOL)highlighted {
  [super setHighlighted:highlighted];
  self.backgroundColor = highlighted ? [BKTheme cellSelected] : UIColor.clearColor;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  const CGFloat height = self.bounds.size.height;
  _glyph.frame = CGRectMake(12, (height - 32) / 2, 32, 32);
  const CGFloat textWidth = self.bounds.size.width - 56 - 12;
  if (_subtitle.text.length) {
    _title.frame = CGRectMake(56, 7, textWidth, 20);
    _subtitle.frame = CGRectMake(56, 27, textWidth, 16);
  } else {
    _title.frame = CGRectMake(56, (height - 20) / 2, textWidth, 20);
    _subtitle.frame = CGRectZero;
  }
}

@end

// ------------------------------------------------------------------------------------------------------------ page

@implementation BKStartPageView {
  UIScrollView *_scroll;
  UIImageView *_logo;
  UILabel *_title;
  UIControl *_search;
  UIImageView *_searchIcon;
  UILabel *_searchLabel;
  UIView *_privateCard;
  UIImageView *_privateIcon;
  UILabel *_privateTitle;
  UILabel *_privateText;
  UILabel *_favoritesHeader;
  NSMutableArray<BKTile *> *_tiles;
  UILabel *_recentHeader;
  UIView *_recentCard;
  NSMutableArray<BKRecentRow *> *_rows;
  NSMutableArray<UIView *> *_separators;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    _tiles = [NSMutableArray array];
    _rows = [NSMutableArray array];
    _separators = [NSMutableArray array];
    _scroll = [[UIScrollView alloc] init];
    _scroll.alwaysBounceVertical = YES;
    _scroll.showsVerticalScrollIndicator = NO;
    _scroll.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    [self addSubview:_scroll];

    _logo = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"blinker_logo"]];
    _logo.contentMode = UIViewContentModeScaleAspectFit;
    [_scroll addSubview:_logo];
    _title = [[UILabel alloc] init];
    _title.text = @"Blinker Fluid";
    _title.textAlignment = NSTextAlignmentCenter;
    _title.font = [BKTheme font:22 weight:UIFontWeightBold];
    [_scroll addSubview:_title];

    _search = [[UIControl alloc] init];
    _search.layer.cornerRadius = 24;
    [_search addTarget:self action:@selector(searchTapped) forControlEvents:UIControlEventTouchUpInside];
    _search.accessibilityLabel = BKL(@"Search or enter address");
    _search.accessibilityTraits = UIAccessibilityTraitSearchField;
    _searchIcon = [[UIImageView alloc] initWithImage:[BKIcons image:BKIconSearch size:18]];
    _searchIcon.contentMode = UIViewContentModeCenter;
    _searchIcon.userInteractionEnabled = NO;
    [_search addSubview:_searchIcon];
    _searchLabel = [[UILabel alloc] init];
    _searchLabel.text = BKL(@"Search or enter address");
    _searchLabel.font = [BKTheme font:16 weight:UIFontWeightRegular];
    _searchLabel.userInteractionEnabled = NO;
    [_search addSubview:_searchLabel];
    [_scroll addSubview:_search];

    _privateCard = [[UIView alloc] init];
    _privateCard.layer.cornerRadius = 16;
    _privateIcon = [[UIImageView alloc] initWithImage:[BKIcons image:BKIconPrivate size:28]];
    _privateIcon.contentMode = UIViewContentModeCenter;
    [_privateCard addSubview:_privateIcon];
    _privateTitle = [[UILabel alloc] init];
    _privateTitle.text = BKL(@"Private Browsing");
    _privateTitle.font = [BKTheme font:16 weight:UIFontWeightSemibold];
    [_privateCard addSubview:_privateTitle];
    _privateText = [[UILabel alloc] init];
    _privateText.text = BKL(@"Private tabs are not saved.");
    _privateText.font = [BKTheme font:13 weight:UIFontWeightRegular];
    _privateText.numberOfLines = 2;
    [_privateCard addSubview:_privateText];
    _privateCard.hidden = ![BKTheme isPrivateSession];
    [_scroll addSubview:_privateCard];

    _favoritesHeader = [self headerLabel:BKL(@"Favorites")];
    _recentHeader = [self headerLabel:BKL(@"Recent")];
    _recentCard = [[UIView alloc] init];
    _recentCard.layer.cornerRadius = 16;
    _recentCard.clipsToBounds = YES;
    [_scroll addSubview:_recentCard];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:BKThemeDidChangeNotification object:nil];
    [self reloadContent];
    [self applyTheme];
  }
  return self;
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (UILabel *)headerLabel:(NSString *)text {
  UILabel *label = [[UILabel alloc] init];
  label.text = text;
  label.font = [BKTheme font:13 weight:UIFontWeightSemibold];
  [_scroll addSubview:label];
  return label;
}

- (void)setHidden:(BOOL)hidden {
  BOOL wasHidden = self.hidden;
  [super setHidden:hidden];
  if (wasHidden && !hidden) {
    [self reloadContent];  // history and shortcuts may have changed while a page was open
  }
}

- (void)searchTapped {
  if (self.onSearchTapped) {
    self.onSearchTapped();
  }
}

- (void)rebuildShortcutGrid {
  [self reloadContent];
}

- (void)reloadContent {
  for (BKTile *tile in _tiles) {
    [tile removeFromSuperview];
  }
  [_tiles removeAllObjects];
  for (NSDictionary *item in [BKSettings shortcuts]) {
    if (_tiles.count >= 8) {
      break;
    }
    NSString *title = item[@"title"], *url = item[@"url"];
    BKTile *tile = [[BKTile alloc] initWithTitle:title url:url];
    [tile addTarget:self action:@selector(tileTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_scroll addSubview:tile];
    [_tiles addObject:tile];
    UIImage *cached = [BKFavicon cachedImageForURLString:url];
    if (cached) {
      [tile setIconImage:cached];
    } else {
      __weak BKTile *weakTile = tile;
      [BKFavicon loadForURLString:url completion:^(UIImage *image) {
        BKTile *strong = weakTile;
        if (strong && [strong.url isEqualToString:url]) {
          [strong setIconImage:image];
        }
      }];
    }
  }

  for (BKRecentRow *row in _rows) {
    [row removeFromSuperview];
  }
  for (UIView *separator in _separators) {
    [separator removeFromSuperview];
  }
  [_rows removeAllObjects];
  [_separators removeAllObjects];
  NSMutableSet *seenHosts = [NSMutableSet set];
  for (NSString *url in [BKSettings historyURLs]) {
    NSString *host = [NSURL URLWithString:url].host;
    if (!host.length || [seenHosts containsObject:host]) {
      continue;
    }
    [seenHosts addObject:host];
    BKRecentRow *row = [[BKRecentRow alloc] initWithURL:url];
    [row addTarget:self action:@selector(rowTapped:) forControlEvents:UIControlEventTouchUpInside];
    [_recentCard addSubview:row];
    [_rows addObject:row];
    if (_rows.count >= 4) {
      break;
    }
  }
  for (NSUInteger i = 1; i < _rows.count; i++) {
    UIView *separator = [[UIView alloc] init];
    [_recentCard addSubview:separator];
    [_separators addObject:separator];
  }
  _privateCard.hidden = ![BKTheme isPrivateSession];
  [self applyTheme];
  [self setNeedsLayout];
}

- (void)tileTapped:(BKTile *)tile {
  [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight] impactOccurred];
  if (self.onNavigate && tile.url.length) {
    self.onNavigate(tile.url);
  }
}

- (void)rowTapped:(BKRecentRow *)row {
  if (self.onNavigate && row.url.length) {
    self.onNavigate(row.url);
  }
}

- (void)applyTheme {
  self.backgroundColor = [BKTheme pageBackground];
  _title.textColor = [BKTheme primaryText];
  _search.backgroundColor = [BKTheme pillBackground];
  _searchIcon.tintColor = [BKTheme secondaryText];
  _searchLabel.textColor = [BKTheme secondaryText];
  _favoritesHeader.textColor = [BKTheme secondaryText];
  _recentHeader.textColor = [BKTheme secondaryText];
  _recentCard.backgroundColor = [BKTheme cellBackground];
  UIColor *accent = [BKTheme accent];
  _privateCard.backgroundColor = [accent colorWithAlphaComponent:0.14];
  _privateIcon.tintColor = accent;
  _privateTitle.textColor = [BKTheme primaryText];
  _privateText.textColor = [BKTheme secondaryText];
  for (BKTile *tile in _tiles) {
    [tile applyTheme];
  }
  for (BKRecentRow *row in _rows) {
    [row applyTheme];
  }
  for (UIView *separator in _separators) {
    separator.backgroundColor = [BKTheme separator];
  }
}

- (void)layoutSubviews {
  [super layoutSubviews];
  _scroll.frame = self.bounds;
  const CGFloat width = self.bounds.size.width;
  const BOOL landscape = width > self.bounds.size.height;
  const CGFloat side = MAX(16, self.safeAreaInsets.left + 8);
  const CGFloat column = MIN(width - 2 * side, 520);
  const CGFloat left = (width - column) / 2;
  CGFloat y = landscape ? 14 : 34;

  const CGFloat logoSize = landscape ? 44 : 68;
  _logo.frame = CGRectMake((width - logoSize) / 2, y, logoSize, logoSize);
  y += logoSize + 8;
  _title.hidden = landscape;
  if (!landscape) {
    _title.frame = CGRectMake(left, y, column, 28);
    y += 28 + 16;
  } else {
    y += 4;
  }

  _search.frame = CGRectMake(left, y, column, 48);
  _searchIcon.frame = CGRectMake(10, 0, 30, 48);
  _searchLabel.frame = CGRectMake(44, 0, column - 56, 48);
  y += 48 + 18;

  if (!_privateCard.hidden) {
    _privateCard.frame = CGRectMake(left, y, column, 76);
    _privateIcon.frame = CGRectMake(10, 0, 52, 76);
    _privateTitle.frame = CGRectMake(66, 14, column - 78, 20);
    _privateText.frame = CGRectMake(66, 36, column - 78, 34);
    y += 76 + 18;
  }

  _favoritesHeader.frame = CGRectMake(left + 4, y, column, 18);
  y += 18 + 10;
  const NSInteger perRow = landscape ? 8 : 4;
  const CGFloat slot = column / (CGFloat)perRow;
  NSInteger index = 0;
  for (BKTile *tile in _tiles) {
    NSInteger r = index / perRow, c = index % perRow;
    tile.frame = CGRectMake(left + slot * c, y + r * 94, slot, 84);
    index++;
  }
  NSInteger rowsUsed = _tiles.count ? (NSInteger)((_tiles.count + perRow - 1) / perRow) : 0;
  y += rowsUsed * 94 + 6;

  const BOOL showRecent = _rows.count > 0 && ![BKTheme isPrivateSession];
  _recentHeader.hidden = !showRecent;
  _recentCard.hidden = !showRecent;
  if (showRecent) {
    _recentHeader.frame = CGRectMake(left + 4, y, column, 18);
    y += 18 + 10;
    const CGFloat rowHeight = 50;
    _recentCard.frame = CGRectMake(left, y, column, rowHeight * _rows.count);
    for (NSUInteger i = 0; i < _rows.count; i++) {
      _rows[i].frame = CGRectMake(0, rowHeight * i, column, rowHeight);
      if (i > 0) {
        _separators[i - 1].frame = CGRectMake(56, rowHeight * i, column - 56, 0.5);
      }
    }
    y += rowHeight * _rows.count + 18;
  }
  _scroll.contentSize = CGSizeMake(width, y + 24);
}

@end
