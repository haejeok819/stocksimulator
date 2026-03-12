import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/features/records/state/records_providers.dart';
import 'package:stocksimulator/features/records/widgets/records_list_view.dart';
import 'package:stocksimulator/shared/widgets/login_gate.dart';
import 'package:stocksimulator/shared/auth/auth_providers.dart';
import 'package:stocksimulator/shared/auth/auth_state.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AuthState authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('기록'),
        actions: <Widget>[
          if (authState.isSignedIn)
            IconButton(
              tooltip: '로그아웃',
              onPressed: authState.isLoading ? null : () => ref.read(authControllerProvider.notifier).signOut(),
              icon: const Icon(Icons.logout),
            ),
          if (authState.isSignedIn)
            IconButton(
              tooltip: '기록 초기화',
              onPressed: () async {
                final bool? confirmed = await showDialog<bool>(
                  context: context,
                  builder: (BuildContext context) {
                    return AlertDialog(
                      title: const Text('기록 초기화'),
                      content: const Text('현재 계정의 기록을 모두 삭제할까요?'),
                      actions: <Widget>[
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('취소'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('삭제'),
                        ),
                      ],
                    );
                  },
                );
                if (confirmed == true) {
                  ref.read(recordsControllerProvider).clearCurrentUserRecords();
                }
              },
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: authState.isSignedIn
          ? const RecordsListView()
          : const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: LoginGateCard(
                  title: '기록을 보려면 로그인 필요',
                  description: '로그인하면 기기 변경 후에도 기록을 확인할 수 있어요.',
                  buttonText: '구글로 로그인',
                  icon: Icons.history_rounded,
                ),
              ),
            ),
    );
  }
}
