// SPDX-License-Identifier: GPL-3.0-or-later
//
// What the input-method (IME) fix needs from the engine's web view, RenderWidgetUIView (the UITextInput implementation of the
// released content_shell_framework).  Kept apart from BKContract.inc: if this class ever looks different, only the IME fix stays
// off - the rest of the modern UI is unaffected.  Same format; checked at launch (BKIME.m) and in CI (tools/check_contract.py).

BK_METHOD("RenderWidgetUIView", "markedTextRange", "@@:")
BK_METHOD("RenderWidgetUIView", "hasMarkedText", "B@:")
BK_METHOD("RenderWidgetUIView", "markedText", "@@:")
BK_METHOD("RenderWidgetUIView", "selectedTextRange", "@@:")
BK_METHOD("RenderWidgetUIView", "textInRange:", "@@:@")
BK_METHOD("RenderWidgetUIView", "offsetFromPosition:toPosition:", "q@:@@")
BK_METHOD("RenderWidgetUIView", "positionFromPosition:offset:", "@@:@q")
BK_METHOD("RenderWidgetUIView", "comparePosition:toPosition:", "q@:@@")
BK_METHOD("RenderWidgetUIView", "caretRectForPosition:", "{CGRect={CGPoint=dd}{CGSize=dd}}@:@")
BK_METHOD("RenderWidgetUIView", "firstRectForRange:", "{CGRect={CGPoint=dd}{CGSize=dd}}@:@")
BK_METHOD("RenderWidgetUIView", "textRangeFromPosition:toPosition:", "@@:@@")
BK_METHOD("RenderWidgetUIView", "setMarkedText:selectedRange:", "v@:@{_NSRange=QQ}")
BK_METHOD("RenderWidgetUIView", "unmarkText", "v@:")
BK_METHOD("RenderWidgetUIView", "insertText:", "v@:@")
BK_METHOD("RenderWidgetUIView", "replaceRange:withText:", "v@:@@")
