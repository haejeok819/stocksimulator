import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/shared/auth/auth_controller.dart';
import 'package:stocksimulator/shared/auth/auth_providers.dart';
import 'package:stocksimulator/shared/auth/auth_state.dart';

class RecordsLoginGate extends ConsumerWidget {
  const RecordsLoginGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState state = ref.watch(authControllerProvider);
    final AuthController controller = ref.read(authControllerProvider.notifier);

    final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('기록을 보려면 로그인 필요', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            if (isWindows) ...<Widget>[
              const Text(
                'Windows에서는 로그인 기능을 지원하지 않습니다.\n모바일(Android/iOS)에서 이용해주세요.',
                textAlign: TextAlign.center,
              ),
            ] else ...<Widget>[
              const Text(
                '카카오/구글/네이버로 로그인하면 기기 변경해도 기록을 볼 수 있어요',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _SignInButton(label: '카카오로 로그인', onPressed: state.isLoading ? null : controller.signInWithKakao),
              const SizedBox(height: 8),
              _SignInButton(label: '구글로 로그인', onPressed: state.isLoading ? null : controller.signInWithGoogle),
              const SizedBox(height: 8),
              _SignInButton(label: '네이버로 로그인', onPressed: state.isLoading ? null : controller.signInWithNaver),
            ],
            if (state.isLoading && !isWindows) ...<Widget>[
              const SizedBox(height: 16),
              const Center(child: CircularProgressIndicator()),
            ],
            if (state.errorMessage != null && state.errorMessage!.isNotEmpty && !isWindows) ...<Widget>[
              const SizedBox(height: 12),
              Text(state.errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
            ],
          ],
        ),
      ),
    );
  }
}

class _SignInButton extends StatelessWidget {
  const _SignInButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton(onPressed: onPressed, child: Text(label)),
    );
  }
}
