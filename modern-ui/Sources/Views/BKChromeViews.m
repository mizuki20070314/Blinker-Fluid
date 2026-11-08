// SPDX-License-Identifier: GPL-3.0-or-later
#import "BKChromeViews.h"
#import "BKCore.h"
#import "BKTheme.h"

static const CGFloat kHairline = 0.5;

// ------------------------------------------------------------------------------------------------------- BKBarButton

@implementation BKBarButton

- (instancetype)initWithIcon:(BKIcon)icon iconSize:(CGFloat)size {
  if ((self = [super initWithFrame:CGRectZero])) {
    _icon = icon;
    _iconSize = size;
    self.adjustsImageWhenHighlighted = NO;
    self.adjustsImageWhenDisabled = NO;
    self.exclusiveTouch = YES;
    [self refreshImage];
    [self applyTheme];
  }
  return self;
}

- (void)refreshImage {
  [super setImage:[BKIcons image:_icon size:_iconSize] forState:UIControlStateNormal];
}

- (void)setIcon:(BKIcon)icon {
  if (_icon != icon) {
    _icon = icon;
    [self refreshImage];
  }
}

// The engine glue sets ic_reload / ic_stop images here (nil in the iOS 12 build); the chrome owns the icons.
- (void)setImage:(UIImage *)image forState:(UIControlState)state {
}

- (void)setEnabled:(BOOL)enabled {
  [super setEnabled:enabled];
  self.alpha = enabled ? 1.0 : 0.30;
  if (self.enabledDidChange) {
    self.enabledDidChange(enabled);
  }
}

- (void)setHighlighted:(BOOL)highlighted {
  [super setHighlighted:highlighted];
  self.alpha = highlighted ? 0.45 : (self.enabled ? 1.0 : 0.30);
}

- (void)applyTheme {
  self.tintColor = [BKTheme iconTint];
}

@end

// ----------------------------------------------------------------------------------------------------- BKTabsButton

@implementation BKTabsButton {
  UILabel *_countLabel;
}

- (instancetype)initWithIcon:(BKIcon)icon iconSize:(CGFloat)size {
  if ((self = [super initWithIcon:icon iconSize:size])) {
    _countLabel = [[UILabel alloc] init];
    _countLabel.textAlignment = NSTextAlignmentCenter;
    _countLabel.font = [UIFont monospacedDigitSystemFontOfSize:11 weight:UIFontWeightBold];
    _countLabel.adjustsFontSizeToFitWidth = YES;
    _countLabel.minimumScaleFactor = 0.6;
    _countLabel.userInteractionEnabled = NO;
    [self addSubview:_countLabel];
    _count = 1;
    _countLabel.text = @"1";
    [self applyTheme];
  }
  return self;
}

- (void)setCount:(NSInteger)count {
  _count = count;
  _countLabel.text = count > 99 ? @"99+" : [NSString stringWithFormat:@"%ld", (long)MAX(count, 0)];
  self.accessibilityValue = [NSString stringWithFormat:@"%ld", (long)count];
}

- (void)applyTheme {
  [super applyTheme];
  _countLabel.textColor = [BKTheme iconTint];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  CGRect box = self.imageView.frame;
  if (CGRectIsEmpty(box)) {
    box = CGRectMake((self.bounds.size.width - self.iconSize) / 2, (self.bounds.size.height - self.iconSize) / 2, self.iconSize, self.iconSize);
  }
  _countLabel.frame = CGRectInset(box, self.iconSize * 0.17, self.iconSize * 0.17);
  [self bringSubviewToFront:_countLabel];
}

@end

// ------------------------------------------------------------------------------------------------------ BKProgressView

@implementation BKProgressView {
  CALayer *_fill;
  NSInteger _generation;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    self.userInteractionEnabled = NO;
    _fill = [CALayer layer];
    _fill.anchorPoint = CGPointMake(0, 0.5);
    _fill.opacity = 0;
    [self.layer addSublayer:_fill];
    [self applyTheme];
  }
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  _fill.bounds = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height);
  _fill.position = CGPointMake(0, self.bounds.size.height / 2);
  [CATransaction commit];
}

- (void)applyTheme {
  _fill.backgroundColor = [BKTheme accent].CGColor;
}

- (void)setScale:(CGFloat)scale opacity:(float)opacity {
  [CATransaction begin];
  [CATransaction setDisableActions:YES];
  _fill.transform = CATransform3DMakeScale(MAX(scale, 0.0001), 1, 1);
  _fill.opacity = opacity;
  [CATransaction commit];
}

- (void)start {
  _generation++;
  [_fill removeAllAnimations];
  [self setScale:0.10 opacity:1];
  CABasicAnimation *creep = [CABasicAnimation animationWithKeyPath:@"transform.scale.x"];
  creep.fromValue = @0.10;
  creep.toValue = @0.84;
  creep.duration = 8.0;
  creep.timingFunction = [CAMediaTimingFunction functionWithControlPoints:0.12f:0.6f:0.3f:1.0f];
  creep.fillMode = kCAFillModeForwards;
  creep.removedOnCompletion = NO;
  [_fill addAnimation:creep forKey:@"creep"];
}

- (void)finish {
  NSInteger generation = ++_generation;
  if (_fill.opacity < 0.01) {
    return;  // nothing was running
  }
  CALayer *presentation = _fill.presentationLayer;
  CGFloat current = MAX(presentation ? presentation.transform.m11 : 0.1, 0.1);
  [_fill removeAllAnimations];
  [self setScale:1.0 opacity:1];  // the model value is where the line ends up; the animation below shows the way there
  CABasicAnimation *grow = [CABasicAnimation animationWithKeyPath:@"transform.scale.x"];
  grow.fromValue = @(current);
  grow.toValue = @1.0;
  grow.duration = 0.20;
  grow.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
  [CATransaction begin];
  [CATransaction setCompletionBlock:^{
    if (generation != self->_generation) {
      return;
    }
    CABasicAnimation *fade = [CABasicAnimation animationWithKeyPath:@"opacity"];
    fade.fromValue = @1;
    fade.toValue = @0;
    fade.duration = 0.25;
    [self->_fill addAnimation:fade forKey:@"fade"];
    [self setScale:1.0 opacity:0];
  }];
  [_fill addAnimation:grow forKey:@"grow"];
  [CATransaction commit];
}

- (void)reset {
  _generation++;
  [_fill removeAllAnimations];
  [self setScale:0.0001 opacity:0];
}

@end

// -------------------------------------------------------------------------------------------------------- BKAddressPill

static NSString *BKDisplayHost(NSString *host) {
  return [host hasPrefix:@"www."] ? [host substringFromIndex:4] : host;
}

@interface BKAddressPill () <UIGestureRecognizerDelegate>
@end

@implementation BKAddressPill {
  UIImageView *_leadingIcon;
  UILabel *_label;
  NSString *_text;
  BOOL _blank;
  BKSecurityState _security;
  BOOL _loading;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    _text = @"";
    _blank = YES;
    _leadingIcon = [[UIImageView alloc] init];
    _leadingIcon.contentMode = UIViewContentModeScaleAspectFit;
    [self addSubview:_leadingIcon];
    _label = [[UILabel alloc] init];
    _label.font = [BKTheme font:16 weight:UIFontWeightMedium];
    _label.lineBreakMode = NSLineBreakByTruncatingTail;
    [self addSubview:_label];
    _reloadButton = [[BKBarButton alloc] initWithIcon:BKIconReload iconSize:19];
    [self addSubview:_reloadButton];
    self.accessibilityLabel = BKL(@"Address");

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapped:)];
    tap.delegate = self;
    [self addGestureRecognizer:tap];
    UILongPressGestureRecognizer *hold = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(held:)];
    hold.minimumPressDuration = 0.55;
    hold.delegate = self;
    [self addGestureRecognizer:hold];
    for (NSNumber *direction in @[ @(UISwipeGestureRecognizerDirectionLeft), @(UISwipeGestureRecognizerDirectionRight) ]) {
      UISwipeGestureRecognizer *swipe = [[UISwipeGestureRecognizer alloc] initWithTarget:self action:@selector(swiped:)];
      swipe.direction = (UISwipeGestureRecognizerDirection)direction.unsignedIntegerValue;
      swipe.delegate = self;
      [self addGestureRecognizer:swipe];
    }
    [self updateContent];
    [self applyTheme];
  }
  return self;
}

- (NSString *)shownText {
  return _text;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
  return ![touch.view isKindOfClass:[UIControl class]];
}

- (void)tapped:(UITapGestureRecognizer *)tap {
  if (tap.state == UIGestureRecognizerStateEnded && self.onTap) {
    self.onTap();
  }
}

- (void)held:(UILongPressGestureRecognizer *)hold {
  if (hold.state == UIGestureRecognizerStateBegan && self.onLongPress) {
    self.onLongPress();
  }
}

- (void)swiped:(UISwipeGestureRecognizer *)swipe {
  if (swipe.state == UIGestureRecognizerStateEnded && self.onSwipe) {
    self.onSwipe(swipe.direction);
  }
}

- (void)setURLString:(NSString *)url {
  NSString *value = url ?: @"";
  _security = BKSecurityNone;
  if (value.length == 0 || [value isEqualToString:@"about:blank"]) {
    _blank = YES;
    _text = BKL(@"Search or enter address");
  } else {
    _blank = NO;
    NSURL *parsed = [NSURL URLWithString:value];
    NSString *scheme = parsed.scheme.lowercaseString;
    if (([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"http"]) && parsed.host.length) {
      _text = BKDisplayHost(parsed.host);
      _security = [scheme isEqualToString:@"https"] ? BKSecuritySecure : BKSecurityInsecure;
    } else {
      _text = value.length > 80 ? [[value substringToIndex:80] stringByAppendingString:@"…"] : value;
    }
  }
  self.accessibilityValue = _blank ? nil : _text;
  [self updateContent];
}

// The stock -reloadOrStop only ever reloads, so the button keeps the reload icon; it spins while a page is loading.
- (void)setLoading:(BOOL)loading {
  _loading = loading;
  _reloadButton.accessibilityLabel = BKL(@"Reload");
  CALayer *layer = _reloadButton.imageView.layer;
  if (loading) {
    if (![layer animationForKey:@"spin"]) {
      CABasicAnimation *spin = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
      spin.fromValue = @0;
      spin.toValue = @(2 * M_PI);
      spin.duration = 1.0;
      spin.repeatCount = HUGE_VALF;
      spin.removedOnCompletion = NO;
      [layer addAnimation:spin forKey:@"spin"];
    }
  } else {
    [layer removeAnimationForKey:@"spin"];
  }
}

- (void)updateContent {
  _label.text = _text;
  _label.textColor = _blank ? [BKTheme secondaryText] : [BKTheme primaryText];
  _label.font = [BKTheme font:16 weight:_blank ? UIFontWeightRegular : UIFontWeightMedium];
  _reloadButton.hidden = _blank;
  UIImage *icon = nil;
  UIColor *tint = [BKTheme secondaryText];
  if (_blank) {
    icon = [BKIcons image:BKIconSearch size:15];
  } else if (_security == BKSecuritySecure) {
    icon = [BKIcons image:BKIconLock size:13];
  } else if (_security == BKSecurityInsecure) {
    icon = [BKIcons image:BKIconWarning size:14];
    tint = [UIColor colorWithRed:1.0 green:0.62 blue:0.04 alpha:1.0];
  }
  _leadingIcon.image = icon;
  _leadingIcon.tintColor = tint;
  _leadingIcon.hidden = icon == nil;
  [self setNeedsLayout];
}

- (void)applyTheme {
  self.backgroundColor = [BKTheme pillBackground];
  [_reloadButton applyTheme];
  _reloadButton.tintColor = [BKTheme secondaryText];
  [self updateContent];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  const CGFloat height = self.bounds.size.height;
  const CGFloat width = self.bounds.size.width;
  self.layer.cornerRadius = height / 2;
  const CGFloat buttonWidth = MIN(height, 40);
  _reloadButton.frame = CGRectMake(width - buttonWidth - 2, 0, buttonWidth, height);
  const CGFloat left = 14;
  const CGFloat right = _reloadButton.hidden ? 14 : buttonWidth + 4;
  const CGFloat available = MAX(width - left - right, 20);
  const CGFloat iconSide = _leadingIcon.hidden ? 0 : 15;
  const CGFloat gap = _leadingIcon.hidden ? 0 : 6;
  CGFloat labelWidth = MIN([_label sizeThatFits:CGSizeMake(available, height)].width, available - iconSide - gap);
  CGFloat groupWidth = iconSide + gap + labelWidth;
  CGFloat x = left + (available - groupWidth) / 2;
  _leadingIcon.frame = CGRectMake(x, (height - iconSide) / 2, iconSide, iconSide);
  _label.frame = CGRectMake(x + iconSide + gap, 0, labelWidth, height);
}

@end

// -------------------------------------------------------------------------------------------------------------- bars

@implementation BKTopBar {
  UIView *_hairline;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    _hairline = [[UIView alloc] init];
    _hairline.userInteractionEnabled = NO;
    [self addSubview:_hairline];
    [self applyTheme];
  }
  return self;
}

- (void)applyTheme {
  self.backgroundColor = [BKTheme chromeBackground];
  _hairline.backgroundColor = [BKTheme separator];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  const UIEdgeInsets safe = self.safeAreaInsets;
  const CGFloat width = self.bounds.size.width;
  const CGFloat height = self.bounds.size.height;
  UIView *pill = self.pillView;
  if (pill.superview == self && _contentHeight > 0) {
    const CGFloat pillHeight = MIN(40, _contentHeight - 12);
    CGFloat x = MAX(12, safe.left + 8);
    CGFloat w = width - x - MAX(12, safe.right + 8);
    pill.frame = CGRectMake(x, safe.top + (_contentHeight - pillHeight) / 2, w, pillHeight);
  }
  _hairline.frame = CGRectMake(0, height - kHairline, width, kHairline);
  [self bringSubviewToFront:_hairline];
}

- (void)setContentHeight:(CGFloat)contentHeight {
  _contentHeight = contentHeight;
  [self setNeedsLayout];
}

@end

@implementation BKBottomBar {
  UIView *_hairline;
  NSArray<BKBarButton *> *_buttons;
}

- (instancetype)initWithFrame:(CGRect)frame {
  if ((self = [super initWithFrame:frame])) {
    _buttonsHeight = 49;
    _backButton = [[BKBarButton alloc] initWithIcon:BKIconBack iconSize:24];
    _forwardButton = [[BKBarButton alloc] initWithIcon:BKIconForward iconSize:24];
    _newTabButton = [[BKBarButton alloc] initWithIcon:BKIconPlus iconSize:24];
    _tabsButton = [[BKTabsButton alloc] initWithIcon:BKIconTabs iconSize:25];
    _menuButton = [[BKBarButton alloc] initWithIcon:BKIconMenu iconSize:24];
    _backButton.accessibilityLabel = BKL(@"Back");
    _forwardButton.accessibilityLabel = BKL(@"Forward");
    _newTabButton.accessibilityLabel = BKL(@"New Tab");
    _tabsButton.accessibilityLabel = BKL(@"Tabs");
    _menuButton.accessibilityLabel = BKL(@"Menu");
    _buttons = @[ _backButton, _forwardButton, _newTabButton, _tabsButton, _menuButton ];
    for (BKBarButton *button in _buttons) {
      [self addSubview:button];
    }
    // Nothing has loaded yet: both history buttons start disabled (the engine enables them).
    _backButton.enabled = NO;
    _forwardButton.enabled = NO;
    _hairline = [[UIView alloc] init];
    _hairline.userInteractionEnabled = NO;
    [self addSubview:_hairline];
    [self applyTheme];
  }
  return self;
}

- (void)applyTheme {
  self.backgroundColor = [BKTheme chromeBackground];
  _hairline.backgroundColor = [BKTheme separator];
  for (BKBarButton *button in _buttons) {
    [button applyTheme];
  }
}

- (void)setButtonsHeight:(CGFloat)buttonsHeight {
  _buttonsHeight = buttonsHeight;
  [self setNeedsLayout];
}

- (void)setPillRowHeight:(CGFloat)pillRowHeight {
  _pillRowHeight = pillRowHeight;
  [self setNeedsLayout];
}

- (void)layoutSubviews {
  [super layoutSubviews];
  const UIEdgeInsets safe = self.safeAreaInsets;
  const CGFloat width = self.bounds.size.width;
  CGFloat y = 0;
  UIView *pill = self.pillView;
  if (pill.superview == self && _pillRowHeight > 0) {
    const CGFloat pillHeight = MIN(40, _pillRowHeight - 12);
    CGFloat x = MAX(12, safe.left + 8);
    CGFloat w = width - x - MAX(12, safe.right + 8);
    pill.frame = CGRectMake(x, (_pillRowHeight - pillHeight) / 2 + 2, w, pillHeight);
    y = _pillRowHeight;
  }
  const CGFloat rowWidth = width - safe.left - safe.right;
  const CGFloat cell = rowWidth / (CGFloat)_buttons.count;
  for (NSUInteger i = 0; i < _buttons.count; i++) {
    _buttons[i].frame = CGRectMake(safe.left + cell * i, y, cell, _buttonsHeight);
  }
  _hairline.frame = CGRectMake(0, 0, width, kHairline);
  [self bringSubviewToFront:_hairline];
}

@end
