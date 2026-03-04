import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:stocksimulator/shared/state/ads_removed_provider.dart';
import 'package:stocksimulator/shared/utils/app_settings.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final TextEditingController _codeController = TextEditingController();

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _applyCode() async {
    final String normalized = _codeController.text.trim().toLowerCase();
    if (normalized == 'noad2026') {
      await ref.read(adsRemovedProvider.notifier).setAdsRemoved(true);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('테스트 해주셔서 감사합니다. 광고 제거가 됩니다.')),
      );
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('코드가 올바르지 않습니다')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<bool> adsRemovedAsync = ref.watch(adsRemovedProvider);
    final bool adsRemoved = adsRemovedAsync.valueOrNull ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ValueListenableBuilder<bool>(
              valueListenable: AppSettings.chartMotionEnabled,
              builder: (BuildContext context, bool enabled, _) {
                return SwitchListTile(
                  title: const Text('차트 모션'),
                  subtitle: Text(enabled ? 'ON' : 'OFF'),
                  value: enabled,
                  onChanged: (bool value) {
                    AppSettings.chartMotionEnabled.value = value;
                  },
                );
              },
            ),
            const Divider(),
            ListTile(
              title: const Text('데이터 출처'),
              subtitle: const Text(AppSettings.dataSource),
            ),
            ListTile(
              title: const Text('버전'),
              subtitle: const Text(AppSettings.dataVersion),
            ),
            const Divider(),
            const Text('광고 제거 코드', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Text(
              adsRemoved ? '광고 제거 적용됨 ✅' : '현재 광고 표시 중',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _codeController,
              enabled: !adsRemoved,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: '코드를 입력하세요',
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: adsRemoved ? null : _applyCode,
              child: const Text('적용'),
            ),
          ],
        ),
      ),
    );
  }
}
