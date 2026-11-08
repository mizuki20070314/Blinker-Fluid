// SPDX-License-Identifier: GPL-3.0-or-later
#import "BKSettings.h"
#import "BKTheme.h"

// Same order and endpoints as kSearchEngines in shell_platform_delegate_ios.mm (index = "BlinkSearchEngine").
static NSString *const kEngineNames[] = {@"Google", @"DuckDuckGo", @"Bing", @"Yahoo", @"Blinker Fluid (Google)"};
static NSString *const kEngineSuggest[] = {
  @"https://suggestqueries.google.com/complete/search?client=firefox&q=",
  @"https://duckduckgo.com/ac/?type=list&q=",
  @"https://api.bing.com/osjson.aspx?query=",
  @"https://search.yahoo.com/sugg/os?output=fxjson&command=",
  @"https://suggestqueries.google.com/complete/search?client=firefox&q=",
};
static const NSInteger kEngineCount = 5;

@implementation BKSettings

+ (BOOL)toolbarAtBottom {
  return [[NSUserDefaults standardUserDefaults] boolForKey:@"BlinkToolbarBottom"];
}

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)shortcuts {
  NSArray *saved = [[NSUserDefaults standardUserDefaults] arrayForKey:@"BlinkShortcuts"];
  NSMutableArray *result = [NSMutableArray array];
  for (id entry in saved) {
    if ([entry isKindOfClass:[NSDictionary class]] && [entry[@"url"] isKindOfClass:[NSString class]] &&
        [entry[@"title"] isKindOfClass:[NSString class]]) {
      [result addObject:entry];
    }
  }
  if (result.count >= 4) {
    return result;
  }
  return @[
    @{@"title" : @"GitHub", @"url" : @"https://github.com"},
    @{@"title" : @"Reddit", @"url" : @"https://www.reddit.com"},
    @{@"title" : @"YouTube", @"url" : @"https://www.youtube.com"},
    @{@"title" : @"Google", @"url" : @"https://www.google.com"},
    @{@"title" : @"Gmail", @"url" : @"https://mail.google.com"},
    @{@"title" : @"Proton", @"url" : @"https://mail.proton.me"},
    @{@"title" : @"ChatGPT", @"url" : @"https://chatgpt.com"},
    @{@"title" : @"Claude", @"url" : @"https://claude.ai/new"},
  ];
}

static void BKFlatten(NSArray *items, NSMutableArray *out, int depth) {
  if (depth > 8) {
    return;
  }
  for (id item in items) {
    if (![item isKindOfClass:[NSDictionary class]]) {
      continue;
    }
    NSDictionary *dict = item;
    if ([dict[@"children"] isKindOfClass:[NSArray class]]) {
      BKFlatten(dict[@"children"], out, depth + 1);
    } else if ([dict[@"url"] isKindOfClass:[NSString class]]) {
      NSString *title = [dict[@"title"] isKindOfClass:[NSString class]] ? dict[@"title"] : @"";
      [out addObject:@{@"title" : title, @"url" : dict[@"url"]}];
    }
  }
}

+ (NSArray<NSDictionary<NSString *, NSString *> *> *)flatBookmarks {
  NSMutableArray *out = [NSMutableArray array];
  BKFlatten([[NSUserDefaults standardUserDefaults] arrayForKey:@"BlinkBookmarks"], out, 0);
  return out;
}

+ (NSArray<NSString *> *)historyURLs {
  if ([BKTheme isPrivateSession]) {
    return @[];
  }
  return [[NSUserDefaults standardUserDefaults] stringArrayForKey:@"BlinkHistory"] ?: @[];
}

+ (BOOL)proxyConfigured {
  return [[NSUserDefaults standardUserDefaults] stringForKey:@"BlinkProxy"].length > 0;
}

+ (NSInteger)engineIndex {
  NSInteger index = [[NSUserDefaults standardUserDefaults] integerForKey:@"BlinkSearchEngine"];
  return (index >= 0 && index < kEngineCount) ? index : 0;
}

+ (NSString *)searchEngineName {
  return kEngineNames[[self engineIndex]];
}

+ (BOOL)searchSuggestionsAllowed {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  BOOL enabled = [defaults objectForKey:@"BlinkSearchSuggestions"] == nil || [defaults boolForKey:@"BlinkSearchSuggestions"];
  return enabled && ![self proxyConfigured] && ![BKTheme isPrivateSession];
}

+ (NSURL *)suggestionURLForTerm:(NSString *)term {
  if (![self searchSuggestionsAllowed] || term.length < 2) {
    return nil;
  }
  NSString *escaped = [term stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
  return [NSURL URLWithString:[kEngineSuggest[[self engineIndex]] stringByAppendingString:escaped ?: @""]];
}

@end
