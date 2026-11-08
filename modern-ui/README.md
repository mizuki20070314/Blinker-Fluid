# Blinker Fluid – Modern UI

A new browser interface for Blinker Fluid (address bar, toolbar, tab grid, menu sheet, start page, light/dark), written for the
iPod touch 6th generation on iOS 12 (A8, 1 GB RAM, 320 × 568) and working on everything the app supports.

It is **not** a Chromium rebuild. The released engine (`content_shell_framework`, Blink + V8) is used byte for byte; this folder
builds one small extra framework, `BlinkerModernUI.framework` (about 340 KB, Objective‑C, no Swift, no images – every icon is
drawn in code), which re‑skins the stock UI classes through the Objective‑C runtime.

| | |
|---|---|
| Address bar | rounded pill with lock / "Not Secure" mark and the host name; tap = address entry, long‑press = search engine, swipe = previous/next tab |
| Toolbar | back · forward · new tab · tabs (with count) · menu; **Settings → Toolbar Position → Bottom** moves the address bar down next to it |
| Landscape | one bar on top (back, forward, address, tabs, menu) so the page gets the screen |
| Loading | thin progress line; the reload icon spins while a page loads |
| Address entry | full‑screen, suggestions from bookmarks and history on the device; the search provider's suggestions only when opened from the start page (the stock privacy rules, see below) |
| Tabs | grid of page thumbnails, ✕ on every card, swipe a card away to close, long‑press and drag to reorder, big **+** |
| Menu | bottom sheet with quick actions (new tab, bookmarks, downloads, share) above the stock list; the list screens (settings, bookmarks, history …) get the same look |
| New tab page | logo, search field, favourites (the stock `BlinkShortcuts`), recent sites |
| Gestures | swipe in from the left / right screen edge = back / forward |
| Themes | light / dark (iOS 12 has no system dark mode, so **Settings → Appearance** decides there), violet accent and tint in a private session |
| Languages | follows the stock language setting (English, Japanese so far) |

Nothing about browsing changed: navigation, tabs, bookmarks, history, downloads, settings and the engine are the stock code. The
new UI only decides how they look and where the buttons are.

## Install

CI builds the IPA: **Actions → Modern UI → latest run → Artifacts → `BlinkerFluid-ModernUI-ios12-ipa`** (the `.ipa` inside the zip).
It is the released **v.0.3.1 iOS 12 IPA** (SHA‑256 `e26dc439…5822eb`, checked by CI) with the framework added:

* the app executable gets one more `LC_LOAD_DYLIB`; it is signed again with `ldid` using its **original entitlements**
  (`increased-memory-limit`, `extended-virtual-addressing`, `get-task-allow`);
* the bundle identifier is unchanged (`com.nodesclock.blinkerfluid.ios12`), so installing over the old app keeps tabs, bookmarks
  and settings; `CFBundleVersion` becomes `0.3.1.<build>`.

Install it the way you installed the original IPA (jailbreak: unzip, copy `content_shell.app` to `/Applications`, `uicache`, or
your installer of choice). A free‑certificate sideload strips the entitlements and does not work for the stock app either.

### If something is wrong

* **The app crashes right after start** – nothing to do: if the previous launch did not get through its first 3 seconds with the new screen up the layer
  stays off for one launch, and after two such launches it stays off until you delete `ModernUI-safe-mode.txt` (see below). One
  screen that keeps failing (address entry, tab grid, menu) falls back to the stock screen on its own.
* **Turn it off by hand** – menu → **Modern UI** (last row), or create a file called `disable-modern-ui` in the app's folder. In
  the Files app: *On My iPod → Blinker Fluid*; duplicate `ModernUI.log` and rename the copy.
* **Turn it on again** – delete `disable-modern-ui` / `ModernUI-safe-mode.txt` there, or create `enable-modern-ui` (resets the guard).
* **Report a problem** – send `ModernUI.log` from the same folder. It lists which hooks were installed and why anything was skipped.

## How it works

```
released IPA ──► + BlinkerModernUI.framework ──► executable loads it (extra LC_LOAD_DYLIB)
                                                   │ constructor, before the stock UI exists
                                                   ▼
        BKContract.inc matches the binary?  no ─► stock UI untouched
                          │ yes
                          ▼
   hooks on ContentShellWindowDelegate (per‑tab controller), BlinkListVC (every list), BlinkTabsVC (tab data),
   BlinkerStartPageView (replaced), presentViewController: (turns the menu / tab list into the new screens)
```

* `Sources/Hooks/BKContract.inc` lists every Objective‑C method and ivar the hooks depend on, with its signature.  At launch the
  layer checks the list against the running binary; CI checks it against the released `content_shell_framework`
  (`tools/objc_dump.py` + `tools/check_contract.py`), so a different engine build can never half‑apply the new UI.
* The engine talks to the UI through a few stock selectors (`setURL:`, `setPageLoading:`, `-backButton`'s `setEnabled:` …); the
  hooks keep those working, with the new views behind them. Stock views that are replaced stay alive but off‑screen, so every
  stock code path that still touches them is harmless.
* **Privacy rules of the stock UI are kept.** Search suggestions are requested only from the new‑tab page, never while a proxy
  (Tor) is configured, never in a private session, and only if *Search Suggestions* is on; site icons are fetched only for the
  favourites the user chose, and never while a proxy is configured. History and bookmarks are read locally.

## Building

CI does everything (`.github/workflows/modern-ui.yml`). Locally on a Mac with Xcode and `ldid`:

```sh
modern-ui/build/build_device.sh build/device                       # BlinkerModernUI.framework (arm64, iOS 12+)
modern-ui/build/package_ipa.sh base.ipa build/device/BlinkerModernUI.framework out.ipa 1
python3 modern-ui/tools/verify_ipa.py out.ipa base.ipa
```

`modern-ui/Harness` is a simulator app that runs the **real** hook installer against a replica of the stock controller
(`StockMock.m`) and the **real** stock list/tab classes (cut out of `shell_platform_delegate_ios.mm` by `extract_stock.py`), walks
through the screens in a 320 × 568 window and saves pictures (light, dark, bottom bar, private, Japanese, landscape). The pictures
are the `modern-ui-screens` artifact of every CI run.

### Folding it into a Chromium build

Nothing here depends on being a separate framework: add the files under `Sources/` to the `content_shell_framework` sources in
`content/shell/BUILD.gn` and the same constructor installs the hooks from inside the engine image.

## Limits

* The simulator harness cannot run iOS 12 or the engine, so behaviour that depends on the engine (real page loading, fullscreen
  video, keyboard avoidance with web text fields) is exercised only through the stock selectors, not through Blink.
* The stock stop button only reloads, so there is no stop icon.
* Thumbnails in the tab grid are the stock window snapshots with the bars cropped off.
* Auto‑hiding the bars while scrolling is not implemented (it would resize the web view on every scroll).

License: GPL‑3.0, like the rest of the repository.
