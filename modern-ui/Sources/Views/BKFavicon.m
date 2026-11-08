// SPDX-License-Identifier: GPL-3.0-or-later
#import "BKFavicon.h"
#import "BKCore.h"
#import "BKSettings.h"

static NSString *BKIconDirectory(void) {
  static NSString *dir;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    dir = [BKSupportPath() stringByAppendingPathComponent:@"icons"];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
  });
  return dir;
}

static NSString *BKHostKey(NSString *url) {
  NSURL *parsed = [NSURL URLWithString:url];
  NSString *host = parsed.host.lowercaseString;
  if (!host.length) {
    return nil;
  }
  NSUInteger hash = 5381;
  for (NSUInteger i = 0; i < host.length; i++) {
    hash = ((hash << 5) + hash) + [host characterAtIndex:i];
  }
  return [NSString stringWithFormat:@"%@-%08lx", [host stringByReplacingOccurrencesOfString:@"/" withString:@"_"], (unsigned long)hash];
}

static NSCache<NSString *, UIImage *> *BKMemoryCache(void) {
  static NSCache *cache;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    cache = [[NSCache alloc] init];
    cache.countLimit = 64;
  });
  return cache;
}

@implementation BKFavicon

+ (UIImage *)cachedImageForURLString:(NSString *)url {
  NSString *key = BKHostKey(url);
  if (!key) {
    return nil;
  }
  UIImage *image = [BKMemoryCache() objectForKey:key];
  if (image) {
    return image;
  }
  NSString *path = [BKIconDirectory() stringByAppendingPathComponent:[key stringByAppendingString:@".png"]];
  image = [UIImage imageWithContentsOfFile:path];
  if (image) {
    [BKMemoryCache() setObject:image forKey:key];
  }
  return image;
}

+ (UIImage *)downscaled:(UIImage *)image {
  const CGFloat target = 128;
  if (MAX(image.size.width, image.size.height) <= target) {
    return image;
  }
  CGFloat scale = target / MAX(image.size.width, image.size.height);
  CGSize size = CGSizeMake(image.size.width * scale, image.size.height * scale);
  UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat preferredFormat];
  format.scale = 1;
  UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:size format:format];
  return [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
  }];
}

+ (void)loadForURLString:(NSString *)url completion:(void (^)(UIImage *))completion {
  NSString *key = BKHostKey(url);
  if (!key) {
    return;
  }
  UIImage *cached = [self cachedImageForURLString:url];
  if (cached) {
    dispatch_async(dispatch_get_main_queue(), ^{
      completion(cached);
    });
    return;
  }
  if ([BKSettings proxyConfigured]) {
    return;  // a direct request would bypass the proxy the user set up
  }
  NSURLComponents *components = [NSURLComponents componentsWithString:url];
  components.path = @"/apple-touch-icon.png";
  components.query = nil;
  components.fragment = nil;
  NSURL *touchIcon = components.URL;
  if (!touchIcon) {
    return;
  }
  void (^finish)(UIImage *) = ^(UIImage *image) {
    UIImage *small = [self downscaled:image];
    NSString *path = [BKIconDirectory() stringByAppendingPathComponent:[key stringByAppendingString:@".png"]];
    [UIImagePNGRepresentation(small) writeToFile:path atomically:YES];
    [BKMemoryCache() setObject:small forKey:key];
    dispatch_async(dispatch_get_main_queue(), ^{
      completion(small);
    });
  };
  NSURLSession *session = [NSURLSession sharedSession];
  [[session dataTaskWithURL:touchIcon
          completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            UIImage *image = (data.length && !error) ? [UIImage imageWithData:data] : nil;
            if (image && image.size.width >= 32) {
              finish(image);
              return;
            }
            NSString *encoded = [url stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
            NSURL *service = [NSURL URLWithString:[NSString stringWithFormat:@"https://www.google.com/s2/favicons?domain_url=%@&sz=128", encoded]];
            if (!service) {
              return;
            }
            [[session dataTaskWithURL:service
                    completionHandler:^(NSData *data2, NSURLResponse *response2, NSError *error2) {
                      UIImage *fallback = (data2.length && !error2) ? [UIImage imageWithData:data2] : nil;
                      if (fallback && fallback.size.width >= 16) {
                        finish(fallback);
                      }
                    }] resume];
          }] resume];
}

@end
