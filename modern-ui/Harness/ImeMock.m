// A stand-in for the engine's RenderWidgetUIView text-input surface: the same selectors and signatures as the released binary and
// the same (limited) behaviour of the stock implementation - in particular -markedTextRange always answers nil.
#import <UIKit/UIKit.h>

@interface MockTextPosition : UITextPosition
@property(nonatomic) CGRect rect;
@end
@implementation MockTextPosition
@end

@interface MockTextRange : UITextRange
@property(nonatomic, strong) MockTextPosition *from;
@property(nonatomic, strong) MockTextPosition *to;
@end
@implementation MockTextRange
- (UITextPosition *)start {
  return self.from;
}
- (UITextPosition *)end {
  return self.to;
}
- (BOOL)isEmpty {
  return CGRectEqualToRect(self.from.rect, self.to.rect);
}
@end

@interface RenderWidgetUIView : UIView
@end

@implementation RenderWidgetUIView {
  NSString *_marked;
}

- (UITextRange *)markedTextRange {
  return nil;  // as in the engine
}
- (BOOL)hasMarkedText {
  return _marked.length > 0;
}
- (NSString *)markedText {
  return _marked.length ? _marked : nil;
}
- (UITextRange *)selectedTextRange {
  MockTextRange *range = [[MockTextRange alloc] init];
  range.from = [[MockTextPosition alloc] init];
  range.from.rect = CGRectMake(100, 50, 1, 20);
  range.to = [[MockTextPosition alloc] init];
  range.to.rect = CGRectMake(100, 50, 1, 20);
  return range;
}
- (NSString *)textInRange:(UITextRange *)range {
  return nil;
}
- (NSInteger)offsetFromPosition:(UITextPosition *)from toPosition:(UITextPosition *)to {
  return 0;
}
- (UITextPosition *)positionFromPosition:(UITextPosition *)position offset:(NSInteger)offset {
  return position;
}
- (NSComparisonResult)comparePosition:(UITextPosition *)position toPosition:(UITextPosition *)other {
  return NSOrderedSame;
}
- (CGRect)caretRectForPosition:(UITextPosition *)position {
  return [position isKindOfClass:[MockTextPosition class]] ? ((MockTextPosition *)position).rect : CGRectNull;
}
- (CGRect)firstRectForRange:(UITextRange *)range {
  return CGRectNull;
}
- (UITextRange *)textRangeFromPosition:(UITextPosition *)from toPosition:(UITextPosition *)to {
  if ([from isKindOfClass:[MockTextPosition class]] && [to isKindOfClass:[MockTextPosition class]]) {
    MockTextRange *range = [[MockTextRange alloc] init];
    range.from = (MockTextPosition *)from;
    range.to = (MockTextPosition *)to;
    return range;
  }
  return nil;
}
- (void)setMarkedText:(NSString *)markedText selectedRange:(NSRange)selectedRange {
  _marked = [markedText copy];
}
- (void)unmarkText {
  _marked = nil;
}
- (void)insertText:(NSString *)text {
  _marked = nil;
}
- (void)replaceRange:(UITextRange *)range withText:(NSString *)text {
  _marked = nil;
}
@end
