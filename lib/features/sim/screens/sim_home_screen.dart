import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:stocksimulator/data/models/stock_model.dart';
import 'package:stocksimulator/data/repositories/stock_repository.dart';
import 'package:stocksimulator/features/sim/screens/date_range_screen.dart';
import 'package:stocksimulator/features/sim/state/simulation_flow_state.dart';
import 'package:stocksimulator/shared/utils/slide_route.dart';

class SimHomeScreen extends StatefulWidget {
  const SimHomeScreen({super.key});

  @override
  State<SimHomeScreen> createState() => _SimHomeScreenState();
}

class _SimHomeScreenState extends State<SimHomeScreen> {
  final StockRepository _repository = StockRepository();
  final SimulationFlowState _flow = SimulationFlowState();
  final TextEditingController _searchController = TextEditingController();

  static const List<String> _placeholders = <String>[
    '삼성 vs 애플, 뭐가 더 올랐을까?',
    '테슬라 vs 엔비디아?',
    '코스피 5000의 주인공 삼성의 상승세는?',
    '10년동안 묵혀뒀다면 얼마를 벌었을까?',
    '코로나 때 샀더라면?',
  ];

  StockMarket _market = StockMarket.kr;
  String _query = '';

  bool get _safeMode {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.linux || TargetPlatform.macOS => true,
      _ => false,
    };
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _setMarket(StockMarket value) {
    if (_market == value) return;
    if (!_safeMode) {
      HapticFeedback.selectionClick();
    }
    setState(() {
      _market = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color bg = const Color(0xFF17171F);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        titleSpacing: 0,
        toolbarHeight: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[Color(0xFF22222D), Color(0xFF17171F)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _HeroSection(market: _market),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E28),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0x10FFFFFF)),
                  ),
                  child: Column(
                    children: <Widget>[
                      _MarketToggle(market: _market, onChanged: _setMarket),
                      const SizedBox(height: 10),
                      _PremiumSearchBar(
                        controller: _searchController,
                        query: _query,
                        safeMode: _safeMode,
                        placeholders: _placeholders,
                        onChanged: (String value) {
                          setState(() {
                            _query = value;
                          });
                        },
                        onClear: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: FutureBuilder<List<StockModel>>(
                    future: _repository.getTopStocks(market: _market, query: _query),
                    builder: (BuildContext context, AsyncSnapshot<List<StockModel>> snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final List<StockModel> stocks = snapshot.data ?? <StockModel>[];
                      if (stocks.isEmpty) {
                        return const Center(child: Text('데이터 없음', style: TextStyle(color: Color(0xFFA1A1A8))));
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: stocks.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (BuildContext context, int index) {
                          final StockModel stock = stocks[index];
                          return _PremiumStockCard(
                            stock: stock,
                            index: index,
                            reducedMotion: _safeMode,
                            onTap: () {
                              _flow.selectStock(stock);
                              Navigator.of(context).push(
                                buildRightSlideRoute(
                                  DateRangeScreen(
                                    repository: _repository,
                                    flowState: _flow,
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.market});

  final StockMarket market;

  @override
  Widget build(BuildContext context) {
    final String marketLabel = market == StockMarket.kr ? 'KR MARKET' : 'US MARKET';

    return Container(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 12),
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: const Alignment(0, -0.8),
          radius: 1.0,
          colors: <Color>[
            const Color(0xFF5677E7).withOpacity(0.20),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text('종목 선택', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('$marketLabel · Top 100', style: const TextStyle(fontSize: 14, color: Color(0xFFB5B5BE))),
          const SizedBox(height: 2),
          const Text('최근 업데이트: 오늘', style: TextStyle(fontSize: 12, color: Color(0xFFA1A1A8))),
        ],
      ),
    );
  }
}

class _MarketToggle extends StatelessWidget {
  const _MarketToggle({required this.market, required this.onChanged});

  final StockMarket market;
  final ValueChanged<StockMarket> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool krSelected = market == StockMarket.kr;

    return Container(
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFF232330),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Stack(
        children: <Widget>[
          IgnorePointer(
            child: AnimatedAlign(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: krSelected ? Alignment.centerLeft : Alignment.centerRight,
            child: Container(
              width: (MediaQuery.of(context).size.width - 36 - 6) / 2,
              decoration: BoxDecoration(
                color: const Color(0xFF5677E7),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(StockMarket.kr),
                  child: Center(
                    child: Text(
                      'KR',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: krSelected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => onChanged(StockMarket.us),
                  child: Center(
                    child: Text(
                      'US',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: !krSelected ? FontWeight.w800 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PremiumSearchBar extends StatefulWidget {
  const _PremiumSearchBar({
    required this.controller,
    required this.query,
    required this.safeMode,
    required this.placeholders,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final String query;
  final bool safeMode;
  final List<String> placeholders;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  State<_PremiumSearchBar> createState() => _PremiumSearchBarState();
}

class _PremiumSearchBarState extends State<_PremiumSearchBar> {
  final FocusNode _focusNode = FocusNode();
  Timer? _placeholderTimer;
  int _phIndex = 0;

  @override
  void initState() {
    super.initState();
    _placeholderTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || widget.query.isNotEmpty || widget.placeholders.isEmpty) return;
      setState(() {
        _phIndex = (_phIndex + 1) % widget.placeholders.length;
      });
    });
  }

  @override
  void didUpdateWidget(covariant _PremiumSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query.isNotEmpty && _phIndex != 0) {
      setState(() => _phIndex = 0);
    }
  }

  @override
  void dispose() {
    _placeholderTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool focused = _focusNode.hasFocus;
    final String placeholder = widget.placeholders.isEmpty ? '' : widget.placeholders[_phIndex % widget.placeholders.length];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A35),
        borderRadius: BorderRadius.circular(16),
        boxShadow: !widget.safeMode && focused
            ? <BoxShadow>[BoxShadow(color: const Color(0xFF5677E7).withOpacity(0.2), blurRadius: 10)]
            : <BoxShadow>[],
      ),
      child: Row(
        children: <Widget>[
          Icon(Icons.search, color: Colors.white.withOpacity(0.7)),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              onChanged: widget.onChanged,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
              cursorColor: const Color(0xFF5677E7),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                hintText: placeholder,
                hintStyle: const TextStyle(
                  color: Color(0xFFA1A1A8),
                  fontSize: 13,
                ),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: widget.query.isEmpty
                ? const SizedBox(width: 12)
                : GestureDetector(
                    key: const ValueKey<String>('clear-button'),
                    onTap: widget.onClear,
                    child: const Padding(
                      padding: EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 18, color: Color(0xCCFFFFFF)),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _PremiumStockCard extends StatefulWidget {
  const _PremiumStockCard({
    required this.stock,
    required this.index,
    required this.reducedMotion,
    required this.onTap,
  });

  final StockModel stock;
  final int index;
  final bool reducedMotion;
  final VoidCallback onTap;

  @override
  State<_PremiumStockCard> createState() => _PremiumStockCardState();
}

class _PremiumStockCardState extends State<_PremiumStockCard> {
  bool _pressed = false;

  Color _badgeColor() {
    if (widget.index == 0) return const Color(0x33F59E0B);
    if (widget.index == 1) return const Color(0x33266DD3);
    if (widget.index == 2) return const Color(0x3322C55E);
    return const Color(0x00000000);
  }

  @override
  Widget build(BuildContext context) {
    final String initial = widget.stock.displayName.isEmpty ? '?' : widget.stock.displayName.substring(0, 1);

    final Widget card = AnimatedScale(
      duration: const Duration(milliseconds: 120),
      scale: _pressed ? 0.98 : 1,
      child: AnimatedContainer(
        duration: widget.reducedMotion ? Duration.zero : Duration(milliseconds: 220 + (widget.index % 6) * 35),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, widget.reducedMotion ? 0 : 0, 0),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF24242F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x0FFFFFFF)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withOpacity(0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF353543),
                border: Border.all(color: const Color(0x1FFFFFFF)),
              ),
              child: Text(initial, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            if (widget.index < 3)
              Container(
                width: 8,
                height: 40,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(color: _badgeColor(), borderRadius: BorderRadius.circular(99)),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(widget.stock.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                    widget.stock.ticker,
                    style: const TextStyle(color: Color(0xFFA1A1A8), letterSpacing: 0.8),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white.withOpacity(0.55)),
          ],
        ),
      ),
    );

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: card,
    );
  }
}
