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

// What the Return-key fix needs (a separate list: if it differs, only that fix stays off).
static const BKIMERequirement kReturnKeyRequirements[] = {
#define BK_METHOD(c, s, sh) {c, s, sh},
#include "BKContractReturnKey.inc"
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

static BOOL BKIMEContractHolds(const BKIMERequirement *list, size_t count) {
  BOOL ok = YES;
  for (size_t i = 0; i < count; i++) {
    const BKIMERequirement *r = &list[i];
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

// ------------------------------------------------------------------------------------------------------------ the Return key
//
// The software keyboard reports the Return key as the text "\n" (-insertText:), never as a key press.  The engine turns that into
// "commit the text \n": a text area gets a line break, but the page never sees an Enter key - no keydown / keypress (so a search box,
// a chat field or anything else that waits for Enter does nothing) and a one-line field is not submitted.
//
// A hardware keyboard (iOS 17.4+) goes through -handleKeyEntry:withCompletionHandler: instead.  That method builds a real key event
// from a BrowserEngineKit key entry and sends it to the page, as keydown + keypress (or keyup).  BrowserEngineKit does not exist
// below iOS 17.4, but the method only reads a few properties of its argument - state, timestamp and key.keyCode / .characters /
// .modifierFlags (components/input/web_input_event_builders_ios.mm) - and has no system text-input delegate to ask on iOS 12
// (-asyncInputDelegate is nil), so it sends the key itself.  The Return key is therefore handed to it as a small stand-in with
// those properties: the page gets Enter exactly as it would from a hardware keyboard.

BOOL BKIMEAssumeLegacySystem = NO;
NSTimeInterval BKIMEReturnKeyHealthyDelay = 3.0;

// Stand-ins for UIKey / BEKeyEntry (UIKey needs iOS 13.4, BEKeyEntry 17.4).  Only what the engine reads is provided.
@interface BKStandInKey : NSObject
@property(nonatomic, readonly) NSInteger keyCode;
@property(nonatomic, readonly, copy) NSString *characters;
@property(nonatomic, readonly, copy) NSString *charactersIgnoringModifiers;
@property(nonatomic, readonly) NSInteger modifierFlags;
@end

@implementation BKStandInKey
- (instancetype)init {
  if ((self = [super init])) {
    // The engine reads key.keyCode as a Windows virtual-key code (VKEY_RETURN = 13), not as a HID usage.
    _keyCode = 13;
    _characters = @"\r";
    _charactersIgnoringModifiers = @"\r";
    _modifierFlags = 0;
  }
  return self;
}
@end

@interface BKStandInKeyEntry : NSObject
@property(nonatomic, readonly, strong) BKStandInKey *key;
@property(nonatomic, readonly) NSInteger state;  // BEKeyPressState: Down = 1, Up = 2 (BrowserEngineKit/BEKeyEntry.h, checked in CI)
@property(nonatomic, readonly, getter=isKeyRepeating) BOOL keyRepeating;
@property(nonatomic, readonly) NSTimeInterval timestamp;
- (instancetype)initWithState:(NSInteger)state timestamp:(NSTimeInterval)timestamp;
@end

@implementation BKStandInKeyEntry
- (instancetype)initWithState:(NSInteger)state timestamp:(NSTimeInterval)timestamp {
  if ((self = [super init])) {
    _key = [[BKStandInKey alloc] init];
    _state = state;
    _keyRepeating = NO;
    _timestamp = timestamp;
  }
  return self;
}
@end

static const NSInteger kKeyPressStateDown = 1;
static const NSInteger kKeyPressStateUp = 2;

static BOOL gReturnKeyFix = NO;       // installed and not switched off
static NSInteger gReturnKeysInFlight = 0;

static NSString *BKReturnKeyFile(NSString *name) {
  return [BKSupportPath() stringByAppendingPathComponent:name];
}

// A crash while the engine handles the stand-in must never repeat on every Return key press: a marker file is written before the key
// is sent and removed a few seconds later, when the app is still alive.  A marker found at launch is one strike (the app may also just
// have been closed in those seconds), two strikes in a row switch the fix off for good (Documents/disable-return-fix).
void BKIMEReturnKeyCheckLastLaunch(void) {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *marker = BKReturnKeyFile(@"return-key.pending"), *strikes = BKReturnKeyFile(@"return-key.strikes");
  if (![fm fileExistsAtPath:marker]) {
    return;
  }
  [fm removeItemAtPath:marker error:nil];
  NSInteger count = [[NSString stringWithContentsOfFile:strikes encoding:NSUTF8StringEncoding error:nil] integerValue] + 1;
  [[NSString stringWithFormat:@"%ld", (long)count] writeToFile:strikes atomically:YES encoding:NSUTF8StringEncoding error:nil];
  BKLog(@"ime: the app ended while a Return key press was being handled (strike %ld)", (long)count);
  if (count >= 2) {
    [@"The Return key fix is off because the app ended twice right after a Return key press. Delete this file to try it again.\n"
        writeToFile:[BKDocumentsPath() stringByAppendingPathComponent:@"disable-return-fix"]
         atomically:YES
           encoding:NSUTF8StringEncoding
              error:nil];
    [fm removeItemAtPath:strikes error:nil];
    BKLog(@"ime: Documents/disable-return-fix written - the Return key fix stays off");
  }
}

BOOL BKIMEReturnKeyEnabled(void) {
  return gReturnKeyFix;
}

// The press was handled without the app ending: forget the marker and any earlier strike.
static void BKIMEReturnKeySurvived(void) {
  gReturnKeysInFlight = 0;
  NSFileManager *manager = [NSFileManager defaultManager];
  [manager removeItemAtPath:BKReturnKeyFile(@"return-key.pending") error:nil];
  [manager removeItemAtPath:BKReturnKeyFile(@"return-key.strikes") error:nil];
}

// Only where the system has no BrowserEngineKit key path of its own: with a text-input delegate (iOS 17.4+) -handleKeyEntry: would
// hand the stand-in to real BrowserEngineKit objects.
static BOOL BKIMEReturnKeyApplies(id view) {
  if (!gReturnKeyFix) {
    return NO;
  }
  id (*delegate)(id, SEL) = (id (*)(id, SEL))objc_msgSend;
  if (delegate(view, sel_registerName("asyncInputDelegate")) != nil) {
    return NO;
  }
  if (BKIMEAssumeLegacySystem) {
    return YES;
  }
  return NSClassFromString(@"BEKeyEntryContext") == nil;
}

static void BKIMESendReturnKey(id view) {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *marker = BKReturnKeyFile(@"return-key.pending");
  [fm createFileAtPath:marker contents:[NSData data] attributes:nil];
  gReturnKeysInFlight++;

  const NSTimeInterval now = [NSProcessInfo processInfo].systemUptime;
  BKStandInKeyEntry *down = [[BKStandInKeyEntry alloc] initWithState:kKeyPressStateDown timestamp:now];
  BKStandInKeyEntry *up = [[BKStandInKeyEntry alloc] initWithState:kKeyPressStateUp timestamp:now];
  void (^done)(id, BOOL) = ^(id entry, BOOL wasHandled) {
  };
  void (*send)(id, SEL, id, id) = (void (*)(id, SEL, id, id))objc_msgSend;
  SEL handle = sel_registerName("handleKeyEntry:withCompletionHandler:");
  @try {
    send(view, handle, down, done);
    send(view, handle, up, done);
  } @catch (NSException *exception) {
    BKLog(@"ime: the engine raised %@ while handling the Return key - the fix is off until the next launch", exception.name);
    gReturnKeyFix = NO;
  }

  // Still alive a few seconds later: that press was fine.
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(BKIMEReturnKeyHealthyDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    if (--gReturnKeysInFlight <= 0) {
      BKIMEReturnKeySurvived();
    }
  });
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
  const BOOL returnKey = [text isEqualToString:@"\n"];
  const BOOL composing = [(id<BKIMEView>)self hasMarkedText];
  BKIMETrace(@"insertText length=%lu%@ (hasMarkedText=%d)", (unsigned long)text.length, returnKey ? @" [return key]" : @"", composing ? 1 : 0);
  if (returnKey && !composing && BKIMEReturnKeyApplies(self)) {
    BKIMETrace(@"return key -> Enter key press (keydown, keypress, keyup)");
    BKIMESendReturnKey(self);
    gLastMarkedLength = 0;
    return;
  }
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
  if (!BKIMEContractHolds(kIMERequirements, sizeof(kIMERequirements) / sizeof(kIMERequirements[0]))) {
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

  // The Return key (-insertText:@"\n" hook above): Enter key presses instead of a typed line break.
  if ([[NSFileManager defaultManager] fileExistsAtPath:[BKDocumentsPath() stringByAppendingPathComponent:@"disable-return-fix"]]) {
    BKLog(@"ime: Documents/disable-return-fix exists - the Return key keeps typing a line break");
  } else if (!BKIMEContractHolds(kReturnKeyRequirements, sizeof(kReturnKeyRequirements) / sizeof(kReturnKeyRequirements[0]))) {
    BKLog(@"ime: the engine's key handling does not match - the Return key keeps typing a line break");
  } else {
    BKIMEReturnKeyCheckLastLaunch();
    gReturnKeyFix = ![[NSFileManager defaultManager] fileExistsAtPath:[BKDocumentsPath() stringByAppendingPathComponent:@"disable-return-fix"]];
    BKLog(@"ime: the Return key %@", gReturnKeyFix ? @"now sends Enter key presses (below iOS 17.4)" : @"keeps typing a line break");
    if (gReturnKeyFix) {
      // Closing the app from the app switcher right after a Return key press is not a crash: leaving the foreground counts as survived.
      [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationWillResignActiveNotification
                                                        object:nil
                                                         queue:nil
                                                    usingBlock:^(NSNotification *note) {
                                                      if (gReturnKeysInFlight > 0) {
                                                        BKIMEReturnKeySurvived();
                                                      }
                                                    }];
    }
  }
}
