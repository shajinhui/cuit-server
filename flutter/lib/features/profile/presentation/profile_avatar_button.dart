import 'package:flutter/material.dart';

import '../../../ui/components/page_sheet.dart';

import 'package:image_picker/image_picker.dart';

import '../data/profile_avatar.dart';

class ProfileAvatarButton extends StatelessWidget {
  const ProfileAvatarButton({super.key, required this.avatar, this.size = 76});
  final ProfileAvatar avatar;
  final double size;

  Future<void> _choose(BuildContext context) async {
    await showPageSheet<void>(
      context,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * .85,
          ),
          child: SingleChildScrollView(
            child: AnimatedBuilder(
              animation: avatar,
              builder: (context, _) => Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('选择头像', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 280,
                      child: GridView.builder(
                        itemCount: ProfileAvatar.presetCount,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 4,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemBuilder: (context, index) => InkWell(
                          onTap: avatar.saving
                              ? null
                              : () async {
                                  await avatar.selectPreset(index + 1);
                                  if (sheetContext.mounted &&
                                      avatar.error == null) {
                                    Navigator.pop(sheetContext);
                                  }
                                },
                          child: ClipOval(
                            child: Image.asset(
                              'assets/avatars/avatar-${(index + 1).toString().padLeft(2, '0')}.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (avatar.error != null)
                      Text(
                        avatar.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: avatar.saving
                          ? null
                          : () async {
                              try {
                                final file = await ImagePicker().pickImage(
                                  source: ImageSource.gallery,
                                  maxWidth: 1024,
                                  maxHeight: 1024,
                                  requestFullMetadata: false,
                                );
                                if (file == null || !sheetContext.mounted) {
                                  return;
                                }
                                final bytes = await file.readAsBytes();
                                if (!sheetContext.mounted) return;
                                await avatar.selectCustom(bytes);
                                if (sheetContext.mounted &&
                                    avatar.error == null) {
                                  Navigator.pop(sheetContext);
                                }
                              } catch (_) {
                                if (sheetContext.mounted) {
                                  ScaffoldMessenger.of(
                                    sheetContext,
                                  ).showSnackBar(
                                    const SnackBar(content: Text('无法读取照片，请重试')),
                                  );
                                }
                              }
                            },
                      icon: const Icon(Icons.photo_library_outlined),
                      label: Text(avatar.saving ? '正在保存…' : '从相册选择'),
                    ),
                    const SizedBox(height: 8),
                    const Text('头像只保存在本机，不会上传到服务器。'),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: avatar,
    builder: (context, _) => Semantics(
      label: '修改头像',
      button: true,
      child: InkWell(
        key: const Key('profile-avatar'),
        customBorder: const CircleBorder(),
        onTap: avatar.saving ? null : () => _choose(context),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            children: [
              Positioned.fill(
                child: ClipOval(
                  child: avatar.customImage == null
                      ? Image.asset(avatar.assetPath, fit: BoxFit.cover)
                      : Image.memory(avatar.customImage!, fit: BoxFit.cover),
                ),
              ),
              const Positioned(
                right: 0,
                bottom: 0,
                child: CircleAvatar(
                  radius: 12,
                  child: Icon(Icons.edit_rounded, size: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
