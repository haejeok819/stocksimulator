import 'package:flutter/material.dart';
import 'package:stocksimulator/shared/utils/app_settings.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
          ],
        ),
      ),
    );
  }
}
