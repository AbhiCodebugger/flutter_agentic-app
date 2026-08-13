import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

enum MediaSource { camera, gallery }

class MediaPermissionService {
  Future<bool> ensurePermission(MediaSource source) async {
    final permission = switch (source) {
      MediaSource.camera => Permission.camera,
      MediaSource.gallery => Permission.photos,
    };

    var status = await permission.status;
    if (status.isGranted || status.isLimited) {
      return true;
    }

    status = await permission.request();
    if (status.isGranted || status.isLimited) {
      return true;
    }

    // Android photo picker often works without a permanent grant; allow
    // gallery flow to continue so the system picker can still open.
    if (source == MediaSource.gallery &&
        Platform.isAndroid &&
        !status.isPermanentlyDenied) {
      return true;
    }

    return false;
  }

  Future<bool> openSettingsIfPermanentlyDenied(MediaSource source) async {
    final permission = switch (source) {
      MediaSource.camera => Permission.camera,
      MediaSource.gallery => Permission.photos,
    };

    final status = await permission.status;
    if (status.isPermanentlyDenied) {
      return openAppSettings();
    }
    return false;
  }
}
