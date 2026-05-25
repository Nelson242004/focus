import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/custom_profile_icon_service.dart';
import '../utils/profile_icon_access.dart';

class FocusProfileIconImage extends StatelessWidget {
  final String asset;
  final double? width;
  final double? height;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final WidgetBuilder? placeholderBuilder;

  const FocusProfileIconImage({
    super.key,
    required this.asset,
    this.width,
    this.height,
    this.fit = BoxFit.contain,
    this.filterQuality = FilterQuality.high,
    this.placeholderBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (asset == customProfileIconAsset) {
      return FutureBuilder<Uint8List?>(
        future: CustomProfileIconService.loadBytes(),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null || bytes.isEmpty) {
            return placeholderBuilder?.call(context) ??
                _fallback(context, Icons.person_rounded);
          }
          return Image.memory(
            bytes,
            width: width,
            height: height,
            fit: fit,
            filterQuality: filterQuality,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => _fallback(
              context,
              Icons.image_not_supported_rounded,
            ),
          );
        },
      );
    }

    return Image.asset(
      asset,
      width: width,
      height: height,
      fit: fit,
      filterQuality: filterQuality,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => Image.asset(
        defaultProfileIconAsset,
        width: width,
        height: height,
        fit: fit,
        filterQuality: filterQuality,
      ),
    );
  }

  Widget _fallback(BuildContext context, IconData icon) {
    return SizedBox(
      width: width,
      height: height,
      child: Icon(
        icon,
        size: ((width ?? height ?? 72) * 0.42).clamp(24, 96).toDouble(),
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}
