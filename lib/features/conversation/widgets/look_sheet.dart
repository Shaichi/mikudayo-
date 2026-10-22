import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../avatar/avatar_look.dart';

/// Bảng chọn tay / đạo cụ / trang phục. Thấp (~42% màn hình) để vẫn thấy Miku
/// đổi ngay phía trên; chạm là áp dụng, không có nút "Lưu".
Future<void> showLookSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  barrierColor: Colors.transparent,
  backgroundColor: Colors.transparent,
  builder: (_) => const _LookSheet(),
);

class _LookSheet extends ConsumerWidget {
  const _LookSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final look = ref.watch(avatarLookProvider);
    final n = ref.read(avatarLookProvider.notifier);
    final height = MediaQuery.sizeOf(context).height * 0.42;

    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: MikuTheme.canvas,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: MikuTheme.stageCyan, width: 2)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 8, 0),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ngoại hình của Miku',
                    style: TextStyle(
                      color: MikuTheme.ink,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: look.isDefault ? null : n.reset,
                  child: const Text('Về mặc định'),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              children: [
                _Group(
                  title: 'Tư thế tay',
                  options: lookPoses,
                  selected: {look.pose},
                  dimmed: look.prop != 'none',
                  onTap: n.setPose,
                ),
                _Group(
                  title: 'Cầm đồ',
                  hint: 'Chọn một món, Miku tự cầm đúng tư thế',
                  options: lookProps,
                  selected: {look.prop},
                  onTap: n.setProp,
                ),
                _Group(
                  title: 'Trang phục',
                  options: lookOutfits,
                  selected: {look.outfit},
                  onTap: n.setOutfit,
                ),
                _Group(
                  title: 'Hiệu ứng khuôn mặt',
                  hint: 'Bật được nhiều cái cùng lúc',
                  options: lookEffects,
                  selected: look.effects,
                  onTap: n.toggleEffect,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.options,
    required this.selected,
    required this.onTap,
    this.hint,
    this.dimmed = false,
  });

  final String title;
  final String? hint;
  final List<LookOption> options;
  final Set<String> selected;
  final ValueChanged<String> onTap;
  final bool dimmed;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Opacity(
      opacity: dimmed ? 0.45 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: MikuTheme.ink,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (hint != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                hint!,
                style: const TextStyle(color: MikuTheme.mutedInk, fontSize: 12),
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in options)
                _Chip(
                  option: o,
                  on: selected.contains(o.id),
                  onTap: () => onTap(o.id),
                ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.option, required this.on, required this.onTap});

  final LookOption option;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: on,
    label: option.label,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: on ? MikuTheme.mint : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: on ? MikuTheme.primary : Colors.black12,
            width: 1.4,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              option.icon,
              size: 18,
              color: on ? MikuTheme.primary : MikuTheme.mutedInk,
            ),
            const SizedBox(width: 6),
            Text(
              option.label,
              style: TextStyle(
                color: on ? MikuTheme.primary : MikuTheme.ink,
                fontSize: 13,
                fontWeight: on ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
