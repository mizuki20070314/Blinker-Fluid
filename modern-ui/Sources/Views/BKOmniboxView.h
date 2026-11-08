// SPDX-License-Identifier: GPL-3.0-or-later
// The address-entry screen: a text field with Cancel, and a list of suggestions underneath (search / go-to row, bookmarks,
// history, and - only when it was opened from the start page and the stock privacy rules allow it - the search provider's
// suggestions).  Navigation itself is the stock -openUserInput:, so URL-or-search decisions, HTTPS-first etc. stay as they were.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BKOmniboxView : UIView
@property(nonatomic, copy, nullable) void (^onSubmit)(NSString *input);
@property(nonatomic, copy, nullable) void (^onCancel)(void);
@property(nonatomic, copy, nullable) void (^onLongPressField)(void);      // opens the stock search-engine chooser
@property(nonatomic, readonly) BOOL fromStartPage;

- (void)beginWithText:(nullable NSString *)text fromStartPage:(BOOL)fromStartPage;
- (void)endEditing;
- (void)applyTheme;
@end

NS_ASSUME_NONNULL_END
