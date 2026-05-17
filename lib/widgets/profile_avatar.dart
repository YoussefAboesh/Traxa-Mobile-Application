// lib/widgets/profile_avatar.dart
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Circular profile avatar backed by an on-disk cache.
///
/// The image is downloaded from the server only the first time; every later
/// build is served instantly from the cache. After an upload/remove, call
/// [evict] so the next build re-fetches the changed image once.
class ProfileAvatar extends StatelessWidget {
  /// Full URL of the avatar endpoint (e.g. `<base>/api/student/avatar/<id>`).
  final String url;

  /// Name used to render the fallback initial when there is no photo.
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

  /// Drops every cached copy of [url] so the next load fetches it fresh.
  /// Call this right after a successful avatar upload or removal.
  ///
  /// Evicting only the disk cache isn't enough — Flutter keeps the decoded
  /// image in its in-memory [ImageCache], so the old photo would still show.
  /// We clear both, plus the live-image references.
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
          // No spinner flash: show the initial while loading and on error
          // (a 404 simply means the user has no photo yet).
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
          // Guard against size <= 0 (e.g. ScreenUtil not ready on the first
          // frame), which would make fontSize 0 and trip Flutter's
          // 'fontSize > 0' assertion in StrutStyle.
          fontSize: (size * 0.4).clamp(1.0, double.infinity),
          fontWeight: FontWeight.bold,
          color: initialColor,
        ),
      ),
    );
  }
}
