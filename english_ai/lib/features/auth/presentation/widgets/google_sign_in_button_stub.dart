import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../shared/widgets/app_button.dart';

/// Default (mobile/desktop) implementation of the Google Sign-In button.
///
/// Uses the native Google Sign-In flow and exchanges the signed-in account
/// for an ID token via `account.authentication`.
class GoogleSignInButton extends StatelessWidget {
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

  Future<void> _handlePressed() async {
    if (!AppConfig.isGoogleSignInConfigured) {
      onError(
        Exception(
          'Google Sign-In chưa được cấu hình. Thêm --dart-define=GOOGLE_CLIENT_ID=...',
        ),
      );
      return;
    }

    try {
      final googleSignIn = GoogleSignIn(
        scopes: const ['email', 'profile'],
        serverClientId: AppConfig.googleClientId,
      );
      final account = await googleSignIn.signIn();
      if (account == null) {
        return; // User cancelled.
      }

      final auth = await account.authentication;
      final idToken = auth.idToken;
      if (idToken == null) {
        onError(
          Exception('Không lấy được ID token từ Google. Kiểm tra cấu hình.'),
        );
        return;
      }

      await onIdToken(idToken);
    } catch (e) {
      if (e.toString().toLowerCase().contains('cancel')) return;
      onError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppButton(
      text: 'Continue with Google',
      isOutlined: true,
      icon: Icons.g_mobiledata_rounded,
      isLoading: isLoading,
      width: width,
      onPressed: isLoading ? null : _handlePressed,
    );
  }
}
