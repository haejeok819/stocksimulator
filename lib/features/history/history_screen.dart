import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/features/records/state/records_providers.dart';
import 'package:stocksimulator/features/records/widgets/records_list_view.dart';
import 'package:stocksimulator/features/records/widgets/records_login_gate.dart';
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
              onPressed: authState.isLoading ? null : () => ref.read(authControllerProvider.notifier).signOut(),
              icon: const Icon(Icons.logout),
            ),
          if (authState.isSignedIn)
            IconButton(
              onPressed: () => ref.read(recordsControllerProvider).clearCurrentUserRecords(),
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
        ],
      ),
      body: authState.isSignedIn ? const RecordsListView() : const RecordsLoginGate(),
    );
  }
}
