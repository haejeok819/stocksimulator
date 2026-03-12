import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/shared/auth/auth_controller.dart';
import 'package:stocksimulator/shared/auth/auth_providers.dart';
import 'package:stocksimulator/shared/auth/auth_state.dart';

class LoginGateCard extends ConsumerStatefulWidget {
  const LoginGateCard({
    super.key,
    required this.title,
    required this.description,
    this.buttonText = '구글로 로그인',
    this.icon,
    this.onLoginSuccess,
    this.padding,
    this.compact = false,
  });

  final String title;
  final String description;
  final String buttonText;
  final IconData? icon;
  final VoidCallback? onLoginSuccess;
  final EdgeInsetsGeometry? padding;
  final bool compact;

  @override
  ConsumerState<LoginGateCard> createState() => _LoginGateCardState();
}

class _LoginGateCardState extends ConsumerState<LoginGateCard> {
  @override
  Widget build(BuildContext context) {
    ref.listen<AuthState>(authControllerProvider, (AuthState? previous, AuthState next) {
      final bool wasSignedIn = previous?.isSignedIn ?? false;
      if (!wasSignedIn && next.isSignedIn) {
        widget.onLoginSuccess?.call();
      }
    });

    final AuthState state = ref.watch(authControllerProvider);
    final AuthController controller = ref.read(authControllerProvider.notifier);
    final bool isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

    return Container(
      padding: widget.padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2229),
        borderRadius: BorderRadius.circular(widget.compact ? 16 : 20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (widget.icon != null) ...<Widget>[
            Icon(widget.icon, color: Colors.white, size: widget.compact ? 22 : 26),
            SizedBox(height: widget.compact ? 8 : 12),
          ],
          Text(
            widget.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: widget.compact ? 17 : 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: widget.compact ? 6 : 8),
          Text(
            isWindows
                ? 'Windows에서는 로그인 기능을 지원하지 않습니다.\n모바일(Android/iOS)에서 이용해주세요.'
                : widget.description,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFFB0B4BC), height: 1.35),
          ),
          if (!isWindows) ...<Widget>[
            SizedBox(height: widget.compact ? 12 : 16),
            _LoginButton(
              text: widget.buttonText,
              loading: state.isLoading,
              onPressed: state.isLoading ? null : controller.signInWithGoogle,
            ),
          ],
          if (state.errorMessage != null && state.errorMessage!.isNotEmpty && !isWindows) ...<Widget>[
            SizedBox(height: widget.compact ? 8 : 10),
            Text(
              state.errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ],
        ],
      ),
    );
  }
}

class _LoginButton extends StatelessWidget {
  const _LoginButton({required this.text, required this.loading, required this.onPressed});

  final String text;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: loading
            ? const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.login_rounded, size: 18),
        label: Text(text),
      ),
    );
  }
}

Future<bool> showLoginRequiredBottomSheet(
  BuildContext context, {
  required String title,
  required String description,
  String buttonText = '구글로 로그인',
  IconData icon = Icons.lock_outline_rounded,
}) async {
  final bool? result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext context) {
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              LoginGateCard(
                title: title,
                description: description,
                buttonText: buttonText,
                icon: icon,
                compact: true,
                onLoginSuccess: () => Navigator.of(context).pop(true),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('닫기'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );

  return result ?? false;
}
