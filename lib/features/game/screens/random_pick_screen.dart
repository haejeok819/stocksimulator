import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:stocksimulator/app/theme/app_theme.dart';
import 'package:stocksimulator/data/models/price_year_data.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/game/screens/game_play_screen.dart';

class RandomPickScreen extends StatefulWidget {
  const RandomPickScreen({super.key, required this.betPoints, required this.isWindowsGuest});

  final int betPoints;
  final bool isWindowsGuest;

  @override
  State<RandomPickScreen> createState() => _RandomPickScreenState();
}

class _RandomPickScreenState extends State<RandomPickScreen> {
  final StockRepository _repository = StockRepository();
  final Random _random = Random();

  String _rollingText = '선택 중...';
  int _countdown = 0;
  StockModel? _pickedStock;
  List<PricePoint>? _pickedSeries;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _runFlow();
  }

  Future<void> _runFlow() async {
    try {
      final StockModel stock = await _pickRandomStock();
      final List<PricePoint> series = await _pickOneYearSeries(stock);
      if (!mounted) return;
      setState(() {
        _pickedStock = stock;
        _pickedSeries = series;
      });

      await _rollingAnimation(stock.displayName);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _countdown = 3;
      });

      while (_countdown > 0 && mounted) {
        await Future<void>.delayed(const Duration(milliseconds: 850));
        if (!mounted) return;
        setState(() => _countdown -= 1);
      }

      if (!mounted || _pickedSeries == null || _pickedStock == null) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: 'game_play'),
          builder: (_) => GamePlayScreen(
            betPoints: widget.betPoints,
            isWindowsGuest: widget.isWindowsGuest,
            stockName: _pickedStock!.displayName,
            points: _pickedSeries!,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '랜덤 선택에 실패했어요';
        _loading = false;
      });
    }
  }

  Future<void> _rollingAnimation(String finalText) async {
    final List<String> candidates = <String>['삼성전자', 'SK하이닉스', '금(KRX)', 'USD/KRW', 'NAVER', '현대차'];
    const int frameCount = 16;
    for (int i = 0; i < frameCount; i++) {
      await Future<void>.delayed(Duration(milliseconds: 45 + i * 12));
      if (!mounted) return;
      setState(() => _rollingText = candidates[_random.nextInt(candidates.length)]);
    }
    if (!mounted) return;
    setState(() => _rollingText = finalText);
    await Future<void>.delayed(const Duration(milliseconds: 300));
  }

  Future<StockModel> _pickRandomStock() async {
    final List<StockModel> all = await _repository.getTopStocks(assetType: AssetType.stockKR);
    final List<StockModel> available = all.where((StockModel e) => e.assetType == AssetType.stockKR || e.assetType == AssetType.gold || e.assetType == AssetType.fx).toList();
    if (available.isEmpty) {
      throw Exception('no stocks');
    }
    return available[_random.nextInt(available.length)];
  }

  Future<List<PricePoint>> _pickOneYearSeries(StockModel stock) async {
    final List<int> days = await _repository.loadTradingDays(assetType: stock.assetType, assetKey: stock.assetKey);
    if (days.length < 220) {
      throw Exception('not enough days');
    }

    for (int attempt = 0; attempt < 20; attempt++) {
      final int startIdx = _random.nextInt(max(1, days.length - 210));
      final DateTime startDate = _fromYmd(days[startIdx]);
      final DateTime endDate = startDate.add(const Duration(days: 365));
      final List<PricePoint> series = await _repository.loadRangeByAsset(
        assetType: stock.assetType,
        assetKey: stock.assetKey,
        start: startDate,
        end: endDate,
      );
      if (series.length >= 200) {
        return series;
      }
    }
    throw Exception('cannot pick range');
  }

  DateTime _fromYmd(int ymd) {
    final int y = ymd ~/ 10000;
    final int m = (ymd % 10000) ~/ 100;
    final int d = ymd % 100;
    return DateTime(y, m, d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: _error != null
            ? Text(_error!, style: const TextStyle(color: Colors.white))
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Text('랜덤 선택 중…', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
                      child: Text(_rollingText, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _pickedStock == null ? '종목을 고르고 있어요' : '오늘의 종목: ${_pickedStock!.displayName}',
                      style: const TextStyle(color: AppColors.helperText),
                    ),
                    const SizedBox(height: 4),
                    const Text('기간: 1년', style: TextStyle(color: AppColors.helperText)),
                    const SizedBox(height: 20),
                    if (_loading)
                      const CircularProgressIndicator()
                    else if (_countdown > 0)
                      Text('$_countdown', style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
      ),
    );
  }
}
