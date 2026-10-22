import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Một lựa chọn ngoại hình: [exps] là tên các file `*.exp3.json` của model Live2D.
class LookOption {
  const LookOption(this.id, this.label, this.icon, this.exps);

  final String id;
  final String label;
  final IconData icon;
  final List<String> exps;
}

/// Mọi đạo cụ chỉ hiện đủ khi tay ở tư thế "Hold Staff2" (đã thử trên model),
/// nên chọn đạo cụ sẽ tự thêm tư thế đó.
const _holdProp = 'Hold Staff2';

const lookPoses = <LookOption>[
  LookOption('none', 'Mặc định', Icons.accessibility_new_rounded, []),
  LookOption('chest', 'Tay đặt lên ngực', Icons.favorite_border_rounded, [
    'Hand on Chest Pose',
  ]),
  LookOption('cover', 'Hai tay che miệng', Icons.face_rounded, ['Yandere']),
];

const lookProps = <LookOption>[
  LookOption('none', 'Không cầm', Icons.block_rounded, []),
  LookOption('wand', 'Gậy phép', Icons.auto_fix_high_rounded, [
    'Hold Staff (Both Hands)',
  ]),
  LookOption('wand_up', 'Giơ gậy phép', Icons.stars_rounded, [
    'Overhead Staff Raise',
  ]),
  LookOption('hammer', 'Búa', Icons.hardware_rounded, [_holdProp, 'hammer']),
  LookOption('axe', 'Rìu', Icons.carpenter_rounded, [_holdProp, 'axe']),
  LookOption('bat', 'Gậy bóng chày', Icons.sports_baseball_rounded, [
    _holdProp,
    'baseball bat',
  ]),
  LookOption('crowbar', 'Xà beng', Icons.handyman_rounded, [
    _holdProp,
    'crowbar',
  ]),
  LookOption('wrench', 'Cờ lê', Icons.build_rounded, [_holdProp, 'wrench']),
  LookOption('pliers', 'Kìm', Icons.construction_rounded, [
    _holdProp,
    'pliers',
  ]),
  LookOption('saw', 'Cưa', Icons.carpenter_outlined, [_holdProp, 'saw']),
  LookOption('scissors', 'Kéo', Icons.content_cut_rounded, [
    _holdProp,
    'scissors',
  ]),
  LookOption('shovel', 'Xẻng', Icons.agriculture_rounded, [
    _holdProp,
    'shovel',
  ]),
  LookOption('hoe', 'Cuốc', Icons.grass_rounded, [_holdProp, 'hoe']),
  LookOption('knife', 'Dao rọc giấy', Icons.edit_rounded, [
    _holdProp,
    'utility knife',
  ]),
  LookOption('baton', 'Dùi cui điện', Icons.bolt_rounded, [
    _holdProp,
    'stun baton',
  ]),
];

const lookOutfits = <LookOption>[
  LookOption('none', 'Mặc định', Icons.checkroom_rounded, []),
  LookOption('uniform', 'Đồng phục', Icons.school_rounded, ['School Uniform']),
];

const lookEffects = <LookOption>[
  LookOption('blush', 'Đỏ mặt', Icons.local_fire_department_rounded, [
    'Blush',
    'side Blush',
  ]),
  LookOption('star', 'Mắt sao', Icons.star_rounded, ['Star']),
  LookOption('fang', 'Răng nanh', Icons.sentiment_very_satisfied_rounded, [
    'Fanged Smile',
  ]),
  LookOption('gloom', 'Mặt tối sầm', Icons.cloud_rounded, ['Gloom']),
  LookOption('dead', 'Mắt vô hồn', Icons.visibility_off_rounded, ['Dead Eyes']),
];

LookOption _byId(List<LookOption> list, String? id) =>
    list.firstWhere((o) => o.id == id, orElse: () => list.first);

/// Lựa chọn hiện tại của người dùng. Mỗi nhóm chọn đúng một.
class AvatarLook {
  const AvatarLook({
    this.pose = 'none',
    this.prop = 'none',
    this.outfit = 'none',
    this.effects = const {},
  });

  final String pose;
  final String prop;
  final String outfit;
  final Set<String> effects;

  bool get isDefault =>
      pose == 'none' && prop == 'none' && outfit == 'none' && effects.isEmpty;

  /// Danh sách exp3 cần bật. Đạo cụ có tư thế riêng nên đè lên tư thế tay.
  List<String> get exps {
    final propOpt = _byId(lookProps, prop);
    final out = <String>{
      ..._byId(lookOutfits, outfit).exps,
      if (propOpt.id == 'none')
        ..._byId(lookPoses, pose).exps
      else
        ...propOpt.exps,
      for (final e in effects) ..._byId(lookEffects, e).exps,
    };
    return out.toList();
  }

  AvatarLook copyWith({
    String? pose,
    String? prop,
    String? outfit,
    Set<String>? effects,
  }) => AvatarLook(
    pose: pose ?? this.pose,
    prop: prop ?? this.prop,
    outfit: outfit ?? this.outfit,
    effects: effects ?? this.effects,
  );
}

class AvatarLookNotifier extends Notifier<AvatarLook> {
  static const _kPose = 'avatar_look_pose';
  static const _kProp = 'avatar_look_prop';
  static const _kOutfit = 'avatar_look_outfit';
  static const _kEffects = 'avatar_look_effects';

  @override
  AvatarLook build() {
    _load();
    return const AvatarLook();
  }

  Future<void> _load() async {
    try {
      final p = await SharedPreferences.getInstance();
      state = AvatarLook(
        pose: _byId(lookPoses, p.getString(_kPose)).id,
        prop: _byId(lookProps, p.getString(_kProp)).id,
        outfit: _byId(lookOutfits, p.getString(_kOutfit)).id,
        effects: (p.getStringList(_kEffects) ?? const [])
            .where((e) => lookEffects.any((o) => o.id == e))
            .toSet(),
      );
    } catch (_) {
      // Không đọc được cài đặt → giữ mặc định.
    }
  }

  Future<void> _save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_kPose, state.pose);
      await p.setString(_kProp, state.prop);
      await p.setString(_kOutfit, state.outfit);
      await p.setStringList(_kEffects, state.effects.toList());
    } catch (_) {}
  }

  void setPose(String id) {
    // Chọn tư thế tay thì bỏ đạo cụ (đạo cụ tự có tư thế riêng).
    state = state.copyWith(pose: id, prop: id == 'none' ? null : 'none');
    _save();
  }

  void setProp(String id) {
    state = state.copyWith(prop: id);
    _save();
  }

  void setOutfit(String id) {
    state = state.copyWith(outfit: id);
    _save();
  }

  void toggleEffect(String id) {
    final next = {...state.effects};
    if (!next.remove(id)) next.add(id);
    state = state.copyWith(effects: next);
    _save();
  }

  void reset() {
    state = const AvatarLook();
    _save();
  }
}

final avatarLookProvider = NotifierProvider<AvatarLookNotifier, AvatarLook>(
  AvatarLookNotifier.new,
);
