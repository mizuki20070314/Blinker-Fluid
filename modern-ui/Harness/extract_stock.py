#!/usr/bin/env python3
"""Cut the pure-UIKit stock classes (BlinkListVC, BlinkBookmarkEditorVC, BlinkTabCardCell, BlinkTabsVC) out of the real
shell_platform_delegate_ios.mm so the simulator harness runs the *actual* stock code under the hooks.

    python3 extract_stock.py <shell_platform_delegate_ios.mm> <out.inc>
"""
import sys

src = open(sys.argv[1], encoding="utf-8").read()
start_marker = "// A reusable modal list view used for Tabs, Bookmarks and"
end_marker = "// The native Blinker Fluid start page."
a = src.index(start_marker)
b = src.index(end_marker)
text = src[a:b]
for needed in ("@implementation BlinkListVC", "@implementation BlinkBookmarkEditorVC", "@implementation BlinkTabCardCell", "@implementation BlinkTabsVC"):
    assert needed in text, needed
open(sys.argv[2], "w", encoding="utf-8").write(text)
print("extracted %d lines of stock UI code" % text.count("\n"))
