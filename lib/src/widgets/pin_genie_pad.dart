import 'dart:math';

import 'package:flutter/material.dart';

import '../state/app_lock_controller.dart';

class PinGeniePad extends StatefulWidget {
  const PinGeniePad({
    super.key,
    required this.onBucketSelected,
    this.randomize = true,
    this.tileStyle = PinGenieTileStyle.randomMaterial,
    this.tileColors,
    this.tileForegroundColors,
  });

  final ValueChanged<Set<String>> onBucketSelected;
  final bool randomize;
  final PinGenieTileStyle tileStyle;
  final List<Color>? tileColors;
  final List<Color>? tileForegroundColors;

  @override
  State<PinGeniePad> createState() => PinGeniePadState();
}

class PinGeniePadState extends State<PinGeniePad> {
  final _random = Random.secure();
  late List<_GenieBucket> _buckets;

  @override
  void initState() {
    super.initState();
    _buckets = _buildBuckets();
  }

  @override
  void didUpdateWidget(covariant PinGeniePad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tileStyle != widget.tileStyle || oldWidget.randomize != widget.randomize) {
      _buckets = _buildBuckets();
    }
  }

  void shuffle() {
    setState(() {
      _buckets = _buildBuckets();
    });
  }

  List<_GenieBucket> _buildBuckets() {
    final digits = List<String>.generate(10, (index) => index.toString());
    final bucketSizes = <int>[3, 3, 2, 2];
    final directions = <_GenieDirection>[
      const _GenieDirection('North', Icons.north_rounded),
      const _GenieDirection('East', Icons.east_rounded),
      const _GenieDirection('South', Icons.south_rounded),
      const _GenieDirection('West', Icons.west_rounded),
    ];
    final tones = <int>[0, 1, 2, 0];
    final shapes = List<_TileShape>.of(_shapesForStyle(widget.tileStyle));

    if (widget.randomize) {
      digits.shuffle(_random);
      bucketSizes.shuffle(_random);
      directions.shuffle(_random);
      tones.shuffle(_random);
      shapes.shuffle(_random);
    }

    var cursor = 0;
    final entries = <_GenieBucket>[];
    for (var index = 0; index < bucketSizes.length; index++) {
      final size = bucketSizes[index];
      final displayDigits = digits.sublist(cursor, cursor + size);
      cursor += size;

      if (widget.randomize) {
        displayDigits.shuffle(_random);
      } else {
        displayDigits.sort();
      }

      entries.add(
        _GenieBucket(
          digits: displayDigits.toSet(),
          displayDigits: List.unmodifiable(displayDigits),
          label: directions[index].label,
          icon: directions[index].icon,
          toneIndex: tones[index],
          shape: shapes[index],
        ),
      );
    }

    if (widget.randomize) entries.shuffle(_random);
    return List.unmodifiable(entries);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : MediaQuery.sizeOf(context).width - 44;
        final maxSide = widget.tileStyle == PinGenieTileStyle.compact ? 148.0 : 176.0;
        final side = min(max((availableWidth - 14) / 2, 118.0), maxSide);
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 14,
          runSpacing: 14,
          children: List.generate(_buckets.length, (index) {
            final bucket = _buckets[index];
            return _GenieTile(
              key: ValueKey('${bucket.label}-${bucket.displayDigits.join()}-${bucket.toneIndex}'),
              side: side,
              label: bucket.label,
              icon: bucket.icon,
              digits: bucket.displayDigits.join('  '),
              color: _tileColor(colorScheme, bucket.toneIndex),
              foreground: _tileForeground(colorScheme, bucket.toneIndex),
              shape: bucket.shape,
              onTap: () {
                widget.onBucketSelected(Set<String>.from(bucket.digits));
                shuffle();
              },
            );
          }),
        );
      },
    );
  }


  List<_TileShape> _shapesForStyle(PinGenieTileStyle style) {
    return switch (style) {
      PinGenieTileStyle.roundedSquare => const [
          _TileShape(0.22, 0.22, 0.22, 0.22),
          _TileShape(0.22, 0.22, 0.22, 0.22),
          _TileShape(0.22, 0.22, 0.22, 0.22),
          _TileShape(0.22, 0.22, 0.22, 0.22),
        ],
      PinGenieTileStyle.circle => const [
          _TileShape(0.50, 0.50, 0.50, 0.50),
          _TileShape(0.50, 0.50, 0.50, 0.50),
          _TileShape(0.50, 0.50, 0.50, 0.50),
          _TileShape(0.50, 0.50, 0.50, 0.50),
        ],
      PinGenieTileStyle.compact => const [
          _TileShape(0.18, 0.18, 0.18, 0.18),
          _TileShape(0.18, 0.18, 0.18, 0.18),
          _TileShape(0.18, 0.18, 0.18, 0.18),
          _TileShape(0.18, 0.18, 0.18, 0.18),
        ],
      PinGenieTileStyle.expressiveBlob || PinGenieTileStyle.randomMaterial => const [
          _TileShape(0.30, 0.44, 0.42, 0.30),
          _TileShape(0.46, 0.28, 0.32, 0.44),
          _TileShape(0.34, 0.42, 0.28, 0.48),
          _TileShape(0.42, 0.34, 0.46, 0.28),
        ],
    };
  }

  Color _tileColor(ColorScheme colorScheme, int toneIndex) {
    final custom = widget.tileColors;
    if (custom != null && custom.isNotEmpty) {
      return custom[toneIndex % custom.length];
    }
    return switch (toneIndex % 3) {
      1 => colorScheme.secondaryContainer,
      2 => colorScheme.tertiaryContainer,
      _ => colorScheme.primaryContainer,
    };
  }

  Color _tileForeground(ColorScheme colorScheme, int toneIndex) {
    final custom = widget.tileForegroundColors;
    if (custom != null && custom.isNotEmpty) {
      return custom[toneIndex % custom.length];
    }
    return switch (toneIndex % 3) {
      1 => colorScheme.onSecondaryContainer,
      2 => colorScheme.onTertiaryContainer,
      _ => colorScheme.onPrimaryContainer,
    };
  }
}

class _GenieBucket {
  const _GenieBucket({
    required this.digits,
    required this.displayDigits,
    required this.label,
    required this.icon,
    required this.toneIndex,
    required this.shape,
  });

  final Set<String> digits;
  final List<String> displayDigits;
  final String label;
  final IconData icon;
  final int toneIndex;
  final _TileShape shape;
}

class _GenieDirection {
  const _GenieDirection(this.label, this.icon);

  final String label;
  final IconData icon;
}

class _TileShape {
  const _TileShape(this.topLeft, this.topRight, this.bottomLeft, this.bottomRight);

  final double topLeft;
  final double topRight;
  final double bottomLeft;
  final double bottomRight;
}

class _GenieTile extends StatefulWidget {
  const _GenieTile({
    super.key,
    required this.side,
    required this.label,
    required this.icon,
    required this.digits,
    required this.color,
    required this.foreground,
    required this.shape,
    required this.onTap,
  });

  final double side;
  final String label;
  final IconData icon;
  final String digits;
  final Color color;
  final Color foreground;
  final _TileShape shape;
  final VoidCallback onTap;

  @override
  State<_GenieTile> createState() => _GenieTileState();
}

class _GenieTileState extends State<_GenieTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1,
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOutBack,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          width: widget.side,
          height: widget.side,
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(widget.side * widget.shape.topLeft),
              topRight: Radius.circular(widget.side * widget.shape.topRight),
              bottomLeft: Radius.circular(widget.side * widget.shape.bottomLeft),
              bottomRight: Radius.circular(widget.side * widget.shape.bottomRight),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          child: Column(
            children: [
              SizedBox(
                height: 32,
                child: Center(
                  child: Icon(widget.icon, color: widget.foreground, size: 28),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.digits,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: widget.foreground,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.6,
                              height: 1,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 30,
                child: Center(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: widget.foreground.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w800,
                          height: 1,
                        ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
