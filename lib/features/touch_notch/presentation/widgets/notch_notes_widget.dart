import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/touch_notch_providers.dart';

class NotchNotesWidget extends ConsumerStatefulWidget {
  const NotchNotesWidget({
    super.key,
    required this.onCopyText,
  });

  final ValueChanged<String> onCopyText;

  @override
  ConsumerState<NotchNotesWidget> createState() => _NotchNotesWidgetState();
}

class _NotchNotesWidgetState extends ConsumerState<NotchNotesWidget> {
  final _textController = TextEditingController();

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  void _saveNote() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;
    ref.read(touchNotesProvider.notifier).addNote(text);
    _textController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(touchNotesProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Column(
        children: [
          // Input field + Save button
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 32,
                  child: CupertinoTextField(
                    controller: _textController,
                    placeholder: 'Nhập ghi chú nhanh…',
                    placeholderStyle: const TextStyle(
                      color: Color(0x88FFFFFF),
                      fontSize: 12,
                    ),
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x22FFFFFF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    onSubmitted: (_) => _saveNote(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _saveNote,
                child: Container(
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF3E7EFF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                    child: Text(
                      'Lưu',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Notes List
          Expanded(
            child: notes.isEmpty
                ? const Center(
                    child: Text(
                      'Chưa có ghi chú nào',
                      style: TextStyle(
                        color: Color(0x88FFFFFF),
                        fontSize: 12,
                      ),
                    ),
                  )
                : ListView.separated(
                    itemCount: notes.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0x18FFFFFF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0x1AFFFFFF),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                note.text,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.white,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => widget.onCopyText(note.text),
                              child: const Icon(
                                CupertinoIcons.doc_on_clipboard,
                                size: 14,
                                color: Color(0xAAFFFFFF),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () => ref
                                  .read(touchNotesProvider.notifier)
                                  .removeNote(note.id),
                              child: const Icon(
                                CupertinoIcons.trash,
                                size: 14,
                                color: Color(0x88FF5A5F),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
