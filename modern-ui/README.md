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
| Tabs | grid of page thumbnails, ✕ on every card, swipe a card away to close, long‑press and drag to reorder, big **+**; closing the only tab opens a fresh one in its place |
| Menu | bottom sheet with quick actions (new tab, bookmarks, downloads, share) above the stock list; the list screens (settings, bookmarks, history …) get the same look. Three rows are added at the end: **Modern UI** (version, off switch), **JavaScript Speed Test** and **Input Test** (a page that lists every key, composition and input event it receives while you type in a one-line field and a text area – for checking the Return key and Japanese input on a device) |
| Japanese input | the engine's text fields now tell the keyboard when a composition (typed, not yet confirmed) exists, and the Return key reaches the page as a real Enter key press (search boxes, chat fields, forms) – see below |
| New tab page | logo, search field, favourites (the stock `BlinkShortcuts`), recent sites |
| Gestures | swipe in from the left / right screen edge = back / forward |
| Themes | light / dark (iOS 12 has no system dark mode, so **Settings → Appearance** decides there), violet accent and tint in a private session |
| Languages | follows the stock language setting (English, Japanese so far) |

Nothing about browsing changed: navigation, tabs, bookmarks, history, downloads, settings and the engine are the stock code. The
new UI only decides how they look and where the buttons are.

## Install

CI builds two IPAs: **Actions → Modern UI → latest run → Artifacts** (the `.ipa` inside each zip):

| Artifact | Built from | Bundle identifier |
|---|---|---|
| `BlinkerFluid-ModernUI-ios12-stable-ipa` | the released **v.0.3.1 iOS 12 IPA** (SHA‑256 `e26dc439…5822eb`, checked by CI) | `com.nodesclock.blinkerfluid.ios12` (unchanged, so installing over the old app keeps tabs, bookmarks and settings) |
| `BlinkerFluid-ModernUI-ios12-jit-ipa` | the released **v.0.3.1 iOS 12 JIT IPA** (SHA‑256 `557dcf9c…e595e4`, checked by CI) | `com.nodesclock.blinkerfluid.ios12.jit` (a separate app with its own data; both can be installed) |

Both get the same change:

* the app executable gets one more `LC_LOAD_DYLIB`; it is signed again with `ldid` using its **original entitlements**
  (`increased-memory-limit`, `extended-virtual-addressing`, `get-task-allow`);
* `CFBundleVersion` becomes `0.3.1.<build>`.

Install it the way you installed the original IPA (jailbreak: unzip, copy `content_shell.app` to `/Applications`, `uicache`, or
your installer of choice). A free‑certificate sideload strips the entitlements and does not work for the stock app either.

### JavaScript engine speed

*Settings → JavaScript Engine* is not a list of engines to install: it chooses how far V8 may compile JavaScript, and it only
has an effect in the **JIT build** (the stable build always runs V8's `--jitless` interpreter and shows rows 2–5 greyed out with
"Requires the JIT build"; the two builds are the same binary and differ only in the bundle identifier).

| Tier (name in the list) | What V8 may do | Flags the engine passes |
|---|---|---|
| 1 Interpreter | no compiled code | `--no-sparkplug --regexp-interpret-all --wasm-jitless --disable-optimizing-compilers` |
| 2 Baseline JIT | + Sparkplug | `--sparkplug --regexp-interpret-all --wasm-jitless --disable-optimizing-compilers` |
| 3 Balanced JIT | + Maglev and the regexp compiler | `--maglev-as-top-tier --wasm-jitless` |
| 4 Full JIT (default) | + TurboFan | `--wasm-jitless` |
| 5 Full JIT + WebAssembly | + the WebAssembly compilers | (none) |

At launch the JIT build asks whether generated code may run, and silently falls back to the jitless interpreter if not
(`shell_main_delegate.cc`). It may run when **either**

* the process is "debugged" (`CS_DEBUGGED`): the app asks Dopamine's `libjailbreak` for it (iOS 15+), or TrollStore's
  "Open with JIT" sets it; **or**
* two probes show that the kernel lets the process execute memory it wrote itself (the palera1n path – which jailbreaks on
  iOS 12 pass is not known here).

After a crash with SIGILL / SIGBUS / SIGSEGV / SIGTRAP in tier 2 or higher the engine steps down one tier at the next launch.
The release build has no JIT lines in `blink_boot.log`, and the list shows the tier that was *chosen*, so nothing on screen says
whether JIT is really running. The upstream issues about iOS 12.5 are still open: #21 (iPad mini 2: the JIT build crashes on
every site, the jitless one works but is slow; a fix was promised for v.0.3.2, not released yet) and #27 (iPad Air 1: crashes
after a few seconds with both builds).

To find out on your device, use the menu's **JavaScript Speed Test**: it opens a page that times four small workloads and prints
a TOTAL (lower is faster). Run it in the stable build, then in the JIT build once per tier (quit and reopen the app after
changing the tier); if the numbers do not drop, JIT is not active and the stable build is the better choice. On a 1 GB iPod touch,
*Baseline* or *Balanced* are the tiers to try first – *Full* compiles the most and needs the most memory.

### If something is wrong

* **The app crashes right after start** – nothing to do: if the previous launch did not get through its first 3 seconds with the new screen up the layer
  stays off for one launch, and after two such launches it stays off until you delete `ModernUI-safe-mode.txt` (see below). One
  screen that keeps failing (address entry, tab grid, menu) falls back to the stock screen on its own.
* **Turn it off by hand** – menu → **Modern UI** (last row), or create a file called `disable-modern-ui` in the app's folder. In
  the Files app: *On My iPod → Blinker Fluid*; duplicate `ModernUI.log` and rename the copy.
* **Turn it on again** – delete `disable-modern-ui` / `ModernUI-safe-mode.txt` there, or create `enable-modern-ui` (resets the guard).
* **Japanese input misbehaves** – create a file called `disable-ime-fix` in the same folder (the input hooks stay off at the next
  launch; the rest of the new UI is unaffected) and send `ModernUI.log`.
* **The Return key misbehaves** – create `disable-return-fix` in the same folder: the Return key goes back to typing a line break
  (the Japanese input fix stays). The app writes this file by itself if it ended twice right after a Return key press; delete
  it to try again.
* **Report a problem** – send `ModernUI.log` from the same folder. It lists which hooks were installed and why anything was skipped.
  While typing in a web page it also records what the keyboard asked for (`ime:` lines – only lengths and counts, never the text).

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
* **Japanese / Chinese / Korean input** (`Sources/Hooks/BKIME.m`, contract `BKContractIME.inc`). The engine's text input view
  (`RenderWidgetUIView`, a `UITextInput`) always answered `-markedTextRange` with nil, i.e. "nothing is being composed". The iOS
  keyboard relies on that answer: it then treats every key as the first one (only one kana fits before the text has to be
  confirmed) and the confirm key as a plain Return (a line break). The hooks answer it properly from what the engine already
  tracks (`-hasMarkedText`, `-markedText`) and give UIKit consistent positions inside the composition; everything else still goes
  to the engine. The simulator harness tests the logic against a replica of the view (`imetest`); the real keyboard needs a real
  device.
* **The Return key** (`BKIME.m`, contract `BKContractReturnKey.inc`). The software keyboard does not send a key press for
  Return, it sends the text `"\n"` (`-insertText:`), and the engine commits that text: a text area gets a line break, but the page
  never sees an Enter key – no `keydown` / `keypress`, so a search box or a "send on Enter" field does nothing, and a one-line
  field is not submitted. A hardware keyboard on iOS 17.4+ goes through `-handleKeyEntry:withCompletionHandler:`, which builds a
  real key event from a BrowserEngineKit `BEKeyEntry` and sends it to the page (keydown + keypress, then keyup). BrowserEngineKit
  does not exist below iOS 17.4, but that method only reads `state`, `timestamp` and `key.keyCode / characters / modifierFlags` of
  its argument and has no system text-input delegate to ask on iOS 12, so the hook for `-insertText:@"\n"` hands it a small
  stand-in with those properties (Down = 1, Up = 2, checked against the SDK header in CI). Not used while a composition is on
  screen (the confirm key only confirms), nor where the system has its own text-input delegate (iOS 17.4+). A marker file written
  before the key press and removed a few seconds later (two leftovers in a row switch the fix off) keeps a crash in the engine's
  key handling from repeating on every press. The simulator harness checks the calls the hook makes; whether the page then gets
  the Enter needs a real device.
* **Closing the only tab.** The stock code cannot close the last tab. The tab grid opens a new tab first and then closes the old
  one, so the result is the usual "one fresh tab".
* **The menu on iOS 12.** A stock navigation controller that was ever asked for its popover controller keeps presenting as a
  popover, so the menu sheet is shown by a new navigation controller that has never been one.
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
