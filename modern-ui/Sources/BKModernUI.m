// SPDX-License-Identifier: GPL-3.0-or-later
//
// Entry point of the modern UI layer.  As a separate framework it is loaded by an LC_LOAD_DYLIB command that the packaging step
// adds to the app's executable; the constructor below then runs once, before the stock UI is built.

#import <UIKit/UIKit.h>
#import "BKCore.h"
#import "BKHooks.h"
#import "BKTheme.h"

#ifndef BK_VERSION
#define BK_VERSION "dev"
#endif

#ifndef BK_HARNESS  // the simulator harness installs the hooks itself, after seeding its preferences
__attribute__((constructor)) static void BKModernUIMain(void) {
  @autoreleasepool {
    BKLog(@"Modern UI %s on iOS %@ - loading", BK_VERSION, UIDevice.currentDevice.systemVersion);
    [BKTheme cachePrivateSessionAtLaunch];   // the session type is fixed for this launch
    if (!BKGuardBeginLaunch()) {
      return;
    }
    BKInstallHooks();
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(8.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      BKGuardMarkLaunchHealthy();
    });
  }
}
#endif
