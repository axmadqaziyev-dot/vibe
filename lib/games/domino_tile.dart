import 'package:flutter/material.dart';

import '../ui/vibe_design.dart';
import 'domino_engine.dart';

/// Domino daşının görünüşü — nöqtələr həqiqi domino kimi düzülür.
class DominoTileView extends StatelessWidget {
  const DominoTileView({
    super.key,
    required this.tile,
    this.horizontal = false,
    this.highlighted = false,
  });

  final PlacedTile tile;

  /// Masada uzununa, əldə isə dik durur.
  final bool horizontal;

  /// Oynanıla bilən daş işıqlanır.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final width = horizontal ? 60.0 : 44.0;
    final height = horizontal ? 30.0 : 86.0;

    final halves = [
      _Half(value: tile.left),
      _Half(value: tile.right),
    ];

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xfff4f1fb),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: highlighted ? vPink : const Color(0xffcfc6e6),
          width: highlighted ? 2 : 1,
        ),
        boxShadow: highlighted
            ? [BoxShadow(color: vPink.withValues(alpha: .35), blurRadius: 10)]
            : const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        children: [
          Expanded(child: halves[0]),
          // Ortadakı ayırıcı xətt.
          Container(
            width: horizontal ? 1 : double.infinity,
            height: horizontal ? double.infinity : 1,
            color: const Color(0xffcfc6e6),
          ),
          Expanded(child: halves[1]),
        ],
      ),
    );
  }
}

/// Daşın bir yarısı — 0-dan 6-ya qədər nöqtə düzülüşü.
class _Half extends StatelessWidget {
  const _Half({required this.value});

  final int value;

  /// Hər rəqəm üçün 3x3 şəbəkədə hansı xanalarda nöqtə var.
  static const Map<int, List<int>> _layout = {
    0: [],
    1: [4],
    2: [0, 8],
    3: [0, 4, 8],
    4: [0, 2, 6, 8],
    5: [0, 2, 4, 6, 8],
    6: [0, 2, 3, 5, 6, 8],
  };

  @override
  Widget build(BuildContext context) {
    final cells = _layout[value] ?? const <int>[];

    return Padding(
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final dot = (constraints.biggest.shortestSide / 4).clamp(3.0, 7.0);

          return GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            itemCount: 9,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
            ),
            itemBuilder: (context, i) => Center(
              child: cells.contains(i)
                  ? Container(
                      width: dot,
                      height: dot,
                      decoration: const BoxDecoration(
                        color: Color(0xff2a1f3d),
                        shape: BoxShape.circle,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
