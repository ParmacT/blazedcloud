import 'package:blazedcloud/constants.dart';
import 'package:blazedcloud/controllers/download_controller.dart';
import 'package:blazedcloud/log.dart';
import 'package:blazedcloud/providers/files_providers.dart';
import 'package:blazedcloud/providers/transfers_providers.dart';
import 'package:blazedcloud/services/files_api.dart';
import 'package:blazedcloud/utils/files_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final isFileOffline =
    FutureProvider.family<bool, String>((ref, filename) async {
  return await isFileSavedOffline(filename);
});

void deleteItem(String fileKey, BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete file'),
      content: const Text('Are you sure you want to delete this file?'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            // Handle delete action here
            logger.i('Deleting $fileKey');
            Navigator.of(context).pop();
            deleteFile(pb.authStore.model.id, fileKey, pb.authStore.token);
            ref.invalidate(fileListProvider(pb.authStore.model.id));
          },
          child: const Text('Delete'),
        ),
      ],
    ),
  );
}

void downloadItem(String fileKey, DownloadController downloadController) {
  downloadController.startDownload(pb.authStore.model.id, fileKey);
  HapticFeedback.vibrate();
}

void saveItem(String fileKey, WidgetRef ref) {
  isFileSavedOffline(fileKey).then((isOffline) {
    if (isOffline ||
        !isFileBeingDownloaded(fileKey, ref.read(downloadStateProvider))) {
      getOfflineFile(fileKey).then((file) {
        logger.i('Opening file: ${file.path}');
        try {
          //launchUrl(Uri.parse("file://${file.path}"),
          //    mode: LaunchMode.externalNonBrowserApplication);
          openFile(file);
        } catch (e) {
          logger.e('Error opening file: $e');
        }
      });
    }
  });
}

class FileItem extends ConsumerWidget {
  final String fileKey;

  const FileItem({
    super.key,
    required this.fileKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final FileType type = getFileType(fileKey);
    final isAvailableOffline = ref.watch(isFileOffline(fileKey));
    final downloadController = ref.watch(downloadControllerProvider);

    return Card(
      child: ListTile(
        leading: Icon(
          type == FileType.image
              ? Icons.image
              : type == FileType.video
                  ? Icons.video_library
                  : Icons.insert_drive_file,
        ),
        title: isAvailableOffline.when(
          data: (offline) {
            if (offline) {
              return Text('${getFileName(fileKey)} ✓');
            } else {
              return Text(getFileName(fileKey));
            }
          },
          loading: () => const SizedBox.shrink(),
          error: (err, stack) {
            logger.e('Error checking if $fileKey is available offline: $err');
            return const SizedBox.shrink();
          },
        ),
        trailing: PopupMenuButton<String>(
          itemBuilder: (context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'open',
              child: Text('Open'),
            ),
            const PopupMenuItem<String>(
              value: 'save',
              child: Text('Save'),
            ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Text('Delete'),
            ),
          ],
          onSelected: (value) {
            if (value == 'open') {
              saveItem(fileKey, ref);
            } else if (value == 'save') {
              downloadItem(fileKey, downloadController);
            } else if (value == 'delete') {
              // ask for confirmation before deleting
              deleteItem(fileKey, context, ref);
            }
          },
        ),
      ),
    );
  }
}