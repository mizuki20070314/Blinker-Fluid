// SPDX-License-Identifier: GPL-3.0-or-later
#import "BKCore.h"

NSNotificationName const BKThemeDidChangeNotification = @"BKThemeDidChangeNotification";

// ---------------------------------------------------------------------------------------------------------------- paths

NSString *BKDocumentsPath(void) {
  static NSString *path;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    path = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject ?: NSTemporaryDirectory();
  });
  return path;
}

NSString *BKSupportPath(void) {
  static NSString *path;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    NSString *caches = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject ?: NSTemporaryDirectory();
    path = [caches stringByAppendingPathComponent:@"ModernUI"];
    [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
  });
  return path;
}

// ------------------------------------------------------------------------------------------------------------------ log

static dispatch_queue_t BKLogQueue(void) {
  static dispatch_queue_t queue;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    queue = dispatch_queue_create("jp.tank.modernui.log", DISPATCH_QUEUE_SERIAL);
  });
  return queue;
}

void BKLog(NSString *format, ...) {
  va_list args;
  va_start(args, format);
  NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);
  NSLog(@"[ModernUI] %@", message);
  NSDate *now = [NSDate date];
  dispatch_async(BKLogQueue(), ^{
    static NSDateFormatter *formatter;
    if (!formatter) {
      formatter = [[NSDateFormatter alloc] init];
      formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss.SSS";
      formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    }
    NSString *line = [NSString stringWithFormat:@"%@ %@\n", [formatter stringFromDate:now], message];
    NSString *path = [BKDocumentsPath() stringByAppendingPathComponent:@"ModernUI.log"];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSDictionary *attrs = [fm attributesOfItemAtPath:path error:nil];
    if ([attrs fileSize] > 256 * 1024) {
      NSString *old = [BKDocumentsPath() stringByAppendingPathComponent:@"ModernUI.log.1"];
      [fm removeItemAtPath:old error:nil];
      [fm moveItemAtPath:path toPath:old error:nil];
    }
    if (![fm fileExistsAtPath:path]) {
      [fm createFileAtPath:path contents:nil attributes:nil];
    }
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    [handle seekToEndOfFile];
    [handle writeData:[line dataUsingEncoding:NSUTF8StringEncoding]];
    [handle closeFile];
  });
}

// ---------------------------------------------------------------------------------------------------------------- guard

static NSString *BKGuardPlistPath(void) { return [BKSupportPath() stringByAppendingPathComponent:@"guard.plist"]; }
static NSString *BKLaunchMarkerPath(void) { return [BKSupportPath() stringByAppendingPathComponent:@"launch.marker"]; }

static NSMutableDictionary *BKGuardLoad(void) {
  return [NSMutableDictionary dictionaryWithContentsOfFile:BKGuardPlistPath()] ?: [NSMutableDictionary dictionary];
}

static void BKGuardSave(NSDictionary *dict) { [dict writeToFile:BKGuardPlistPath() atomically:YES]; }

BOOL BKGuardBeginLaunch(void) {
  NSFileManager *fm = [NSFileManager defaultManager];
  NSString *docs = BKDocumentsPath();
  NSString *disableFile = [docs stringByAppendingPathComponent:@"disable-modern-ui"];
  NSString *enableFile = [docs stringByAppendingPathComponent:@"enable-modern-ui"];
  NSString *safeFile = [docs stringByAppendingPathComponent:@"ModernUI-safe-mode.txt"];

  if ([fm fileExistsAtPath:enableFile]) {  // the user asks for a clean retry
    [fm removeItemAtPath:BKGuardPlistPath() error:nil];
    [fm removeItemAtPath:BKLaunchMarkerPath() error:nil];
    [fm removeItemAtPath:safeFile error:nil];
    [fm removeItemAtPath:enableFile error:nil];
    BKLog(@"guard: reset by Documents/enable-modern-ui");
  }
  if ([fm fileExistsAtPath:disableFile]) {
    BKLog(@"guard: Documents/disable-modern-ui exists -> stock UI");
    return NO;
  }
  if ([fm fileExistsAtPath:safeFile]) {
    BKLog(@"guard: safe mode file exists -> stock UI (delete Documents/ModernUI-safe-mode.txt to retry)");
    return NO;
  }

  NSMutableDictionary *state = BKGuardLoad();
  NSInteger strikes = [state[@"strikes"] integerValue];
  BOOL previousRunDied = [fm fileExistsAtPath:BKLaunchMarkerPath()];
  if (previousRunDied) {
    strikes += 1;
    state[@"strikes"] = @(strikes);
    BKGuardSave(state);
    [fm removeItemAtPath:BKLaunchMarkerPath() error:nil];
    BKLog(@"guard: the previous launch did not become healthy (strike %ld)", (long)strikes);
  }
  if (strikes >= 2) {
    NSString *text = @"Blinker Fluid Modern UI was switched off because the app stopped twice shortly after launch.\n"
                      "The stock interface is used instead.\n"
                      "To try again: delete this file (or create an empty file named enable-modern-ui next to it).\n"
                      "ModernUI.log in this folder has details.\n";
    [text writeToFile:safeFile atomically:YES encoding:NSUTF8StringEncoding error:nil];
    BKLog(@"guard: two strikes -> safe mode file written, stock UI");
    return NO;
  }
  if (previousRunDied) {
    BKLog(@"guard: running this launch with the stock UI (one strike so far)");
    return NO;
  }
  [[NSString stringWithFormat:@"%f", [[NSDate date] timeIntervalSince1970]] writeToFile:BKLaunchMarkerPath()
                                                                              atomically:YES
                                                                                encoding:NSUTF8StringEncoding
                                                                                   error:nil];
  return YES;
}

void BKGuardMarkLaunchHealthy(void) {
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:BKLaunchMarkerPath()]) {
    [fm removeItemAtPath:BKLaunchMarkerPath() error:nil];
    NSMutableDictionary *state = BKGuardLoad();
    if ([state[@"strikes"] integerValue] != 0) {
      state[@"strikes"] = @0;
      BKGuardSave(state);
    }
    BKLog(@"guard: launch is healthy");
  }
}

static NSString *BKFeatureMarkerPath(NSString *feature) {
  return [BKSupportPath() stringByAppendingPathComponent:[NSString stringWithFormat:@"feature-%@.marker", feature]];
}

BOOL BKFeatureAllowed(NSString *feature) {
  static NSMutableDictionary<NSString *, NSNumber *> *decided;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    decided = [NSMutableDictionary dictionary];
  });
  @synchronized(decided) {
    NSNumber *known = decided[feature];
    if (known) {
      return known.boolValue;
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableDictionary *state = BKGuardLoad();
    NSMutableDictionary *strikesByFeature = [state[@"features"] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSInteger strikes = [strikesByFeature[feature] integerValue];
    if ([fm fileExistsAtPath:BKFeatureMarkerPath(feature)]) {  // it started last time and never finished
      strikes += 1;
      strikesByFeature[feature] = @(strikes);
      state[@"features"] = strikesByFeature;
      BKGuardSave(state);
      [fm removeItemAtPath:BKFeatureMarkerPath(feature) error:nil];
      BKLog(@"guard: feature '%@' did not finish last time (strike %ld)", feature, (long)strikes);
    }
    BOOL allowed = strikes < 2;
    decided[feature] = @(allowed);
    if (!allowed) {
      BKLog(@"guard: feature '%@' is off (stock screen is used)", feature);
    }
    return allowed;
  }
}

void BKFeatureBegin(NSString *feature) {
  [@"1" writeToFile:BKFeatureMarkerPath(feature) atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

void BKFeatureEnd(NSString *feature) {
  NSFileManager *fm = [NSFileManager defaultManager];
  if ([fm fileExistsAtPath:BKFeatureMarkerPath(feature)]) {
    [fm removeItemAtPath:BKFeatureMarkerPath(feature) error:nil];
    NSMutableDictionary *state = BKGuardLoad();
    NSMutableDictionary *strikesByFeature = [state[@"features"] mutableCopy];
    if (strikesByFeature[feature]) {
      [strikesByFeature removeObjectForKey:feature];
      state[@"features"] = strikesByFeature;
      BKGuardSave(state);
    }
  }
}

// -------------------------------------------------------------------------------------------------------------- runtime

static NSString *BKShapeOf(const char *types) {
  NSMutableString *shape = [NSMutableString string];
  for (const char *p = types; p && *p; p++) {
    if (*p >= '0' && *p <= '9') {
      continue;
    }
    [shape appendFormat:@"%c", *p];
  }
  return shape;
}

BOOL BKHookInstance(Class cls, SEL sel, const char *shape, IMP imp, IMP *orig) {
  if (!cls) {
    BKLog(@"hook: class missing for %s", sel_getName(sel));
    return NO;
  }
  Method method = class_getInstanceMethod(cls, sel);
  if (!method) {
    BKLog(@"hook: %s has no -%s", class_getName(cls), sel_getName(sel));
    return NO;
  }
  NSString *actual = BKShapeOf(method_getTypeEncoding(method));
  if (strcmp(actual.UTF8String, shape) != 0) {
    BKLog(@"hook: -[%s %s] has signature %@ (expected %s) - not hooked", class_getName(cls), sel_getName(sel), actual, shape);
    return NO;
  }
  BOOL definedHere = NO;
  unsigned int count = 0;
  Method *list = class_copyMethodList(cls, &count);
  for (unsigned int i = 0; i < count; i++) {
    if (method_getName(list[i]) == sel) {
      definedHere = YES;
      break;
    }
  }
  free(list);
  IMP previous = method_getImplementation(method);
  if (definedHere) {
    method_setImplementation(method, imp);
  } else if (!class_addMethod(cls, sel, imp, method_getTypeEncoding(method))) {
    BKLog(@"hook: could not add -[%s %s]", class_getName(cls), sel_getName(sel));
    return NO;
  }
  if (orig) {
    *orig = previous;
  }
  return YES;
}

id BKGetIvar(id obj, const char *name) {
  if (!obj) {
    return nil;
  }
  Ivar ivar = class_getInstanceVariable(object_getClass(obj), name);
  return ivar ? object_getIvar(obj, ivar) : nil;
}

// ------------------------------------------------------------------------------------------------------------- strings

NSString *BKLanguageCode(void) {
  static NSString *code;
  NSString *accept = [[NSUserDefaults standardUserDefaults] stringForKey:@"BlinkLanguageAccept"] ?: @"en-US,en";
  NSString *first = [[accept componentsSeparatedByString:@","] firstObject] ?: @"en-US";
  NSString *language = [[first componentsSeparatedByString:@"-"] firstObject] ?: @"en";
  code = language.lowercaseString;
  return code;
}

NSString *BKL(NSString *english) {
  static NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *> *tables;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    tables = @{
      @"ja" : @{
        @"Search or enter address" : @"検索またはアドレスを入力",
        @"Search or type URL" : @"検索またはアドレスを入力",
        @"Cancel" : @"キャンセル",
        @"Done" : @"完了",
        @"New Tab" : @"新規タブ",
        @"Tabs" : @"タブ",
        @"%ld Tabs" : @"%ld 個のタブ",
        @"1 Tab" : @"1 個のタブ",
        @"Private" : @"プライベート",
        @"Private Browsing" : @"プライベートブラウズ",
        @"Private tabs are not saved." : @"プライベートタブの履歴や Cookie は保存されません。",
        @"Not Secure" : @"保護されていません",
        @"Favorites" : @"お気に入り",
        @"Recent" : @"最近見たサイト",
        @"Search" : @"検索",
        @"Go to %@" : @"%@ を開く",
        @"Search for \"%@\"" : @"「%@」を検索",
        @"Paste and Go" : @"ペーストして移動",
        @"Bookmarks" : @"ブックマーク",
        @"History" : @"履歴",
        @"Suggestions" : @"候補",
        @"Close Tab" : @"タブを閉じる",
        @"Close All" : @"すべて閉じる",
        @"Menu" : @"メニュー",
        @"Back" : @"戻る",
        @"Forward" : @"進む",
        @"Reload" : @"再読み込み",
        @"Stop" : @"停止",
        @"Share" : @"共有",
        @"Downloads" : @"ダウンロード",
        @"Settings" : @"設定",
        @"Add Bookmark" : @"ブックマークに追加",
        @"No Tabs" : @"タブがありません",
        @"Clear" : @"消去",
        @"Address" : @"アドレス",
        @"Blinker Fluid" : @"Blinker Fluid",
        @"Turn off" : @"オフにする",
        @"Turn off the modern interface? The stock interface comes back after you quit and reopen Blinker Fluid. To turn it on again, delete the file disable-modern-ui in the app's folder (Files app)." :
            @"新しいインターフェースをオフにしますか？Blinker Fluid を終了して開き直すと元の画面に戻ります。もう一度オンにするには、アプリのフォルダ(ファイルアプリ)にある disable-modern-ui というファイルを削除してください。",
      },
    };
  });
  NSString *translated = tables[BKLanguageCode()][english];
  return translated ?: english;
}
