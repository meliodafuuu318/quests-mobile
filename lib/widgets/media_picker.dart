import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';

/// A single selected media file with its type
class MediaFile {
  final XFile file;
  final bool isVideo;
  MediaFile({required this.file, required this.isVideo});
}

/// Compact media attachment bar shown at the bottom of post/comment composers.
/// Call [MediaPickerBar.buildPreview] to render thumbnails above the bar.
class MediaPickerBar extends StatelessWidget {
  final List<MediaFile> files;
  final VoidCallback onPickImage;
  final VoidCallback onPickVideo;
  final void Function(int) onRemove;
  final int maxFiles;

  const MediaPickerBar({
    super.key,
    required this.files,
    required this.onPickImage,
    required this.onPickVideo,
    required this.onRemove,
    this.maxFiles = 4,
  });

  bool get _canAdd => files.length < maxFiles;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Btn(
          icon: Icons.image_outlined,
          label: 'Photo',
          color: AppTheme.cyan,
          enabled: _canAdd,
          onTap: onPickImage,
        ),
        const SizedBox(width: 8),
        _Btn(
          icon: Icons.videocam_outlined,
          label: 'Video',
          color: AppTheme.violet,
          enabled: _canAdd,
          onTap: onPickVideo,
        ),
        if (files.isNotEmpty) ...[
          const SizedBox(width: 8),
          Text(
            '${files.length}/$maxFiles',
            style: AppTheme.label(color: AppTheme.textMuted, size: 11),
          ),
        ],
      ],
    );
  }

  /// Horizontal scrollable row of thumbnails with ✕ remove buttons.
  static Widget buildPreview(List<MediaFile> files, void Function(int) onRemove) {
    if (files.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
        itemCount: files.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = files[i];
          return Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: f.isVideo
                    ? Container(
                        width: 90,
                        height: 90,
                        color: AppTheme.surfaceElevated,
                        alignment: Alignment.center,
                        child: const Icon(Icons.play_circle_outline,
                            color: AppTheme.violet, size: 36),
                      )
                    : Image.file(
                        File(f.file.path),
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                      ),
              ),
              // Remove button
              Positioned(
                top: 3,
                right: 3,
                child: GestureDetector(
                  onTap: () => onRemove(i),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.bg.withOpacity(0.85),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 12),
                  ),
                ),
              ),
              // Video badge
              if (f.isVideo)
                Positioned(
                  bottom: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.violetDim,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: AppTheme.violet.withOpacity(0.4)),
                    ),
                    child: Text('VID', style: AppTheme.label(color: AppTheme.violet, size: 8)),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Displays server-returned media (URLs/filepaths) with lightbox tap.
class MediaGallery extends StatelessWidget {
  final List<dynamic> media; // List of {filepath: String}
  final String baseUrl;

  const MediaGallery({
    super.key,
    required this.media,
    this.baseUrl = 'http://10.54.172.137:8000',
  });

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) return const SizedBox.shrink();

    final items = media.cast<Map<String, dynamic>>();
    bool isVideo(dynamic path) =>
        path.toString().toLowerCase().endsWith('.mp4') ||
        path.toString().toLowerCase().endsWith('.mov') ||
        path.toString().toLowerCase().endsWith('.webm');

    if (items.length == 1) {
      return _MediaTile(
        path: items[0]['filepath'].toString(),
        isVideo: isVideo(items[0]['filepath']),
        baseUrl: baseUrl,
        fullWidth: true,
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: items.length > 4 ? 4 : items.length,
      itemBuilder: (_, i) {
        final more = i == 3 && items.length > 4;
        return Stack(
          fit: StackFit.expand,
          children: [
            _MediaTile(
              path: items[i]['filepath'].toString(),
              isVideo: isVideo(items[i]['filepath']),
              baseUrl: baseUrl,
            ),
            if (more)
              Container(
                color: AppTheme.bg.withOpacity(0.7),
                alignment: Alignment.center,
                child: Text(
                  '+${items.length - 3}',
                  style: AppTheme.mono(color: Colors.white, size: 22),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MediaTile extends StatelessWidget {
  final String path;
  final bool isVideo;
  final String baseUrl;
  final bool fullWidth;

  const _MediaTile({
    required this.path,
    required this.isVideo,
    required this.baseUrl,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = path.startsWith('http') ? path : '$baseUrl$path';

    return GestureDetector(
      onTap: () => _showLightbox(context, url, isVideo),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: isVideo
            ? Container(
                color: AppTheme.surfaceElevated,
                width: fullWidth ? double.infinity : null,
                height: fullWidth ? 220 : null,
                alignment: Alignment.center,
                child: const Icon(Icons.play_circle_outline,
                    color: AppTheme.violet, size: 48),
              )
            : Image.network(
                url,
                fit: BoxFit.cover,
                width: fullWidth ? double.infinity : null,
                height: fullWidth ? 220 : null,
                errorBuilder: (_, __, ___) => Container(
                  color: AppTheme.surfaceElevated,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined,
                      color: AppTheme.textMuted, size: 36),
                ),
              ),
      ),
    );
  }

  void _showLightbox(BuildContext context, String url, bool isVideo) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (_) => GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: isVideo
              ? Center(
                  child: Text('Video: $url',
                      style: const TextStyle(color: Colors.white)),
                )
              : InteractiveViewer(
                  child: Image.network(url, fit: BoxFit.contain),
                ),
        ),
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  const _Btn({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: enabled ? color.withOpacity(0.1) : AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: enabled ? color.withOpacity(0.35) : AppTheme.border,
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: enabled ? color : AppTheme.textMuted, size: 15),
          const SizedBox(width: 5),
          Text(label,
              style: AppTheme.label(
                color: enabled ? color : AppTheme.textMuted,
                size: 12,
              )),
        ]),
      ),
    );
  }
}