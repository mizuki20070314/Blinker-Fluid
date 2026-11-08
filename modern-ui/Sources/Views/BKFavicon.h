// SPDX-License-Identifier: GPL-3.0-or-later
// Site icons for the start-page tiles.  Same sources as the stock start page (the site's apple-touch-icon, then Google's icon
// service), but cached on disk and never fetched while a proxy is configured.  Only the tiles the user chose (shortcuts and
// bookmarks) ever trigger a request - browsing history never does.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface BKFavicon : NSObject
+ (nullable UIImage *)cachedImageForURLString:(NSString *)url;
+ (void)loadForURLString:(NSString *)url completion:(void (^)(UIImage *image))completion;   // called on the main queue, only when an icon exists
@end

NS_ASSUME_NONNULL_END
