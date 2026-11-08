// SPDX-License-Identifier: GPL-3.0-or-later
// The tab switcher: a grid of page thumbnails with a close button on every card, swipe-to-close, drag-to-reorder and a big "+".
// It is fed by the stock BlinkTabsVC (titles / urls / previews and the select / close / add / reorder blocks), so the engine
// side of tab management is untouched.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BKTabGridViewController : UIViewController
// `stock` is the BlinkTabsVC the stock code built; `currentURL` marks the open tab; the crop fractions remove the bars from
// the window snapshots the stock code takes of every tab.
- (instancetype)initWithStockTabs:(UIViewController *)stock
                       currentURL:(nullable NSString *)currentURL
                          cropTop:(CGFloat)cropTop
                       cropBottom:(CGFloat)cropBottom;
@end

NS_ASSUME_NONNULL_END
