// SPDX-License-Identifier: GPL-3.0-or-later
// A bottom sheet (iOS 12 has no UISheetPresentationController): dimmed backdrop, rounded top corners, slides up from the bottom,
// closes on a tap outside or a downward drag on its grabber area.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BKSheetTransition : NSObject <UIViewControllerTransitioningDelegate>
// Keeps the delegate alive for as long as the presented controller lives (UIKit only holds it weakly).
+ (void)applyToController:(UIViewController *)controller;
@end

NS_ASSUME_NONNULL_END
