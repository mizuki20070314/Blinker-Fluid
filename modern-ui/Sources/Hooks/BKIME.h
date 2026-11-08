// SPDX-License-Identifier: GPL-3.0-or-later
// Japanese / Chinese / Korean input in web pages.
//
// The engine's UITextInput implementation (RenderWidgetUIView) always answers -markedTextRange with nil: it never tells UIKit that
// a composition (text that is typed but not yet confirmed) exists.  The iOS keyboard relies on that answer: with nil it treats
// every key press as the first one (so only one kana fits before it has to be confirmed) and the confirm key as a plain
// Return (so it inserts a line break).  The hooks here answer it properly, using the composition the engine already tracks
// (-hasMarkedText / -markedText), and give UIKit consistent positions inside that composition.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Installs the hooks; does nothing (and logs why) when the engine's view differs from the expected one or when the file
// Documents/disable-ime-fix exists.
void BKInstallIMEHooks(void);

NS_ASSUME_NONNULL_END
