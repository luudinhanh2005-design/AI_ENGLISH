/// Platform-conditional Google Sign-In button.
///
/// On the web it renders the official Google Identity Services button (the
/// only reliable way to obtain an `idToken`); on mobile/desktop it uses the
/// native sign-in flow.
library;

export 'google_sign_in_button_stub.dart'
    if (dart.library.js_interop) 'google_sign_in_button_web.dart';
