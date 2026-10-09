import 'package:flutter/material.dart';
import '../struct/models/document_models.dart';

// =====================================================================
// [KIẾN TRÚC CASHEW - TẦNG GIAO DIỆN TÁI SỬ DỤNG: FILTER CHIP BAR]
// File: lib/widgets/filter_chip_bar.dart
// Mô tả: Thanh chọn phân loại nằm ngang (Horizontal Filter Chips)
// giúp người học chuyển đổi nhanh giữa các nhóm tài liệu.
// =====================================================================

class FilterChipBar extends StatelessWidget {
  final DocumentType? selectedType;
  final ValueChanged<DocumentType?> onSelected;

  const FilterChipBar({
    super.key,
    required this.selectedType,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          // Nút "Tất cả"
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: const Text('Tất cả'),
              selected: selectedType == null,
              onSelected: (_) => onSelected(null),
              avatar: const Icon(Icons.grid_view_rounded, size: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
          ),

          // Các loại tài liệu cụ thể
          ...DocumentType.values.map((type) {
            final isSelected = selectedType == type;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(type.displayName),
                selected: isSelected,
                selectedColor: type.color.withValues(alpha: 0.2),
                avatar: Icon(
                  type.icon,
                  size: 16,
                  color: isSelected
                      ? type.color
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                labelStyle: TextStyle(
                  color: isSelected ? type.color : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected
                      ? type.color
                      : Theme.of(context).colorScheme.outlineVariant,
                ),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onSelected: (val) {
                  onSelected(val ? type : null);
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
