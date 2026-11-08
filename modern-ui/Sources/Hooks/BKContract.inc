// SPDX-License-Identifier: GPL-3.0-or-later
//
// The contract between the modern UI and the stock Blinker Fluid binary: every Objective-C method / ivar the hooks rely on.
// Included twice by BKHooks.m (once to check at launch - if anything is missing or has another signature the UI layer stays
// off and the stock UI runs untouched) and parsed by tools/check_contract.py in CI against the Objective-C metadata of the
// released content_shell_framework.  Keep one entry per line:  BK_METHOD("Class", "selector:", "shape")  /  BK_IVAR("Class", "_ivar")
// where shape is the type encoding without frame offsets (v = void, @ = object, : = selector, B = BOOL, q = NSInteger, d = double,
// ^v = pointer, Q = unsigned).

// --- ContentShellWindowDelegate: the per-tab controller that owns the toolbar -------------------------------------------
BK_METHOD("ContentShellWindowDelegate", "viewDidLoad", "v@:")
BK_METHOD("ContentShellWindowDelegate", "applyToolbarPosition", "v@:")
BK_METHOD("ContentShellWindowDelegate", "setURL:", "v@:@")
BK_METHOD("ContentShellWindowDelegate", "setPageLoading:", "v@:B")
BK_METHOD("ContentShellWindowDelegate", "backButton", "@@:")
BK_METHOD("ContentShellWindowDelegate", "forwardButton", "@@:")
BK_METHOD("ContentShellWindowDelegate", "reloadOrStopButton", "@@:")
BK_METHOD("ContentShellWindowDelegate", "menuButton", "@@:")
BK_METHOD("ContentShellWindowDelegate", "toolbarBackgroundView", "@@:")
BK_METHOD("ContentShellWindowDelegate", "updateDownloadAttentionBadge", "v@:")
BK_METHOD("ContentShellWindowDelegate", "ensureStartPage", "v@:")
BK_METHOD("ContentShellWindowDelegate", "showStartPage:", "v@:B")
BK_METHOD("ContentShellWindowDelegate", "startPage", "@@:")
BK_METHOD("ContentShellWindowDelegate", "switchToTab:direction:", "v@:^vq")
BK_METHOD("ContentShellWindowDelegate", "showTabWindow:", "v@:^v")
BK_METHOD("ContentShellWindowDelegate", "openNewTab", "v@:")
BK_METHOD("ContentShellWindowDelegate", "closeCurrentTab", "v@:")
BK_METHOD("ContentShellWindowDelegate", "applyWebColorScheme:", "v@:q")
BK_METHOD("ContentShellWindowDelegate", "shell", "^v@:")
BK_METHOD("ContentShellWindowDelegate", "contentView", "@@:")
BK_METHOD("ContentShellWindowDelegate", "topPosConstraints", "@@:")
BK_METHOD("ContentShellWindowDelegate", "setTopPosConstraints:", "v@:@")
BK_METHOD("ContentShellWindowDelegate", "bottomPosConstraints", "@@:")
BK_METHOD("ContentShellWindowDelegate", "setBottomPosConstraints:", "v@:@")
BK_METHOD("ContentShellWindowDelegate", "keyboardViewportInset", "d@:")
BK_METHOD("ContentShellWindowDelegate", "back", "v@:")
BK_METHOD("ContentShellWindowDelegate", "forward", "v@:")
BK_METHOD("ContentShellWindowDelegate", "reloadOrStop", "v@:")
BK_METHOD("ContentShellWindowDelegate", "showTabSwitcher", "v@:")
BK_METHOD("ContentShellWindowDelegate", "showMainMenu", "v@:")
BK_METHOD("ContentShellWindowDelegate", "openUserInput:", "v@:@")
BK_METHOD("ContentShellWindowDelegate", "presentSearchEngineMenu", "v@:")
BK_METHOD("ContentShellWindowDelegate", "handleURLBarSwipe:", "v@:@")
BK_IVAR("ContentShellWindowDelegate", "_toolbarBackgroundView")
BK_IVAR("ContentShellWindowDelegate", "_loadingProgressView")
BK_IVAR("ContentShellWindowDelegate", "_urlField")
BK_IVAR("ContentShellWindowDelegate", "_backButton")
BK_IVAR("ContentShellWindowDelegate", "_forwardButton")

// --- BlinkListVC: every list screen (menu, settings, bookmarks, history ...) -------------------------------------------
BK_METHOD("BlinkListVC", "viewDidLoad", "v@:")
BK_METHOD("BlinkListVC", "applyNavigationBarAppearance", "v@:")
BK_METHOD("BlinkListVC", "tableView:cellForRowAtIndexPath:", "@@:@@")
BK_METHOD("BlinkListVC", "globalRowForIndexPath:", "q@:@")
BK_METHOD("BlinkListVC", "titles", "@@:")
BK_METHOD("BlinkListVC", "imageNames", "@@:")
BK_METHOD("BlinkListVC", "rowImages", "@@:")
BK_METHOD("BlinkListVC", "sectionStarts", "@@:")
BK_METHOD("BlinkListVC", "titleColors", "@@:")
BK_METHOD("BlinkListVC", "badgedRows", "@@:")
BK_METHOD("BlinkListVC", "compactRows", "B@:")
BK_METHOD("BlinkListVC", "onSelect", "@?@:")

// --- BlinkTabsVC: the data and callbacks behind the tab switcher ------------------------------------------------------
BK_METHOD("BlinkTabsVC", "titles", "@@:")
BK_METHOD("BlinkTabsVC", "urls", "@@:")
BK_METHOD("BlinkTabsVC", "previews", "@@:")
BK_METHOD("BlinkTabsVC", "onSelect", "@?@:")
BK_METHOD("BlinkTabsVC", "onClose", "@?@:")
BK_METHOD("BlinkTabsVC", "onAdd", "@?@:")
BK_METHOD("BlinkTabsVC", "onReorder", "@?@:")

// --- small screens that are only re-coloured ------------------------------------------------------------------------
BK_METHOD("BlinkBookmarkEditorVC", "viewDidLoad", "v@:")
