import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../chat/data/chat_repository.dart';
import '../../chat/data/community_room_repository.dart';
import '../../chat/presentation/chat_hub_page.dart';
import '../../chat/presentation/image_picking.dart';
import 'admin_widgets.dart';

typedef _RoomEdit = ({String name, String icon, PickedImage? cover, bool removeCover});

class AdminRoomsPage extends ConsumerStatefulWidget {
  const AdminRoomsPage({super.key});

  @override
  ConsumerState<AdminRoomsPage> createState() => _AdminRoomsPageState();
}

class _AdminRoomsPageState extends ConsumerState<AdminRoomsPage> {
  @override
  void initState() {
    super.initState();
    // Creates the original 3 rooms (cooking, dharma, pets) the first time an admin opens this page.
    ref.read(communityRoomRepositoryProvider).ensureDefaultRooms().catchError((Object e) {
      debugPrint('ensure default rooms failed: $e');
    });
  }

  Future<void> _edit([CommunityRoom? room]) async {
    final result = await showDialog<_RoomEdit>(
      context: context,
      builder: (context) => _RoomDialog(room: room),
    );
    if (result == null || !mounted) return;
    final repo = ref.read(communityRoomRepositoryProvider);
    if (result.cover != null) showAppSnack(context, 'กำลังบันทึกและอัปโหลดรูปปก...');
    try {
      final String id;
      if (room == null) {
        id = await repo.addRoom(result.name, result.icon);
      } else {
        id = room.id;
        await repo.updateRoom(id, name: result.name, icon: result.icon);
      }
      final cover = result.cover;
      final oldUrl = room?.imageUrl;
      if (cover != null) {
        await repo.setCover(id, cover, oldUrl: oldUrl);
      } else if (result.removeCover && oldUrl != null) {
        await repo.removeCover(id, oldUrl);
      }
      if (mounted) {
        showAppSnack(context, room == null ? 'เพิ่มห้อง "${result.name}" แล้ว' : 'บันทึกแล้ว');
      }
    } on FirebaseException catch (e) {
      if (mounted) showAppSnack(context, 'บันทึกไม่สำเร็จ (${e.code})', isError: true);
    }
  }

  Future<void> _setOpen(CommunityRoom room, bool open) async {
    try {
      await ref.read(communityRoomRepositoryProvider).setOpen(room.id, open);
    } on FirebaseException catch (e) {
      if (mounted) showAppSnack(context, 'เปลี่ยนสถานะไม่สำเร็จ (${e.code})', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rooms = ref.watch(communityRoomsProvider);

    return AdminGuard(
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                  children: [
                    const BackTextButton(),
                    const PageTitle('ห้องแชทชุมชน'),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        'ห้องที่ปิดจะไม่แสดงให้สมาชิกเห็น',
                        style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
                      ),
                    ),
                    const SizedBox(height: 16),
                    rooms.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Text('โหลดห้องไม่สำเร็จ\n$e'),
                      data: (list) => Column(
                        children: [
                          for (final room in list)
                            AdminCard(
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: SizedBox(
                                      width: 52,
                                      height: 52,
                                      child: Opacity(
                                        opacity: room.open ? 1 : 0.45,
                                        child: RoomCover(room: room),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(room.name,
                                            style: TextStyle(fontSize: 20, color: scheme.onSurface)),
                                        Text(
                                          room.open ? 'เปิดอยู่' : 'ปิดอยู่',
                                          style: TextStyle(
                                            fontSize: 15,
                                            color: room.open
                                                ? const Color(0xFF2F6B58)
                                                : scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'แก้ไขห้อง',
                                    onPressed: () => _edit(room),
                                    icon: Icon(Icons.edit_outlined, color: scheme.tertiary),
                                  ),
                                  Switch(
                                    value: room.open,
                                    onChanged: (v) => _setOpen(room, v),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 24, top: 8),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => _edit(),
                  icon: const Icon(Icons.add),
                  label: const Text('เพิ่มห้องแชท'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoomDialog extends StatefulWidget {
  const _RoomDialog({this.room});

  final CommunityRoom? room;

  @override
  State<_RoomDialog> createState() => _RoomDialogState();
}

class _RoomDialogState extends State<_RoomDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.room?.name ?? '');
  late String _icon = widget.room?.icon ?? 'chat';
  PickedImage? _cover;
  bool _removeCover = false;

  Future<void> _pickCover() async {
    try {
      final picked = await pickChatImage(ImageSource.gallery, maxSize: 1200);
      if (picked != null && mounted) {
        setState(() {
          _cover = picked;
          _removeCover = false;
        });
      }
    } catch (_) {
      if (mounted) showAppSnack(context, 'เปิดรูปภาพไม่สำเร็จ', isError: true);
    }
  }

  Widget _coverPreview() {
    final picked = _cover;
    final Widget child;
    if (picked != null) {
      child = Image.memory(picked.bytes, fit: BoxFit.cover);
    } else if (!_removeCover && widget.room?.imageUrl != null) {
      child = Image.network(widget.room!.imageUrl!, fit: BoxFit.cover);
    } else if (widget.room?.image != null) {
      child = Image.asset(widget.room!.image!, fit: BoxFit.cover);
    } else {
      child = ColoredBox(
        color: AppColors.brown,
        child: Center(child: Icon(roomIconOf(_icon), size: 48, color: Colors.white)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(aspectRatio: 2, child: child),
    );
  }

  bool get _hasCustomCover =>
      _cover != null || (!_removeCover && widget.room?.imageUrl != null);

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showAppSnack(context, 'กรุณากรอกชื่อห้อง', isError: true);
      return;
    }
    final _RoomEdit result = (
      name: name,
      icon: _icon,
      cover: _cover,
      removeCover: _removeCover,
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.room == null ? 'เพิ่มห้องแชท' : 'แก้ไขห้องแชท', textAlign: TextAlign.center),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ชื่อห้อง', style: TextStyle(fontSize: 18, color: scheme.onSurface)),
            const SizedBox(height: 6),
            TextField(
              controller: _name,
              maxLength: CommunityRoomRepository.maxNameLength,
              style: const TextStyle(fontSize: 20),
            ),
            const SizedBox(height: 4),
            Text('รูปปก', style: TextStyle(fontSize: 18, color: scheme.onSurface)),
            const SizedBox(height: 8),
            _coverPreview(),
            Row(
              children: [
                TextButton.icon(
                  onPressed: _pickCover,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('เลือกรูปปก'),
                ),
                if (_hasCustomCover)
                  TextButton(
                    onPressed: () => setState(() {
                      _cover = null;
                      _removeCover = true;
                    }),
                    child: Text('ลบรูปปก', style: TextStyle(color: scheme.error)),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('ไอคอนห้อง', style: TextStyle(fontSize: 18, color: scheme.onSurface)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final entry in roomIcons.entries)
                  InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => setState(() => _icon = entry.key),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _icon == entry.key ? AppColors.brown : scheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _icon == entry.key ? AppColors.primary : scheme.outlineVariant,
                          width: _icon == entry.key ? 3 : 1.5,
                        ),
                      ),
                      child: Icon(
                        entry.value,
                        size: 30,
                        color: _icon == entry.key ? Colors.white : AppColors.brown,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        TextButton(onPressed: _save, child: const Text('บันทึก')),
      ],
    );
  }
}
