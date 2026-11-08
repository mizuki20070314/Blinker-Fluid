// SPDX-License-Identifier: GPL-3.0-or-later
#import "BKIcons.h"
#import "BKTheme.h"

#define BKP(x, y) CGPointMake((x), (y))

static UIBezierPath *BKPen(CGFloat width) {
  UIBezierPath *p = [UIBezierPath bezierPath];
  p.lineWidth = width;
  p.lineCapStyle = kCGLineCapRound;
  p.lineJoinStyle = kCGLineJoinRound;
  return p;
}

static void BKStrokeLine(CGFloat x1, CGFloat y1, CGFloat x2, CGFloat y2, CGFloat width) {
  UIBezierPath *p = BKPen(width);
  [p moveToPoint:BKP(x1, y1)];
  [p addLineToPoint:BKP(x2, y2)];
  [p stroke];
}

static void BKStrokePoly(const CGPoint *pts, int count, BOOL close, CGFloat width) {
  UIBezierPath *p = BKPen(width);
  [p moveToPoint:pts[0]];
  for (int i = 1; i < count; i++) {
    [p addLineToPoint:pts[i]];
  }
  if (close) {
    [p closePath];
  }
  [p stroke];
}

static void BKFillDot(CGFloat x, CGFloat y, CGFloat r) {
  [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(x - r, y - r, 2 * r, 2 * r)] fill];
}

static void BKStrokeCircle(CGFloat x, CGFloat y, CGFloat r, CGFloat width) {
  UIBezierPath *p = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(x - r, y - r, 2 * r, 2 * r)];
  p.lineWidth = width;
  [p stroke];
}

static UIBezierPath *BKGearPath(CGFloat cx, CGFloat cy, CGFloat outer, CGFloat inner, int teeth) {
  UIBezierPath *p = BKPen(1.8);
  CGFloat step = 2 * M_PI / teeth;
  CGFloat half = step * 0.5;
  for (int i = 0; i < teeth; i++) {
    CGFloat a = step * i - M_PI_2;
    CGFloat angles[4] = {a - half * 0.80, a - half * 0.42, a + half * 0.42, a + half * 0.80};
    CGFloat radii[4] = {inner, outer, outer, inner};
    for (int k = 0; k < 4; k++) {
      CGPoint pt = BKP(cx + radii[k] * cos(angles[k]), cy + radii[k] * sin(angles[k]));
      if (i == 0 && k == 0) {
        [p moveToPoint:pt];
      } else {
        [p addLineToPoint:pt];
      }
    }
  }
  [p closePath];
  return p;
}

static void BKDrawIcon(BKIcon icon, CGContextRef ctx) {
  const CGFloat w = 2.0;
  switch (icon) {
    case BKIconBack: {
      CGPoint pts[3] = {BKP(15, 4.6), BKP(7.6, 12), BKP(15, 19.4)};
      BKStrokePoly(pts, 3, NO, 2.3);
      break;
    }
    case BKIconForward: {
      CGPoint pts[3] = {BKP(9, 4.6), BKP(16.4, 12), BKP(9, 19.4)};
      BKStrokePoly(pts, 3, NO, 2.3);
      break;
    }
    case BKIconChevronRight: {
      CGPoint pts[3] = {BKP(9, 5), BKP(16, 12), BKP(9, 19)};
      BKStrokePoly(pts, 3, NO, 2.2);
      break;
    }
    case BKIconChevronDown: {
      CGPoint pts[3] = {BKP(5, 9), BKP(12, 16), BKP(19, 9)};
      BKStrokePoly(pts, 3, NO, 2.2);
      break;
    }
    case BKIconChevronUp: {
      CGPoint pts[3] = {BKP(5, 15), BKP(12, 8), BKP(19, 15)};
      BKStrokePoly(pts, 3, NO, 2.2);
      break;
    }
    case BKIconReload: {
      const CGFloat cx = 12, cy = 12, r = 7.3;
      const CGFloat end = 300.0 * M_PI / 180.0;
      UIBezierPath *arc = BKPen(w);
      [arc addArcWithCenter:BKP(cx, cy) radius:r startAngle:0.2 endAngle:end clockwise:YES];
      [arc stroke];
      // arrow head at the end of the arc, pointing along the travel direction
      CGPoint tip = BKP(cx + r * cos(end), cy + r * sin(end));
      CGPoint tangent = BKP(-sin(end), cos(end));
      CGPoint normal = BKP(cos(end), sin(end));
      CGPoint a = BKP(tip.x - tangent.x * 4.6 + normal.x * 3.7, tip.y - tangent.y * 4.6 + normal.y * 3.7);
      CGPoint b = BKP(tip.x - tangent.x * 4.6 - normal.x * 3.7, tip.y - tangent.y * 4.6 - normal.y * 3.7);
      CGPoint pts[3] = {a, BKP(tip.x + tangent.x * 0.6, tip.y + tangent.y * 0.6), b};
      BKStrokePoly(pts, 3, NO, w);
      break;
    }
    case BKIconStop:
    case BKIconCloseCircle: {
      if (icon == BKIconCloseCircle) {
        BKFillDot(12, 12, 9.6);
        CGContextSetBlendMode(ctx, kCGBlendModeClear);
        BKStrokeLine(8.4, 8.4, 15.6, 15.6, 2.2);
        BKStrokeLine(15.6, 8.4, 8.4, 15.6, 2.2);
        CGContextSetBlendMode(ctx, kCGBlendModeNormal);
      } else {
        BKStrokeLine(6.2, 6.2, 17.8, 17.8, 2.4);
        BKStrokeLine(17.8, 6.2, 6.2, 17.8, 2.4);
      }
      break;
    }
    case BKIconPlus: {
      BKStrokeLine(12, 4.8, 12, 19.2, 2.3);
      BKStrokeLine(4.8, 12, 19.2, 12, 2.3);
      break;
    }
    case BKIconTabs: {
      UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3.6, 3.6, 16.8, 16.8) cornerRadius:4.6];
      p.lineWidth = 2.0;
      [p stroke];
      break;
    }
    case BKIconMenu: {
      BKFillDot(4.8, 12, 2.0);
      BKFillDot(12, 12, 2.0);
      BKFillDot(19.2, 12, 2.0);
      break;
    }
    case BKIconLock: {
      [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(5.8, 10.6, 12.4, 10.2) cornerRadius:2.6] fill];
      UIBezierPath *shackle = BKPen(2.0);
      [shackle moveToPoint:BKP(8.8, 10.8)];
      [shackle addLineToPoint:BKP(8.8, 8.2)];
      [shackle addArcWithCenter:BKP(12, 8.2) radius:3.2 startAngle:M_PI endAngle:2 * M_PI clockwise:YES];
      [shackle addLineToPoint:BKP(15.2, 10.8)];
      [shackle stroke];
      break;
    }
    case BKIconWarning: {
      CGPoint pts[3] = {BKP(12, 4), BKP(21, 19.6), BKP(3, 19.6)};
      BKStrokePoly(pts, 3, YES, 2.0);
      BKStrokeLine(12, 10, 12, 14.4, 2.0);
      BKFillDot(12, 17.2, 1.1);
      break;
    }
    case BKIconSearch: {
      BKStrokeCircle(10.4, 10.4, 6.0, 2.2);
      BKStrokeLine(14.9, 14.9, 20, 20, 2.4);
      break;
    }
    case BKIconShare: {
      CGPoint box[6] = {BKP(8.6, 10.2), BKP(6.2, 10.2), BKP(6.2, 19.8), BKP(17.8, 19.8), BKP(17.8, 10.2), BKP(15.4, 10.2)};
      BKStrokePoly(box, 6, NO, 2.0);
      BKStrokeLine(12, 14.4, 12, 3.8, 2.0);
      CGPoint head[3] = {BKP(8.4, 7.2), BKP(12, 3.6), BKP(15.6, 7.2)};
      BKStrokePoly(head, 3, NO, 2.0);
      break;
    }
    case BKIconBookmark:
    case BKIconBookmarkFill: {
      UIBezierPath *p = BKPen(2.0);
      [p moveToPoint:BKP(7, 4.4)];
      [p addLineToPoint:BKP(17, 4.4)];
      [p addLineToPoint:BKP(17, 20)];
      [p addLineToPoint:BKP(12, 15.8)];
      [p addLineToPoint:BKP(7, 20)];
      [p closePath];
      if (icon == BKIconBookmarkFill) {
        [p fill];
      }
      [p stroke];
      break;
    }
    case BKIconStar: {
      UIBezierPath *p = BKPen(2.0);
      for (int i = 0; i < 10; i++) {
        CGFloat r = (i % 2 == 0) ? 8.8 : 3.8;
        CGFloat a = -M_PI_2 + i * M_PI / 5;
        CGPoint pt = BKP(12 + r * cos(a), 12.8 + r * sin(a));
        if (i == 0) {
          [p moveToPoint:pt];
        } else {
          [p addLineToPoint:pt];
        }
      }
      [p closePath];
      [p stroke];
      break;
    }
    case BKIconClock: {
      BKStrokeCircle(12, 12, 8.4, 2.0);
      CGPoint hands[3] = {BKP(12, 7), BKP(12, 12), BKP(15.6, 14.2)};
      BKStrokePoly(hands, 3, NO, 2.0);
      break;
    }
    case BKIconDownload: {
      BKStrokeCircle(12, 12, 8.6, 2.0);
      BKStrokeLine(12, 7.4, 12, 15.2, 2.0);
      CGPoint head[3] = {BKP(8.6, 12), BKP(12, 15.4), BKP(15.4, 12)};
      BKStrokePoly(head, 3, NO, 2.0);
      break;
    }
    case BKIconGear: {
      UIBezierPath *gear = BKGearPath(12, 12, 9.4, 7.0, 8);
      [gear stroke];
      BKStrokeCircle(12, 12, 2.9, 1.9);
      break;
    }
    case BKIconHouse: {
      CGPoint roof[3] = {BKP(3.4, 11.4), BKP(12, 4), BKP(20.6, 11.4)};
      BKStrokePoly(roof, 3, NO, 2.0);
      CGPoint body[4] = {BKP(6, 9.6), BKP(6, 20), BKP(18, 20), BKP(18, 9.6)};
      BKStrokePoly(body, 4, NO, 2.0);
      BKStrokeLine(10, 20, 10, 14.6, 2.0);
      BKStrokeLine(14, 20, 14, 14.6, 2.0);
      BKStrokeLine(10, 14.6, 14, 14.6, 2.0);
      break;
    }
    case BKIconPrivate: {
      BKStrokeLine(3.8, 13.2, 20.2, 13.2, 2.0);
      CGPoint crown[4] = {BKP(7, 13.2), BKP(8.6, 5.6), BKP(15.4, 5.6), BKP(17, 13.2)};
      BKStrokePoly(crown, 4, NO, 2.0);
      BKStrokeCircle(8.2, 17.8, 2.5, 1.9);
      BKStrokeCircle(15.8, 17.8, 2.5, 1.9);
      BKStrokeLine(10.7, 17.2, 13.3, 17.2, 1.9);
      break;
    }
    case BKIconDesktop: {
      UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3.4, 4.6, 17.2, 11.6) cornerRadius:2.2];
      p.lineWidth = 2.0;
      [p stroke];
      BKStrokeLine(12, 16.4, 12, 19.6, 2.0);
      BKStrokeLine(8, 19.8, 16, 19.8, 2.0);
      break;
    }
    case BKIconTextSize: {
      NSDictionary *small = @{NSFontAttributeName : [UIFont systemFontOfSize:11.5 weight:UIFontWeightSemibold], NSForegroundColorAttributeName : UIColor.blackColor};
      NSDictionary *big = @{NSFontAttributeName : [UIFont systemFontOfSize:19 weight:UIFontWeightSemibold], NSForegroundColorAttributeName : UIColor.blackColor};
      [@"a" drawAtPoint:BKP(3, 8.2) withAttributes:small];
      [@"A" drawAtPoint:BKP(9.3, 2.2) withAttributes:big];
      break;
    }
    case BKIconPerson: {
      BKStrokeCircle(12, 12, 9.2, 2.0);
      BKFillDot(12, 9.6, 3.0);
      UIBezierPath *shoulders = BKPen(2.0);
      [shoulders addArcWithCenter:BKP(12, 20.6) radius:7.2 startAngle:M_PI * 1.16 endAngle:M_PI * 1.84 clockwise:YES];
      [shoulders stroke];
      break;
    }
    case BKIconCheck: {
      CGPoint pts[3] = {BKP(5, 12.8), BKP(10, 17.6), BKP(19, 7)};
      BKStrokePoly(pts, 3, NO, 2.4);
      break;
    }
    case BKIconTrash: {
      BKStrokeLine(4.6, 7, 19.4, 7, 2.0);
      CGPoint handle[4] = {BKP(9.4, 7), BKP(9.4, 4.4), BKP(14.6, 4.4), BKP(14.6, 7)};
      BKStrokePoly(handle, 4, NO, 2.0);
      CGPoint body[4] = {BKP(6.6, 7), BKP(7.8, 20), BKP(16.2, 20), BKP(17.4, 7)};
      BKStrokePoly(body, 4, NO, 2.0);
      break;
    }
    case BKIconGlobe: {
      BKStrokeCircle(12, 12, 8.6, 2.0);
      UIBezierPath *meridian = [UIBezierPath bezierPathWithOvalInRect:CGRectMake(8.2, 3.4, 7.6, 17.2)];
      meridian.lineWidth = 1.8;
      [meridian stroke];
      BKStrokeLine(3.5, 12, 20.5, 12, 1.8);
      break;
    }
    case BKIconArrowUpRight: {
      BKStrokeLine(7.2, 16.8, 16.8, 7.2, 2.2);
      CGPoint head[3] = {BKP(8.8, 7.2), BKP(16.8, 7.2), BKP(16.8, 15.2)};
      BKStrokePoly(head, 3, NO, 2.2);
      break;
    }
    case BKIconPaste: {
      UIBezierPath *board = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(5.4, 5.6, 13.2, 15.2) cornerRadius:2.6];
      board.lineWidth = 2.0;
      [board stroke];
      UIBezierPath *clip = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(9, 3.2, 6, 4.6) cornerRadius:1.6];
      clip.lineWidth = 1.9;
      [clip stroke];
      break;
    }
    case BKIconInfo: {
      BKStrokeCircle(12, 12, 8.8, 2.0);
      BKFillDot(12, 7.8, 1.25);
      BKStrokeLine(12, 11, 12, 16.6, 2.1);
      break;
    }
    case BKIconShield: {
      UIBezierPath *p = BKPen(2.0);
      [p moveToPoint:BKP(12, 3.2)];
      [p addLineToPoint:BKP(19.2, 5.9)];
      [p addLineToPoint:BKP(19.2, 11.4)];
      [p addCurveToPoint:BKP(12, 20.8) controlPoint1:BKP(19.2, 16.2) controlPoint2:BKP(15.6, 19.3)];
      [p addCurveToPoint:BKP(4.8, 11.4) controlPoint1:BKP(8.4, 19.3) controlPoint2:BKP(4.8, 16.2)];
      [p addLineToPoint:BKP(4.8, 5.9)];
      [p closePath];
      [p stroke];
      CGPoint check[3] = {BKP(8.6, 11.8), BKP(11, 14.2), BKP(15.6, 9.4)};
      BKStrokePoly(check, 3, NO, 1.9);
      break;
    }
    case BKIconBolt: {
      UIBezierPath *p = BKPen(1.6);
      [p moveToPoint:BKP(13.2, 2.8)];
      [p addLineToPoint:BKP(5.6, 13.4)];
      [p addLineToPoint:BKP(11.2, 13.4)];
      [p addLineToPoint:BKP(10.4, 21.2)];
      [p addLineToPoint:BKP(18.4, 10.2)];
      [p addLineToPoint:BKP(12.6, 10.2)];
      [p closePath];
      [p fill];
      [p stroke];
      break;
    }
    case BKIconCode: {
      CGPoint left[3] = {BKP(8, 7.2), BKP(3.2, 12), BKP(8, 16.8)};
      BKStrokePoly(left, 3, NO, 2.0);
      CGPoint right[3] = {BKP(16, 7.2), BKP(20.8, 12), BKP(16, 16.8)};
      BKStrokePoly(right, 3, NO, 2.0);
      BKStrokeLine(13.6, 5.2, 10.4, 18.8, 2.0);
      break;
    }
    case BKIconCamera: {
      UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 7, 18, 12.4) cornerRadius:3];
      body.lineWidth = 2.0;
      [body stroke];
      BKStrokeCircle(12, 13.2, 3.3, 2.0);
      CGPoint bump[4] = {BKP(8.4, 7), BKP(9.6, 4.8), BKP(14.4, 4.8), BKP(15.6, 7)};
      BKStrokePoly(bump, 4, NO, 2.0);
      break;
    }
    case BKIconMic: {
      UIBezierPath *capsule = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(9, 3.4, 6, 11.4) cornerRadius:3];
      capsule.lineWidth = 2.0;
      [capsule stroke];
      UIBezierPath *arc = BKPen(2.0);
      [arc addArcWithCenter:BKP(12, 11.2) radius:6.4 startAngle:0 endAngle:M_PI clockwise:YES];
      [arc stroke];
      BKStrokeLine(12, 17.6, 12, 20.6, 2.0);
      BKStrokeLine(8.6, 20.6, 15.4, 20.6, 2.0);
      break;
    }
    case BKIconLocation: {
      UIBezierPath *p = BKPen(2.0);
      [p moveToPoint:BKP(4, 11.2)];
      [p addLineToPoint:BKP(20, 4)];
      [p addLineToPoint:BKP(12.8, 20)];
      [p addLineToPoint:BKP(11.2, 12.8)];
      [p closePath];
      [p stroke];
      break;
    }
    case BKIconFolder: {
      [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 8, 18, 11.8) cornerRadius:2.6] fill];
      [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 4.8, 9, 6) cornerRadius:1.8] fill];
      break;
    }
    case BKIconHalfCircle: {
      BKStrokeCircle(12, 12, 8.6, 2.0);
      UIBezierPath *half = [UIBezierPath bezierPath];
      [half addArcWithCenter:BKP(12, 12) radius:8.6 startAngle:M_PI_2 endAngle:3 * M_PI_2 clockwise:YES];
      [half closePath];
      [half fill];
      break;
    }
    case BKIconToolbarPosition: {
      UIBezierPath *frame = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 3.6, 16, 16.8) cornerRadius:3.4];
      frame.lineWidth = 2.0;
      [frame stroke];
      CGContextSaveGState(ctx);
      [frame addClip];
      CGContextFillRect(ctx, CGRectMake(3, 14.6, 18, 7));
      CGContextRestoreGState(ctx);
      break;
    }
    case BKIconExit: {
      CGPoint door[4] = {BKP(11, 4), BKP(5, 4), BKP(5, 20), BKP(11, 20)};
      BKStrokePoly(door, 4, NO, 2.0);
      BKStrokeLine(9.6, 12, 20, 12, 2.0);
      CGPoint head[3] = {BKP(16.4, 8.4), BKP(20, 12), BKP(16.4, 15.6)};
      BKStrokePoly(head, 3, NO, 2.0);
      break;
    }
    case BKIconCompass: {
      BKStrokeCircle(12, 12, 8.8, 2.0);
      UIBezierPath *needle = BKPen(1.4);
      [needle moveToPoint:BKP(15.8, 8.2)];
      [needle addLineToPoint:BKP(13.2, 13.2)];
      [needle addLineToPoint:BKP(8.2, 15.8)];
      [needle addLineToPoint:BKP(10.8, 10.8)];
      [needle closePath];
      [needle fill];
      [needle stroke];
      break;
    }
    case BKIconHand: {
      UIBezierPath *palm = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(7, 10.4, 11, 10.4) cornerRadius:3.2];
      palm.lineWidth = 2.0;
      [palm stroke];
      BKStrokeLine(9.2, 10.4, 9.2, 5.8, 2.0);
      BKStrokeLine(12, 10.4, 12, 3.8, 2.0);
      BKStrokeLine(14.8, 10.4, 14.8, 4.6, 2.0);
      BKStrokeLine(17.4, 10.4, 17.4, 7.2, 2.0);
      BKStrokeLine(7.2, 14.6, 4.8, 12, 2.0);
      break;
    }
    case BKIconCount:
      break;
  }
}

@implementation BKIcons

+ (UIImage *)image:(BKIcon)icon size:(CGFloat)size {
  static NSCache<NSString *, UIImage *> *cache;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    cache = [[NSCache alloc] init];
    cache.countLimit = 160;
  });
  NSString *key = [NSString stringWithFormat:@"%ld@%.1f@%.0f", (long)icon, size, UIScreen.mainScreen.scale];
  UIImage *cached = [cache objectForKey:key];
  if (cached) {
    return cached;
  }
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
  format.opaque = NO;
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size) format:format];
  UIImage *image = [renderer imageWithActions:^(UIGraphicsImageRendererContext *rc) {
    CGContextRef ctx = rc.CGContext;
    CGContextScaleCTM(ctx, size / 24.0, size / 24.0);
    [UIColor.blackColor set];
    BKDrawIcon(icon, ctx);
  }];
  image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  [cache setObject:image forKey:key];
  return image;
}

+ (UIImage *)tileWithIcon:(BKIcon)icon size:(CGFloat)size color:(UIColor *)color {
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
  format.opaque = NO;
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:CGSizeMake(size, size) format:format];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *rc) {
    CGContextRef ctx = rc.CGContext;
    [color setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, size, size) cornerRadius:size * 0.25] fill];
    CGFloat glyph = size * 0.62;
    CGContextTranslateCTM(ctx, (size - glyph) / 2, (size - glyph) / 2);
    CGContextScaleCTM(ctx, glyph / 24.0, glyph / 24.0);
    [UIColor.whiteColor set];
    BKDrawIcon(icon, ctx);
  }];
}

+ (BKIcon)iconForSymbolName:(NSString *)name found:(BOOL *)found {
  static NSDictionary<NSString *, NSNumber *> *map;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    map = @{
      @"arrow.clockwise" : @(BKIconReload),
      @"arrow.triangle.2.circlepath" : @(BKIconReload),
      @"arrow.down.circle" : @(BKIconDownload),
      @"bolt.fill" : @(BKIconBolt),
      @"bookmark" : @(BKIconBookmark),
      @"camera" : @(BKIconCamera),
      @"checkmark.shield" : @(BKIconShield),
      @"chevron.down" : @(BKIconChevronDown),
      @"chevron.up" : @(BKIconChevronUp),
      @"chevron.left" : @(BKIconBack),
      @"chevron.left.forwardslash.chevron.right" : @(BKIconCode),
      @"circle.lefthalf.filled" : @(BKIconHalfCircle),
      @"clock.arrow.circlepath" : @(BKIconClock),
      @"desktopcomputer" : @(BKIconDesktop),
      @"eye.slash" : @(BKIconPrivate),
      @"folder.fill" : @(BKIconFolder),
      @"gear" : @(BKIconGear),
      @"gearshape" : @(BKIconGear),
      @"globe" : @(BKIconGlobe),
      @"hand.raised" : @(BKIconHand),
      @"hand.raised.slash" : @(BKIconHand),
      @"heart.circle" : @(BKIconShield),
      @"house" : @(BKIconHouse),
      @"info.circle" : @(BKIconInfo),
      @"location" : @(BKIconLocation),
      @"lock.fill" : @(BKIconLock),
      @"lock.shield" : @(BKIconShield),
      @"lock.shield.fill" : @(BKIconShield),
      @"magnifyingglass" : @(BKIconSearch),
      @"mic" : @(BKIconMic),
      @"person.badge.plus" : @(BKIconPerson),
      @"person.crop.circle" : @(BKIconPerson),
      @"person.crop.circle.badge.plus" : @(BKIconPerson),
      @"plus" : @(BKIconPlus),
      @"rectangle.bottomthird.inset.filled" : @(BKIconToolbarPosition),
      @"rectangle.portrait.and.arrow.right" : @(BKIconExit),
      @"safari" : @(BKIconCompass),
      @"square.and.arrow.up" : @(BKIconShare),
      @"square.on.square" : @(BKIconTabs),
      @"textformat.size" : @(BKIconTextSize),
      @"trash" : @(BKIconTrash),
      @"xmark.circle.fill" : @(BKIconCloseCircle),
    };
  });
  NSNumber *value = map[name];
  if (found) {
    *found = value != nil;
  }
  return value ? (BKIcon)value.integerValue : BKIconInfo;
}

+ (UIImage *)imageForSymbolName:(NSString *)name size:(CGFloat)size {
  BOOL found = NO;
  BKIcon icon = [self iconForSymbolName:name found:&found];
  return found ? [self image:icon size:size] : nil;
}

@end
