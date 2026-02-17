import 'dart:convert';
import 'dart:io';

import 'package:stocksimulator/data/models/simulation_result.dart';

class HistoryRepository {
  Future<List<SimulationResult>> load() async {
    final File file = await _file();
    if (!await file.exists()) {
      return <SimulationResult>[];
    }
    final List<dynamic> list = jsonDecode(await file.readAsString()) as List<dynamic>;
    return list
        .whereType<Map<String, dynamic>>()
        .map((Map<String, dynamic> row) => SimulationResult.fromJson(row))
        .toList();
  }

  Future<void> append(SimulationResult item) async {
    final List<SimulationResult> old = await load();
    final List<SimulationResult> merged = <SimulationResult>[item, ...old].take(100).toList();
    final File file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(merged.map((SimulationResult e) => e.toJson()).toList()));
  }

  Future<File> _file() async {
    return File('${Directory.systemTemp.path}/stocksim-cache/history.json');
  }
}
