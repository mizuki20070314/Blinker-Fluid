// SPDX-License-Identifier: GPL-3.0-or-later
#import "BKIME.h"
#import "BKCore.h"
#import <objc/message.h>
#import <objc/runtime.h>

// ----------------------------------------------------------------------------------------------------- the contract

typedef struct {
  const char *cls;
  const char *sel;
  const char *shape;
} BKIMERequirement;

static const BKIMERequirement kIMERequirements[] = {
#define BK_METHOD(c, s, sh) {c, s, sh},
#include "BKContractIME.inc"
#undef BK_METHOD
};

static NSString *BKIMEShape(const char *types) {
  NSMutableString *shape = [NSMutableString string];
  for (const char *p = types; p && *p; p++) {
    if (!(*p >= '0' && *p <= '9')) {
      [shape appendFormat:@"%c", *p];
    }
  }
  return shape;
}

static BOOL BKIMEContractHolds(void) {
  BOOL ok = YES;
  for (size_t i = 0; i < sizeof(kIMERequirements) / sizeof(kIMERequirements[0]); i++) {
    const BKIMERequirement *r = &kIMERequirements[i];
    Class cls = objc_getClass(r->cls);
    Method m = cls ? class_getInstanceMethod(cls, sel_registerName(r->sel)) : NULL;
    if (!m) {
      BKLog(@"ime: -[%s %s] is missing", r->cls, r->sel);
      ok = NO;
    } else if (![BKIMEShape(method_getTypeEncoding(m)) isEqualToString:@(r->shape)]) {
      BKLog(@"ime: -[%s %s] is %@, expected %s", r->cls, r->sel, BKIMEShape(method_getTypeEncoding(m)), r->shape);
      ok = NO;
    }
  }
  return ok;
}

// ---------------------------------------------------------------------------------------- positions inside the composition

// The composition ("marked text") is the only text UIKit needs positions for here, so its positions are plain offsets 0...length.
@interface BKMarkedPosition : UITextPosition
@property(nonatomic, readonly) NSInteger offset;
- (instancetype)initWithOffset:(NSInteger)offset;
@end

@implementation BKMarkedPosition
- (instancetype)initWithOffset:(NSInteger)offset {
  if ((self = [super init])) {
    _offset = offset;
  }
  return self;
}
@end

@interface BKMarkedRange : UITextRange
- (instancetype)initWithStart:(NSInteger)start end:(NSInteger)end;
@end

@implementation BKMarkedRange {
  BKMarkedPosition *_start;
  BKMarkedPosition *_end;
}
- (instancetype)initWithStart:(NSInteger)start end:(NSInteger)end {
  if ((self = [super init])) {
    _start = [[BKMarkedPosition alloc] initWithOffset:start];
    _end = [[BKMarkedPosition alloc] initWithOffset:end];
  }
  return self;
}
- (UITextPosition *)start {
  return _start;
}
- (UITextPosition *)end {
  return _end;
}
- (BOOL)isEmpty {
  return _start.offset == _end.offset;
}
@end

@protocol BKIMEView <NSObject>
- (BOOL)hasMarkedText;
- (NSString *)markedText;
- (UITextRange *)selectedTextRange;
@end

// ------------------------------------------------------------------------------------------------------------- tracing

// A few lines (lengths only, never the text) about what UIKit asks during a composition, so a log can show what the keyboard does.
static int gTraceBudget = 160;

static void BKIMETrace(NSString *format, ...) NS_FORMAT_FUNCTION(1, 2);
static void BKIMETrace(NSString *format, ...) {
  if (gTraceBudget <= 0) {
    return;
  }
  gTraceBudget--;
  va_list args;
  va_start(args, format);
  NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);
  BKLog(@"ime: %@", message);
}

// ------------------------------------------------------------------------------------------------------------- the hooks

static id (*orig_markedTextRange)(id, SEL);
static NSString *(*orig_textInRange)(id, SEL, UITextRange *);
static NSInteger (*orig_offsetFromPosition)(id, SEL, UITextPosition *, UITextPosition *);
static UITextPosition *(*orig_positionFromPositionOffset)(id, SEL, UITextPosition *, NSInteger);
static NSInteger (*orig_comparePosition)(id, SEL, UITextPosition *, UITextPosition *);
static CGRect (*orig_caretRectForPosition)(id, SEL, UITextPosition *);
static CGRect (*orig_firstRectForRange)(id, SEL, UITextRange *);
static UITextRange *(*orig_textRangeFromPosition)(id, SEL, UITextPosition *, UITextPosition *);
static void (*orig_setMarkedText)(id, SEL, NSString *, NSRange);
static void (*orig_unmarkText)(id, SEL);
static void (*orig_insertText)(id, SEL, NSString *);
static void (*orig_replaceRange)(id, SEL, UITextRange *, NSString *);

static NSInteger gLastMarkedLength = -1;

static id hook_markedTextRange(id self, SEL _cmd) {
  id original = orig_markedTextRange(self, _cmd);
  if (original) {
    return original;  // (a future engine build that answers it itself)
  }
  id<BKIMEView> view = self;
  if (![view hasMarkedText]) {
    if (gLastMarkedLength != 0) {
      gLastMarkedLength = 0;
      BKIMETrace(@"markedTextRange -> nil");
    }
    return nil;
  }
  NSInteger length = (NSInteger)[view markedText].length;
  if (length <= 0) {
    return nil;
  }
  if (length != gLastMarkedLength) {
    gLastMarkedLength = length;
    BKIMETrace(@"markedTextRange -> composition of %ld", (long)length);
  }
  return [[BKMarkedRange alloc] initWithStart:0 end:length];
}

static NSString *hook_textInRange(id self, SEL _cmd, UITextRange *range) {
  if ([range isKindOfClass:[BKMarkedRange class]]) {
    NSString *marked = [(id<BKIMEView>)self markedText] ?: @"";
    NSInteger a = ((BKMarkedPosition *)range.start).offset, b = ((BKMarkedPosition *)range.end).offset;
    a = MAX(0, MIN(a, (NSInteger)marked.length));
    b = MAX(a, MIN(b, (NSInteger)marked.length));
    return [marked substringWithRange:NSMakeRange((NSUInteger)a, (NSUInteger)(b - a))];
  }
  return orig_textInRange(self, _cmd, range);
}

static NSInteger hook_offsetFromPosition(id self, SEL _cmd, UITextPosition *from, UITextPosition *to) {
  if ([from isKindOfClass:[BKMarkedPosition class]] && [to isKindOfClass:[BKMarkedPosition class]]) {
    return ((BKMarkedPosition *)to).offset - ((BKMarkedPosition *)from).offset;
  }
  return orig_offsetFromPosition(self, _cmd, from, to);
}

static UITextPosition *hook_positionFromPositionOffset(id self, SEL _cmd, UITextPosition *position, NSInteger offset) {
  if ([position isKindOfClass:[BKMarkedPosition class]]) {
    NSInteger length = (NSInteger)[(id<BKIMEView>)self markedText].length;
    NSInteger target = MAX(0, MIN(((BKMarkedPosition *)position).offset + offset, length));
    return [[BKMarkedPosition alloc] initWithOffset:target];
  }
  return orig_positionFromPositionOffset(self, _cmd, position, offset);
}

static NSInteger hook_comparePosition(id self, SEL _cmd, UITextPosition *a, UITextPosition *b) {
  if ([a isKindOfClass:[BKMarkedPosition class]] && [b isKindOfClass:[BKMarkedPosition class]]) {
    NSInteger x = ((BKMarkedPosition *)a).offset, y = ((BKMarkedPosition *)b).offset;
    return x < y ? NSOrderedAscending : (x > y ? NSOrderedDescending : NSOrderedSame);
  }
  return orig_comparePosition(self, _cmd, a, b);
}

// Where the composition is on screen = where the caret is (the engine keeps the caret at the end of the composition).
static CGRect BKCaretRect(id self, SEL _cmd) {
  UITextRange *selection = [(id<BKIMEView>)self selectedTextRange];
  UITextPosition *caret = selection.end;
  return caret ? orig_caretRectForPosition(self, _cmd, caret) : CGRectNull;
}

static CGRect hook_caretRectForPosition(id self, SEL _cmd, UITextPosition *position) {
  if ([position isKindOfClass:[BKMarkedPosition class]]) {
    return BKCaretRect(self, _cmd);
  }
  return orig_caretRectForPosition(self, _cmd, position);
}

static CGRect hook_firstRectForRange(id self, SEL _cmd, UITextRange *range) {
  if ([range isKindOfClass:[BKMarkedRange class]]) {
    return BKCaretRect(self, @selector(caretRectForPosition:));
  }
  return orig_firstRectForRange(self, _cmd, range);
}

static UITextRange *hook_textRangeFromPosition(id self, SEL _cmd, UITextPosition *from, UITextPosition *to) {
  if ([from isKindOfClass:[BKMarkedPosition class]] && [to isKindOfClass:[BKMarkedPosition class]]) {
    NSInteger a = ((BKMarkedPosition *)from).offset, b = ((BKMarkedPosition *)to).offset;
    return [[BKMarkedRange alloc] initWithStart:MIN(a, b) end:MAX(a, b)];
  }
  return orig_textRangeFromPosition(self, _cmd, from, to);
}

// ---- pass-through hooks that only note what happens

static void hook_setMarkedText(id self, SEL _cmd, NSString *text, NSRange selected) {
  BKIMETrace(@"setMarkedText length=%lu selection=%lu+%lu", (unsigned long)text.length, (unsigned long)selected.location, (unsigned long)selected.length);
  orig_setMarkedText(self, _cmd, text, selected);
}

static void hook_unmarkText(id self, SEL _cmd) {
  BKIMETrace(@"unmarkText (confirm) hasMarkedText=%d", [(id<BKIMEView>)self hasMarkedText] ? 1 : 0);
  orig_unmarkText(self, _cmd);
  gLastMarkedLength = 0;
}

static void hook_insertText(id self, SEL _cmd, NSString *text) {
  BKIMETrace(@"insertText length=%lu%@ (hasMarkedText=%d)", (unsigned long)text.length, [text isEqualToString:@"\n"] ? @" [return key]" : @"",
             [(id<BKIMEView>)self hasMarkedText] ? 1 : 0);
  orig_insertText(self, _cmd, text);
  gLastMarkedLength = 0;
}

static void hook_replaceRange(id self, SEL _cmd, UITextRange *range, NSString *text) {
  BKIMETrace(@"replaceRange (%@) length=%lu", [range isKindOfClass:[BKMarkedRange class]] ? @"composition" : @"other", (unsigned long)text.length);
  orig_replaceRange(self, _cmd, range, text);
  gLastMarkedLength = 0;
}

void BKInstallIMEHooks(void) {
  if ([[NSFileManager defaultManager] fileExistsAtPath:[BKDocumentsPath() stringByAppendingPathComponent:@"disable-ime-fix"]]) {
    BKLog(@"ime: Documents/disable-ime-fix exists - the engine's own input handling stays as it is");
    return;
  }
  if (!BKIMEContractHolds()) {
    BKLog(@"ime: the engine's text view does not match - no input-method fix");
    return;
  }
  Class cls = objc_getClass("RenderWidgetUIView");
  int installed = 0, total = 0;
#define BK_IME_HOOK(selector, shape, fn, orig)                                              \
  do {                                                                                      \
    total++;                                                                                \
    if (BKHookInstance(cls, NSSelectorFromString(selector), shape, (IMP)fn, (IMP *)&orig)) { \
      installed++;                                                                          \
    }                                                                                       \
  } while (0)
  BK_IME_HOOK(@"markedTextRange", "@@:", hook_markedTextRange, orig_markedTextRange);
  BK_IME_HOOK(@"textInRange:", "@@:@", hook_textInRange, orig_textInRange);
  BK_IME_HOOK(@"offsetFromPosition:toPosition:", "q@:@@", hook_offsetFromPosition, orig_offsetFromPosition);
  BK_IME_HOOK(@"positionFromPosition:offset:", "@@:@q", hook_positionFromPositionOffset, orig_positionFromPositionOffset);
  BK_IME_HOOK(@"comparePosition:toPosition:", "q@:@@", hook_comparePosition, orig_comparePosition);
  BK_IME_HOOK(@"caretRectForPosition:", "{CGRect={CGPoint=dd}{CGSize=dd}}@:@", hook_caretRectForPosition, orig_caretRectForPosition);
  BK_IME_HOOK(@"firstRectForRange:", "{CGRect={CGPoint=dd}{CGSize=dd}}@:@", hook_firstRectForRange, orig_firstRectForRange);
  BK_IME_HOOK(@"textRangeFromPosition:toPosition:", "@@:@@", hook_textRangeFromPosition, orig_textRangeFromPosition);
  BK_IME_HOOK(@"setMarkedText:selectedRange:", "v@:@{_NSRange=QQ}", hook_setMarkedText, orig_setMarkedText);
  BK_IME_HOOK(@"unmarkText", "v@:", hook_unmarkText, orig_unmarkText);
  BK_IME_HOOK(@"insertText:", "v@:@", hook_insertText, orig_insertText);
  BK_IME_HOOK(@"replaceRange:withText:", "v@:@@", hook_replaceRange, orig_replaceRange);
#undef BK_IME_HOOK
  BKLog(@"ime: %d of %d hooks installed on RenderWidgetUIView (the composition is now reported to the keyboard)", installed, total);
}
