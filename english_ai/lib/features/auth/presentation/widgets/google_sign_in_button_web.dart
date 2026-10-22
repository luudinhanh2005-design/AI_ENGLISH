import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:google_sign_in_web/web_only.dart' as gsi_web;

import '../../../../core/constants/app_config.dart';

/// Web implementation of the Google Sign-In button.
///
/// On the web, `GoogleSignIn.signIn()` cannot reliably return an `idToken`.
/// The official approach is to render the Google Identity Services (GIS)
/// button and listen to `onCurrentUserChanged`; the resulting account can then
/// expose a valid `idToken` through `account.authentication`.
class GoogleSignInButton extends StatefulWidget {
  const GoogleSignInButton({
    super.key,
    this.isLoading = false,
    this.width,
    required this.onIdToken,
    required this.onError,
  });

  final bool isLoading;
  final double? width;
  final Future<void> Function(String idToken) onIdToken;
  final void Function(Object error) onError;

  @override
  State<GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<GoogleSignInButton> {
  StreamSubscription<GoogleSignInAccount?>? _subscription;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    if (AppConfig.isGoogleSignInConfigured) {
      _init();
    }
  }

  Future<void> _init() async {
    final googleSignIn = GoogleSignIn(
      clientId: AppConfig.googleClientId,
      scopes: const ['email', 'profile'],
    );

    _subscription = googleSignIn.onCurrentUserChanged.listen((account) async {
      if (account == null) return;
      try {
        final auth = await account.authentication;
        final idToken = auth.idToken;
        if (idToken == null) {
          widget.onError(
            Exception(
              'Không lấy được ID token từ Google. Kiểm tra cấu hình client ID.',
            ),
          );
          return;
        }
        await widget.onIdToken(idToken);
      } catch (e) {
        widget.onError(e);
      }
    });

    // Initialization must complete before `renderButton()` can be used, and it
    // wires the credential responses (which contain the idToken) to
    // `onCurrentUserChanged`.
    try {
      await googleSignIn.signInSilently();
    } catch (_) {
      // No cached session / initialization warning: the button still works.
    }

    if (mounted) {
      setState(() => _ready = true);
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.isGoogleSignInConfigured) {
      return SizedBox(
        width: widget.width ?? double.infinity,
        height: 50,
        child: OutlinedButton.icon(
          onPressed: () => widget.onError(
            'Chưa cấu hình GOOGLE_CLIENT_ID. Hãy chạy app bằng run.ps1 '
            '(hoặc thêm --dart-define=GOOGLE_CLIENT_ID=... --web-port 5000).',
          ),
          icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
          label: const Text('Continue with Google'),
        ),
      );
    }

    if (!_ready) {
      return const SizedBox(
        height: 50,
        child: Center(
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      );
    }

    return SizedBox(
      width: widget.width ?? double.infinity,
      height: 50,
      child: gsi_web.renderButton(
        configuration: gsi_web.GSIButtonConfiguration(
          type: gsi_web.GSIButtonType.standard,
          theme: gsi_web.GSIButtonTheme.outline,
          size: gsi_web.GSIButtonSize.large,
          text: gsi_web.GSIButtonText.continueWith,
          shape: gsi_web.GSIButtonShape.rectangular,
          logoAlignment: gsi_web.GSIButtonLogoAlignment.center,
        ),
      ),
    );
  }
}
