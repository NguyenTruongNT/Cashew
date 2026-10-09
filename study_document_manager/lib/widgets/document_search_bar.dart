import 'dart:async';
import 'package:flutter/material.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN TÁI SỬ DỤNG: SEARCH BAR]
// File: lib/widgets/document_search_bar.dart
// Mô tả: Thanh tìm kiếm tích hợp bộ đệm thời gian (Debounce) để tối ưu
// hiệu năng truy vấn dữ liệu theo đúng phương pháp tối ưu của Cashew.
// =====================================================================

class DocumentSearchBar extends StatefulWidget {
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;
  final VoidCallback? onFilterTap;
  final bool hasActiveFilter;
  final TextEditingController? controller;

  const DocumentSearchBar({
    super.key,
    this.hintText = 'Tìm theo tên bài giảng, bài tập, thẻ tag...',
    required this.onChanged,
    this.onClear,
    this.onFilterTap,
    this.hasActiveFilter = false,
    this.controller,
  });

  @override
  State<DocumentSearchBar> createState() => _DocumentSearchBarState();
}

class _DocumentSearchBarState extends State<DocumentSearchBar> {
  late final TextEditingController _textController;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _textController = widget.controller ?? TextEditingController();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    if (widget.controller == null) {
      _textController.dispose();
    }
    super.dispose();
  }

  void _onTextChange(String value) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      widget.onChanged(value);
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: _textController,
        onChanged: _onTextChange,
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
          suffixIcon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_textController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 20, color: Colors.grey),
                  onPressed: () {
                    _textController.clear();
                    widget.onChanged('');
                    if (widget.onClear != null) widget.onClear!();
                    setState(() {});
                  },
                ),
              if (widget.onFilterTap != null)
                IconButton(
                  icon: Stack(
                    children: [
                      const Icon(Icons.tune_rounded, size: 20),
                      if (widget.hasActiveFilter)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  onPressed: widget.onFilterTap,
                ),
            ],
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
    );
  }
}
