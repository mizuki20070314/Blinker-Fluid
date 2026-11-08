// SPDX-License-Identifier: GPL-3.0-or-later
#import "BKTabGrid.h"
#import "BKCore.h"
#import "BKIcons.h"
#import "BKTheme.h"

static const CGFloat kHeaderHeight = 34;

// ------------------------------------------------------------------------------------------------------------- card

@interface BKTabCard : UICollectionViewCell <UIGestureRecognizerDelegate>
@property(nonatomic, copy, nullable) void (^onClose)(void);
- (void)configureWithTitle:(NSString *)title
                       url:(NSString *)url
                   preview:(nullable UIImage *)preview
                   cropTop:(CGFloat)top
                cropBottom:(CGFloat)bottom
                   current:(BOOL)current;
@end

@implementation BKTabCard {
  UIView *_card;
  UILabel *_title;
  UIButton *_close;
  UIView *_clip;
  UIImageView *_thumb;
  UIImageView *_placeholder;
  UIPanGestureRecognizer *_pan;
  CGFloat _cropTop, _cropBottom;
  BOOL _current;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.contentView.layer.shadowColor = UIColor.blackColor.CGColor;
    self.contentView.layer.shadowOpacity = 0.14;
    self.contentView.layer.shadowRadius = 6;
    self.contentView.layer.shadowOffset = CGSizeMake(0, 2);
    _card = [[UIView alloc] init];
    _card.layer.cornerRadius = 14;
    _card.layer.masksToBounds = YES;
    [self.contentView addSubview:_card];
    _title = [[UILabel alloc] init];
    _title.font = [BKTheme font:13 weight:UIFontWeightSemibold];
    _title.lineBreakMode = NSLineBreakByTruncatingTail;
    [_card addSubview:_title];
    _close = [UIButton buttonWithType:UIButtonTypeCustom];
    [_close setImage:[BKIcons image:BKIconCloseCircle size:20] forState:UIControlStateNormal];
    [_close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    _close.accessibilityLabel = BKL(@"Close Tab");
    [_card addSubview:_close];
    _clip = [[UIView alloc] init];
    _clip.clipsToBounds = YES;
    [_card addSubview:_clip];
    _thumb = [[UIImageView alloc] init];
    [_clip addSubview:_thumb];
    _placeholder = [[UIImageView alloc] init];
    _placeholder.contentMode = UIViewContentModeCenter;
    [_clip addSubview:_placeholder];

    _pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(panned:)];
    _pan.delegate = self;
    [self.contentView addGestureRecognizer:_pan];
  }
  return self;
}

- (void)prepareForReuse {
  [super prepareForReuse];
  self.contentView.transform = CGAffineTransformIdentity;
  self.contentView.alpha = 1;
}

- (void)configureWithTitle:(NSString *)title
                       url:(NSString *)url
                   preview:(UIImage *)preview
                   cropTop:(CGFloat)top
                cropBottom:(CGFloat)bottom
                   current:(BOOL)current {
  _title.text = title;
  _current = current;
  _cropTop = top;
  _cropBottom = bottom;
  _card.backgroundColor = [BKTheme tileBackground];
  _title.textColor = [BKTheme primaryText];
  _close.tintColor = [BKTheme secondaryText];
  _clip.backgroundColor = [BKTheme pageBackground];
  BOOL blank = !url.length || [url isEqualToString:@"about:blank"];
  BOOL usable = preview && preview.size.width > 1 && preview.size.height > 1 && !blank;
  _thumb.image = usable ? preview : nil;
  _thumb.hidden = !usable;
  _placeholder.hidden = usable;
  if (!usable) {
    UIImage *logo = blank ? [UIImage imageNamed:@"blinker_logo"] : nil;
    if (logo) {
      _placeholder.image = logo;
      _placeholder.contentMode = UIViewContentModeScaleAspectFit;
    } else {
      _placeholder.image = [BKIcons image:BKIconGlobe size:34];
      _placeholder.tintColor = [BKTheme tertiaryText];
      _placeholder.contentMode = UIViewContentModeCenter;
    }
  }
  self.contentView.layer.borderWidth = 0;
  _card.layer.borderWidth = current ? 2.5 : 0.5;
  _card.layer.borderColor = (current ? [BKTheme accent] : [BKTheme separator]).CGColor;
  [self setNeedsLayout];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  const CGRect bounds = self.contentView.bounds;
  _card.frame = bounds;
  self.contentView.layer.shadowPath = [UIBezierPath bezierPathWithRoundedRect:bounds cornerRadius:14].CGPath;
  _title.frame = CGRectMake(10, 0, bounds.size.width - 10 - 34, kHeaderHeight);
  _close.frame = CGRectMake(bounds.size.width - 34, 0, 34, kHeaderHeight);
  _clip.frame = CGRectMake(0, kHeaderHeight, bounds.size.width, bounds.size.height - kHeaderHeight);
  _placeholder.frame = _clip.bounds;
  if (_thumb.image) {
    const CGSize box = _clip.bounds.size;
    const CGSize img = _thumb.image.size;
    const CGFloat visible = MAX(1 - _cropTop - _cropBottom, 0.2);
    CGFloat scale = MAX(box.width / img.width, box.height / (img.height * visible));
    CGSize shown = CGSizeMake(img.width * scale, img.height * scale);
    _thumb.frame = CGRectMake((box.width - shown.width) / 2, -_cropTop * shown.height, shown.width, shown.height);
  }
}

- (void)closeTapped {
  if (self.onClose) {
    self.onClose();
  }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gesture {
  if (gesture != _pan) {
    return YES;
  }
  CGPoint velocity = [_pan velocityInView:self.contentView];
  return fabs(velocity.x) > fabs(velocity.y) * 1.4;
}

- (void)panned:(UIPanGestureRecognizer *)pan {
  UIView *view = self.contentView;
  const CGFloat width = MAX(view.bounds.size.width, 1);
  const CGFloat dx = [pan translationInView:view].x;
  switch (pan.state) {
    case UIGestureRecognizerStateChanged:
      view.transform = CGAffineTransformMakeTranslation(dx, 0);
      view.alpha = MAX(0.25, 1 - fabs(dx) / (width * 1.3));
      break;
    case UIGestureRecognizerStateEnded:
    case UIGestureRecognizerStateCancelled: {
      const CGFloat vx = [pan velocityInView:view].x;
      if (fabs(dx) > width * 0.42 || fabs(vx) > 900) {
        if (self.onClose) {
          self.onClose();
        }
      } else {
        [UIView animateWithDuration:0.28
                              delay:0
             usingSpringWithDamping:0.8
              initialSpringVelocity:0
                            options:0
                         animations:^{
                           view.transform = CGAffineTransformIdentity;
                           view.alpha = 1;
                         }
                         completion:nil];
      }
      break;
    }
    default:
      break;
  }
}

@end

// -------------------------------------------------------------------------------------------------------- controller

@interface BKTabGridViewController () <UICollectionViewDataSource, UICollectionViewDelegateFlowLayout>
@end

@implementation BKTabGridViewController {
  __weak UIViewController *_stock;
  NSMutableArray<NSString *> *_titles;
  NSMutableArray<NSString *> *_urls;
  NSMutableArray<UIImage *> *_previews;
  void (^_onSelect)(NSInteger);
  BOOL (^_onClose)(NSInteger);
  void (^_onAdd)(void);
  void (^_onReorder)(NSInteger, NSInteger);
  NSString *_currentURL;
  CGFloat _cropTop, _cropBottom;

  UILabel *_heading;
  UIView *_headerLine;
  UICollectionView *_collection;
  UIView *_footer;
  UIView *_footerLine;
  UIButton *_addButton;
  UIButton *_doneButton;
  UILabel *_privateBadge;
}

- (instancetype)initWithStockTabs:(UIViewController *)stock
                       currentURL:(NSString *)currentURL
                          cropTop:(CGFloat)cropTop
                       cropBottom:(CGFloat)cropBottom {
  if ((self = [super initWithNibName:nil bundle:nil])) {
    _stock = stock;
    _titles = [[stock valueForKey:@"titles"] mutableCopy] ?: [NSMutableArray array];
    _urls = [[stock valueForKey:@"urls"] mutableCopy] ?: [NSMutableArray array];
    _previews = [[stock valueForKey:@"previews"] mutableCopy] ?: [NSMutableArray array];
    _onSelect = [stock valueForKey:@"onSelect"];
    _onClose = [stock valueForKey:@"onClose"];
    _onAdd = [stock valueForKey:@"onAdd"];
    _onReorder = [stock valueForKey:@"onReorder"];
    _currentURL = [currentURL copy];
    _cropTop = cropTop;
    _cropBottom = cropBottom;
    self.modalPresentationStyle = UIModalPresentationFullScreen;
    self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
  }
  return self;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
  return [BKTheme statusBarStyle];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  _heading = [[UILabel alloc] init];
  _heading.textAlignment = NSTextAlignmentCenter;
  _heading.font = [BKTheme font:17 weight:UIFontWeightSemibold];
  [self.view addSubview:_heading];
  _headerLine = [[UIView alloc] init];
  [self.view addSubview:_headerLine];

  UICollectionViewFlowLayout *layout = [[UICollectionViewFlowLayout alloc] init];
  layout.minimumInteritemSpacing = 12;
  layout.minimumLineSpacing = 14;
  layout.sectionInset = UIEdgeInsetsMake(14, 16, 18, 16);
  _collection = [[UICollectionView alloc] initWithFrame:CGRectZero collectionViewLayout:layout];
  _collection.dataSource = self;
  _collection.delegate = self;
  _collection.alwaysBounceVertical = YES;
  [_collection registerClass:[BKTabCard class] forCellWithReuseIdentifier:@"card"];
  [_collection addGestureRecognizer:[[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(reorderGesture:)]];
  [self.view addSubview:_collection];

  _footer = [[UIView alloc] init];
  [self.view addSubview:_footer];
  _footerLine = [[UIView alloc] init];
  [_footer addSubview:_footerLine];
  _addButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [_addButton setImage:[BKIcons image:BKIconPlus size:24] forState:UIControlStateNormal];
  _addButton.layer.cornerRadius = 24;
  _addButton.accessibilityLabel = BKL(@"New Tab");
  [_addButton addTarget:self action:@selector(addTapped) forControlEvents:UIControlEventTouchUpInside];
  [_footer addSubview:_addButton];
  _doneButton = [UIButton buttonWithType:UIButtonTypeCustom];
  [_doneButton setTitle:BKL(@"Done") forState:UIControlStateNormal];
  _doneButton.titleLabel.font = [BKTheme font:17 weight:UIFontWeightSemibold];
  [_doneButton addTarget:self action:@selector(doneTapped) forControlEvents:UIControlEventTouchUpInside];
  [_footer addSubview:_doneButton];

  _privateBadge = [[UILabel alloc] init];
  _privateBadge.text = [@" " stringByAppendingString:BKL(@"Private")];
  _privateBadge.font = [BKTheme font:12 weight:UIFontWeightSemibold];
  _privateBadge.textAlignment = NSTextAlignmentCenter;
  _privateBadge.layer.cornerRadius = 11;
  _privateBadge.layer.masksToBounds = YES;
  _privateBadge.hidden = ![BKTheme isPrivateSession];
  [self.view addSubview:_privateBadge];

  [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applyTheme) name:BKThemeDidChangeNotification object:nil];
  [self applyTheme];
  [self updateHeading];
}

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)applyTheme {
  self.view.backgroundColor = [BKTheme groupedBackground];
  _heading.textColor = [BKTheme primaryText];
  _headerLine.backgroundColor = [BKTheme separator];
  _footer.backgroundColor = [BKTheme chromeBackground];
  _footerLine.backgroundColor = [BKTheme separator];
  _collection.backgroundColor = UIColor.clearColor;
  _addButton.backgroundColor = [BKTheme accent];
  _addButton.tintColor = UIColor.whiteColor;
  [_doneButton setTitleColor:[BKTheme accent] forState:UIControlStateNormal];
  _privateBadge.backgroundColor = [[BKTheme accent] colorWithAlphaComponent:0.16];
  _privateBadge.textColor = [BKTheme accent];
  [_collection reloadData];
  [self setNeedsStatusBarAppearanceUpdate];
}

- (void)updateHeading {
  NSInteger count = _titles.count;
  _heading.text = count == 1 ? BKL(@"1 Tab") : [NSString stringWithFormat:BKL(@"%ld Tabs"), (long)count];
}

- (void)viewDidLayoutSubviews {
  [super viewDidLayoutSubviews];
  const UIEdgeInsets safe = self.view.safeAreaInsets;
  const CGFloat width = self.view.bounds.size.width;
  const CGFloat headerHeight = 46;
  const CGFloat footerHeight = 60 + safe.bottom;
  _heading.frame = CGRectMake(0, safe.top, width, headerHeight);
  _headerLine.frame = CGRectMake(0, safe.top + headerHeight - 0.5, width, 0.5);
  _footer.frame = CGRectMake(0, self.view.bounds.size.height - footerHeight, width, footerHeight);
  _footerLine.frame = CGRectMake(0, 0, width, 0.5);
  _addButton.frame = CGRectMake((width - 48) / 2, 6, 48, 48);
  CGSize doneSize = [_doneButton sizeThatFits:CGSizeMake(200, 44)];
  _doneButton.frame = CGRectMake(width - safe.right - doneSize.width - 20, 8, doneSize.width + 8, 44);
  CGSize badge = [_privateBadge sizeThatFits:CGSizeMake(200, 24)];
  _privateBadge.frame = CGRectMake(MAX(12, safe.left + 8), safe.top + (headerHeight - 24) / 2, badge.width + 16, 24);
  _collection.frame = CGRectMake(0, safe.top + headerHeight, width, self.view.bounds.size.height - safe.top - headerHeight - footerHeight);
  UICollectionViewFlowLayout *layout = (UICollectionViewFlowLayout *)_collection.collectionViewLayout;
  const CGFloat usable = width - layout.sectionInset.left - layout.sectionInset.right - safe.left - safe.right;
  const NSInteger columns = width > 600 ? 4 : (width > self.view.bounds.size.height ? 3 : 2);
  const CGFloat itemWidth = floor((usable - layout.minimumInteritemSpacing * (columns - 1)) / columns);
  CGSize size = CGSizeMake(itemWidth, kHeaderHeight + itemWidth * 1.18);
  if (!CGSizeEqualToSize(layout.itemSize, size)) {
    layout.itemSize = size;
    [layout invalidateLayout];
  }
}

// --------------------------------------------------------------------------------------------------------- actions

- (void)doneTapped {
  [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)addTapped {
  void (^handler)(void) = _onAdd;
  [self dismissViewControllerAnimated:YES
                           completion:^{
                             if (handler) {
                               handler();
                             }
                           }];
}

- (BOOL)isCurrent:(NSInteger)index {
  NSString *url = _urls[index];
  NSString *current = _currentURL.length ? _currentURL : @"about:blank";
  return [url isEqualToString:current] || (_urls.count == 1);
}

- (void)closeCardAtIndex:(NSInteger)index {
  if (index < 0 || index >= (NSInteger)_titles.count) {
    return;
  }
  NSIndexPath *path = [NSIndexPath indexPathForItem:index inSection:0];
  UICollectionViewCell *cell = [_collection cellForItemAtIndexPath:path];
  if (_titles.count <= 1) {
    void (^replace)(void) = self.onCloseLastTab;
    if (replace) {
      [UIView animateWithDuration:0.18 animations:^{
        cell.contentView.alpha = 0;
        cell.contentView.transform = CGAffineTransformMakeScale(0.9, 0.9);
      }];
      [self dismissViewControllerAnimated:YES completion:^{ replace(); }];
      return;
    }
  }
  BOOL ok = _onClose ? _onClose(index) : YES;
  if (!ok) {  // the last tab (or the open tab, which the stock code hands over itself): bring the card back
    [UIView animateWithDuration:0.25 animations:^{
      cell.contentView.transform = CGAffineTransformIdentity;
      cell.contentView.alpha = 1;
    }];
    return;
  }
  [_titles removeObjectAtIndex:index];
  [_urls removeObjectAtIndex:index];
  [_previews removeObjectAtIndex:index];
  [_collection performBatchUpdates:^{ [self->_collection deleteItemsAtIndexPaths:@[ path ]]; }
                        completion:^(BOOL finished) { [self->_collection reloadData]; }];
  [self updateHeading];
}

- (void)reorderGesture:(UILongPressGestureRecognizer *)gesture {
  switch (gesture.state) {
    case UIGestureRecognizerStateBegan: {
      NSIndexPath *path = [_collection indexPathForItemAtPoint:[gesture locationInView:_collection]];
      if (path && _titles.count > 1) {
        [[[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium] impactOccurred];
        [_collection beginInteractiveMovementForItemAtIndexPath:path];
      }
      break;
    }
    case UIGestureRecognizerStateChanged:
      [_collection updateInteractiveMovementTargetPosition:[gesture locationInView:_collection]];
      break;
    case UIGestureRecognizerStateEnded:
      [_collection endInteractiveMovement];
      break;
    default:
      [_collection cancelInteractiveMovement];
      break;
  }
}

// -------------------------------------------------------------------------------------------------- collection view

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  return _titles.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
  BKTabCard *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"card" forIndexPath:indexPath];
  NSInteger index = indexPath.item;
  [cell configureWithTitle:_titles[index]
                       url:_urls[index]
                   preview:_previews[index]
                   cropTop:_cropTop
                cropBottom:_cropBottom
                   current:[self isCurrent:index]];
  __weak BKTabGridViewController *weakSelf = self;
  __weak BKTabCard *weakCell = cell;
  cell.onClose = ^{
    BKTabGridViewController *strongSelf = weakSelf;
    BKTabCard *strongCell = weakCell;
    NSIndexPath *path = strongCell ? [strongSelf->_collection indexPathForCell:strongCell] : nil;
    if (strongSelf && path) {
      [strongSelf closeCardAtIndex:path.item];
    }
  };
  return cell;
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
  NSInteger index = indexPath.item;
  void (^handler)(NSInteger) = _onSelect;
  [self dismissViewControllerAnimated:YES
                           completion:^{
                             if (handler) {
                               handler(index);
                             }
                           }];
}

- (BOOL)collectionView:(UICollectionView *)collectionView canMoveItemAtIndexPath:(NSIndexPath *)indexPath {
  return _titles.count > 1;
}

- (void)collectionView:(UICollectionView *)collectionView moveItemAtIndexPath:(NSIndexPath *)from toIndexPath:(NSIndexPath *)to {
  NSInteger a = from.item, b = to.item;
  if (a == b || a >= (NSInteger)_titles.count || b >= (NSInteger)_titles.count) {
    return;
  }
  NSString *title = _titles[a], *url = _urls[a];
  UIImage *preview = _previews[a];
  [_titles removeObjectAtIndex:a];
  [_urls removeObjectAtIndex:a];
  [_previews removeObjectAtIndex:a];
  [_titles insertObject:title atIndex:b];
  [_urls insertObject:url atIndex:b];
  [_previews insertObject:preview atIndex:b];
  if (_onReorder) {
    _onReorder(a, b);
  }
}

@end
