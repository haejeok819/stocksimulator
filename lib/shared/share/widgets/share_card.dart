import 'package:flutter/material.dart';
import 'package:stocksimulator/shared/share/share_payload.dart';

class SimulationShareCard extends StatelessWidget {
  const SimulationShareCard({super.key, required this.boundaryKey, required this.payload});

  final GlobalKey boundaryKey;
  final SimulationSharePayload payload;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF22222B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('그때 살걸', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _BadgePill(text: payload.badgeText),
            const SizedBox(height: 12),
            Text(payload.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(payload.returnText, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
            const SizedBox(height: 10),
            Text('${payload.investText} → ${payload.finalText}', style: const TextStyle(fontSize: 14, color: Color(0xFFDBDBE3))),
            const SizedBox(height: 6),
            Text(payload.periodText, style: const TextStyle(fontSize: 13, color: Color(0xFFA1A1A8))),
            const SizedBox(height: 14),
            const Text('나도 해보기', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8AB4FF))),
          ],
        ),
      ),
    );
  }
}

class BattleShareCard extends StatelessWidget {
  const BattleShareCard({super.key, required this.boundaryKey, required this.payload});

  final GlobalKey boundaryKey;
  final BattleSharePayload payload;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: boundaryKey,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF22222B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0x33FFFFFF)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Text('그때 살걸', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _BadgePill(text: payload.badgeText),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(child: _VsCell(title: payload.aTitle, value: payload.aReturnText)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text('VS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                Expanded(child: _VsCell(title: payload.bTitle, value: payload.bReturnText)),
              ],
            ),
            const SizedBox(height: 12),
            Text(payload.winnerText, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF8AB4FF))),
            const SizedBox(height: 8),
            Text(payload.periodText, style: const TextStyle(fontSize: 13, color: Color(0xFFA1A1A8))),
            const SizedBox(height: 14),
            const Text('나도 해보기', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF8AB4FF))),
          ],
        ),
      ),
    );
  }
}

class _BadgePill extends StatelessWidget {
  const _BadgePill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF2F3442),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(text, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _VsCell extends StatelessWidget {
  const _VsCell({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: const Color(0xFF2A2A33), borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFFA1A1A8))),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
