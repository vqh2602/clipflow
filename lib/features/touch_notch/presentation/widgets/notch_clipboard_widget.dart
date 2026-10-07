import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/providers.dart';
import '../../../../core/utils/color_parser.dart';
import '../../../clipboard_history/domain/clipboard_content_type.dart';
import '../../../clipboard_history/domain/clipboard_item.dart';
import '../../../clipboard_history/presentation/history_controller.dart';

class NotchClipboardWidget extends ConsumerStatefulWidget {
  const NotchClipboardWidget({
    super.key,
    required this.onItemPasted,
  });

  final ValueChanged<ClipboardItem> onItemPasted;

  @override
  ConsumerState<NotchClipboardWidget> createState() =>
      _NotchClipboardWidgetState();
}

class _NotchClipboardWidgetState extends ConsumerState<NotchClipboardWidget> {
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  String _selectedSection = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onCategorySelected(String sectionId) {
    setState(() => _selectedSection = sectionId);
    final historyNotifier = ref.read(historyControllerProvider.notifier);
    if (sectionId == 'all') {
      historyNotifier.selectSection(HistorySection.all);
    } else if (sectionId == 'pinned') {
      historyNotifier.selectSection(HistorySection.pinned);
    } else {
      historyNotifier.selectSection(
        HistorySection.collection,
        collectionId: sectionId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final history = ref.watch(historyControllerProvider);
    final collections =
        ref.watch(collectionsControllerProvider).value ?? const [];
    final items = history.visibleItems;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Top Toolbar inside Notch: Search + Filter Categories
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            children: [
              // Search input
              SizedBox(
                width: 140,
                height: 28,
                child: CupertinoTextField(
                  controller: _searchController,
                  placeholder: 'Tìm kiếm',
                  placeholderStyle: const TextStyle(
                    color: Color(0x88FFFFFF),
                    fontSize: 12,
                  ),
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 12,
                  ),
                  prefix: const Padding(
                    padding: EdgeInsets.only(left: 7),
                    child: Icon(
                      CupertinoIcons.search,
                      size: 13,
                      color: Color(0x99FFFFFF),
                    ),
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0x22FFFFFF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  onChanged: (text) {
                    ref.read(historyControllerProvider.notifier).search(text);
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Filter category chips (Tất cả, Đã ghim, Collections...)
              Expanded(
                child: SizedBox(
                  height: 26,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: [
                      _CategoryChip(
                        label: 'Tất cả ${items.length}',
                        icon: CupertinoIcons.clock,
                        isSelected: _selectedSection == 'all',
                        onTap: () => _onCategorySelected('all'),
                      ),
                      const SizedBox(width: 5),
                      _CategoryChip(
                        label: 'Đã ghim',
                        icon: CupertinoIcons.pin_fill,
                        isSelected: _selectedSection == 'pinned',
                        onTap: () => _onCategorySelected('pinned'),
                      ),
                      const SizedBox(width: 5),
                      for (final col in collections.take(4)) ...[
                        _CategoryChip(
                          label: col.name,
                          icon: CupertinoIcons.folder,
                          isSelected: _selectedSection == col.id,
                          onTap: () => _onCategorySelected(col.id),
                        ),
                        const SizedBox(width: 5),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Horizontal Clipboard Cards
        Expanded(
          child: items.isEmpty
              ? const Center(
                  child: Text(
                    'Chưa có dữ liệu sao chép',
                    style: TextStyle(
                      color: Color(0x88FFFFFF),
                      fontSize: 13,
                    ),
                  ),
                )
              : ListView.separated(
                  controller: _scrollController,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  itemCount: items.length,
                  separatorBuilder: (context, index) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NotchClipboardCard(
                      item: item,
                      onTap: () => widget.onItemPasted(item),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF3E7EFF)
              : const Color(0x22FFFFFF),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 11,
              color: isSelected
                  ? CupertinoColors.white
                  : const Color(0xBBFFFFFF),
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: isSelected
                    ? CupertinoColors.white
                    : const Color(0xDDFFFFFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotchClipboardCard extends StatefulWidget {
  const _NotchClipboardCard({
    required this.item,
    required this.onTap,
  });

  final ClipboardItem item;
  final VoidCallback onTap;

  @override
  State<_NotchClipboardCard> createState() => _NotchClipboardCardState();
}

class _NotchClipboardCardState extends State<_NotchClipboardCard> {
  bool _isHovered = false;

  String _formatTime(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 1) return 'Vừa xong';
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  String _formatSize(ClipboardItem item) {
    final bytes = item.content.length;
    if (item.contentType == ClipboardContentType.image &&
        item.imagePath != null) {
      return '76 KB';
    }
    if (bytes < 1024) return '$bytes bytes';
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }

  IconData _sourceIcon(String? appName) {
    final lower = (appName ?? '').toLowerCase();
    if (lower.contains('safari')) return CupertinoIcons.compass;
    if (lower.contains('chrome')) return CupertinoIcons.globe;
    if (lower.contains('note')) return CupertinoIcons.doc_text;
    if (lower.contains('code') || lower.contains('xcode')) {
      return CupertinoIcons.chevron_left_slash_chevron_right;
    }
    return CupertinoIcons.doc_on_clipboard;
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isColor = item.contentType == ClipboardContentType.color;
    final parsedColor = isColor ? ColorParser.parse(item.content) : null;
    final hasImage = item.contentType == ClipboardContentType.image &&
        item.imagePath != null &&
        File(item.imagePath!).existsSync();

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          width: 175,
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: _isHovered
                ? const Color(0x3DFFFFFF)
                : const Color(0x1AFFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _isHovered
                  ? const Color(0x66FFFFFF)
                  : const Color(0x22FFFFFF),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visual Preview Area
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: double.infinity,
                    color: isColor && parsedColor != null
                        ? parsedColor
                        : const Color(0x18FFFFFF),
                    child: isColor
                        ? Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0x88000000),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.content.trim(),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  fontFamily: 'monospace',
                                  color: CupertinoColors.white,
                                ),
                              ),
                            ),
                          )
                        : hasImage
                            ? Image.file(
                                File(item.imagePath!),
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (context, error, stackTrace) =>
                                        const Center(
                                  child: Icon(
                                    CupertinoIcons.photo,
                                    size: 24,
                                    color: Color(0x66FFFFFF),
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(6),
                                child: Text(
                                  item.content.trim(),
                                  maxLines: 4,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.3,
                                    color: item.contentType ==
                                            ClipboardContentType.url
                                        ? const Color(0xFF64B5F6)
                                        : const Color(0xEEFFFFFF),
                                  ),
                                ),
                              ),
                  ),
                ),
              ),
              const SizedBox(height: 7),

              // Bottom Metadata (Source icon, Time, Size)
              Row(
                children: [
                  Icon(
                    _sourceIcon(item.sourceAppName),
                    size: 11,
                    color: const Color(0xAAFFFFFF),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _formatTime(item.createdAt),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xAAFFFFFF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    _formatSize(item),
                    style: const TextStyle(
                      fontSize: 9,
                      color: Color(0x77FFFFFF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
