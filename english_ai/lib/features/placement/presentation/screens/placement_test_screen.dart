import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../providers/placement_provider.dart';
import 'placement_intro_screen.dart';
import 'placement_result_screen.dart';
import 'placement_runner_screen.dart';

/// Entry point for the placement flow.
///
/// It shows the intro/mode picker when there is no active session, resumes an
/// in-progress session automatically, and replaces the whole flow with the
/// report once the backend finalises it.
class PlacementTestScreen extends ConsumerWidget {
  const PlacementTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(placementProvider);
    final notifier = ref.read(placementProvider.notifier);

    final result = state.result ?? state.session?.result;
    if (result != null) {
      return PlacementResultScreen(result: result);
    }

    final session = state.session;
    if (session != null) {
      if (session.completed) {
        return _LoadingScaffold(
          message: 'Đang tổng hợp kết quả...',
          onRefresh: notifier.refreshSession,
        );
      }
      return PlacementRunnerScreen(session: session);
    }

    if (!state.initialized || (state.isLoading && state.config == null)) {
      return const _LoadingScaffold(message: 'Đang chuẩn bị bài kiểm tra...');
    }

    if (state.config == null) {
      return Scaffold(
        backgroundColor: context.palette.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      color: AppColors.error, size: 48),
                  const SizedBox(height: 14),
                  Text(
                    state.errorMessage ??
                        'Không thể tải cấu hình bài kiểm tra trình độ.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: context.palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 20),
                  AppButton(
                    text: 'Thử lại',
                    onPressed: () => notifier.initialize(force: true),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/learn');
                      }
                    },
                    child: Text(
                      'Quay lại',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.palette.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return const PlacementIntroScreen();
  }
}

class _LoadingScaffold extends StatelessWidget {
  final String message;
  final VoidCallback? onRefresh;

  const _LoadingScaffold({required this.message, this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    color: AppColors.primary,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: context.palette.textSecondary,
                  ),
                ),
                if (onRefresh != null) ...[
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: onRefresh,
                    child: const Text('Làm mới'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
