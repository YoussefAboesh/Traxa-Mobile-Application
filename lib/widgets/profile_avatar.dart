import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class ProfileAvatar extends StatelessWidget {
  final String url;

  final String name;

  final double size;
  final Color initialColor;
  final Color backgroundColor;

  const ProfileAvatar({
    super.key,
    required this.url,
    required this.name,
    this.size = 100,
    this.initialColor = const Color(0xFF0EA5E9),
    this.backgroundColor = Colors.white,
  });

  static Future<void> evict(String url) async {
    try {
      await CachedNetworkImage.evictFromCache(url);
    } catch (_) {}
    try {
      final provider = CachedNetworkImageProvider(url);
      await provider.evict();
    } catch (_) {}
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
      ),
      child: ClipOval(
        child: CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          width: size,
          height: size,
          placeholder: (_, __) => _initial(),
          errorWidget: (_, __, ___) => _initial(),
        ),
      ),
    );
  }

  Widget _initial() {
    return Center(
      child: Text(
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?',
        style: TextStyle(
          fontSize: (size * 0.4).clamp(1.0, double.infinity),
          fontWeight: FontWeight.bold,
          color: initialColor,
        ),
      ),
    );
  }
}
