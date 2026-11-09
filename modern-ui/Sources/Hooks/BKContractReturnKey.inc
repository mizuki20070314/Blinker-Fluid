// SPDX-License-Identifier: GPL-3.0-or-later
//
// What the Return-key fix needs from the engine's web view, RenderWidgetUIView (see BKIME.m).  A separate list from
// BKContractIME.inc: if something here differs in a future engine build, only the Return-key fix stays off - the Japanese input
// fix is unaffected.  Same format; checked at launch (BKIME.m) and in CI (tools/check_contract.py).

BK_METHOD("RenderWidgetUIView", "handleKeyEntry:withCompletionHandler:", "v@:@@?")
BK_METHOD("RenderWidgetUIView", "asyncInputDelegate", "@@:")
BK_METHOD("RenderWidgetUIView", "insertText:", "v@:@")
