import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:stocksimulator/features/records/models/attempt_record.dart';
import 'package:stocksimulator/features/records/state/records_providers.dart';
import 'package:stocksimulator/shared/utils/number_format.dart';

class RecordsListView extends ConsumerWidget {
  const RecordsListView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AttemptRecord>> recordsAsync = ref.watch(recordsListProvider);

    return recordsAsync.when(
      data: (List<AttemptRecord> items) {
        if (items.isEmpty) {
          return const Center(child: Text('아직 기록이 없어요. 시뮬/배틀을 해보세요'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (BuildContext context, int index) {
            final AttemptRecord item = items[index];
            final bool isBattle = item.mode == 'BATTLE';
            final String title = isBattle
                ? '${item.nameA.isEmpty ? item.tickerA : item.nameA} vs ${item.nameB?.isEmpty ?? true ? item.tickerB ?? '-' : item.nameB}'
                : (item.nameA.isEmpty ? item.tickerA : item.nameA);
            final String period = '${_formatYmd(item.startYmd)} ~ ${_formatYmd(item.endYmd)}';
            final String createdAt = _formatCreatedAt(item.createdAtIso);
            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFF2A2A33), borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _modeBadge(item.mode),
                      const SizedBox(width: 8),
                      Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(period),
                  const SizedBox(height: 4),
                  Text(
                    isBattle
                        ? 'A ${AppNumberFormat.formatPercent(item.returnPctA)} / B ${AppNumberFormat.formatPercent(item.returnPctB ?? 0)}'
                        : '수익률 ${AppNumberFormat.formatPercent(item.returnPctA)}',
                  ),
                  const SizedBox(height: 4),
                  Text(createdAt, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Center(child: Text('기록을 불러오지 못했습니다.')),
    );
  }

  Widget _modeBadge(String mode) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: mode == 'BATTLE' ? const Color(0xFF6A5ACD) : const Color(0xFF2E8B57),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(mode, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  String _formatCreatedAt(String iso) {
    final DateTime? dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    return DateFormat('yyyy.MM.dd HH:mm').format(dt);
  }

  String _formatYmd(String ymd) {
    if (ymd.length != 8) return ymd;
    return '${ymd.substring(0, 4)}.${ymd.substring(4, 6)}.${ymd.substring(6, 8)}';
  }
}
