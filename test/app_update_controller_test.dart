import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lira/features/app_update/data/android_update_installer.dart';
import 'package:lira/features/app_update/data/github_update_client.dart';
import 'package:lira/features/app_update/domain/app_update.dart';
import 'package:lira/features/app_update/presentation/app_update_controller.dart';

void main() {
  late Directory directory;
  late _Client client;
  late _Installer installer;
  late AppUpdateController controller;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('lira-update-state-');
    client = _Client();
    installer = _Installer(directory);
    controller = AppUpdateController(
      installedVersion: () async => AppUpdateVersion.parse('0.6.4+8'),
      client: client,
      installer: installer,
      canInstall: true,
    );
  });

  tearDown(() async {
    controller.dispose();
    await directory.delete(recursive: true);
  });

  test(
    'a replacement release cannot install the previous downloaded APK',
    () async {
      await controller.check();
      await controller.download();
      expect(controller.status, AppUpdateStatus.ready);

      client.release = _release('0.8.0', '1' * 64);
      await controller.check();
      await controller.install();
      expect(controller.status, AppUpdateStatus.available);
      expect(installer.installations, 0);

      await controller.download();
      await controller.install();
      expect(installer.installedVersion, '0.8.0');
    },
  );

  test(
    'permission retry keeps the APK and does not claim installation succeeded',
    () async {
      await controller.check();
      await controller.download();
      installer.result = UpdateInstallResult.permissionRequired;
      await controller.install();
      expect(controller.status, AppUpdateStatus.ready);
      expect(controller.installFailure, AppUpdateInstallFailure.permission);

      installer.result = UpdateInstallResult.started;
      await controller.install();
      expect(controller.status, AppUpdateStatus.ready);
      expect(controller.installFailure, isNull);
      expect(installer.installations, 2);
      expect(await File('${directory.path}/app-release.apk').exists(), isTrue);
    },
  );

  test(
    'failed recheck preserves a ready update, missing file requires download',
    () async {
      await controller.check();
      await controller.download();
      client.failure = const AppUpdateException(UpdateFailure.network);
      await controller.check();
      expect(controller.status, AppUpdateStatus.ready);
      expect(controller.failure, UpdateFailure.network);

      await File('${directory.path}/app-release.apk').delete();
      await controller.install();
      expect(controller.status, AppUpdateStatus.available);
      expect(controller.failure, UpdateFailure.download);
      expect(installer.installations, 0);
    },
  );

  test(
    'concurrent download presses cannot overwrite the in-flight APK',
    () async {
      await controller.check();
      client.downloadGate = Completer<void>();
      final first = controller.download();
      await client.downloadEntered.future;
      await controller.download();
      expect(controller.status, AppUpdateStatus.downloading);
      expect(client.downloads, 1);
      client.downloadGate!.complete();
      await first;
      expect(controller.status, AppUpdateStatus.ready);
    },
  );

  test(
    'signature failure stays actionable without deleting the download',
    () async {
      await controller.check();
      await controller.download();
      installer.failure = PlatformException(code: 'incompatible_signature');
      await controller.install();
      expect(controller.status, AppUpdateStatus.ready);
      expect(controller.installFailure, AppUpdateInstallFailure.signature);
      expect(await File('${directory.path}/app-release.apk').exists(), isTrue);
    },
  );

  test(
    'non-Android platforms detect releases but cannot download APKs',
    () async {
      controller.dispose();
      client = _Client();
      controller = AppUpdateController(
        installedVersion: () async => AppUpdateVersion.parse('0.6.4+8'),
        client: client,
        installer: installer,
        canInstall: false,
      );
      await controller.check();
      await controller.download();
      await controller.install();
      expect(controller.status, AppUpdateStatus.available);
      expect(
        controller.release!.releaseUrl.path,
        endsWith('/releases/tag/v0.7.0'),
      );
      expect(await File('${directory.path}/app-release.apk').exists(), isFalse);
      expect(installer.installations, 0);
    },
  );

  test(
    'a release without a verified APK remains link-only on Android',
    () async {
      client.release = AppUpdateRelease(
        version: AppUpdateVersion.parse('0.7.0'),
        releaseUrl: client.release.releaseUrl,
      );
      await controller.check();
      await controller.download();
      expect(controller.status, AppUpdateStatus.available);
      expect(await File('${directory.path}/app-release.apk').exists(), isFalse);
    },
  );
}

AppUpdateRelease _release(String version, String digest) => AppUpdateRelease(
  version: AppUpdateVersion.parse(version),
  releaseUrl: Uri.parse(
    'https://github.com/0x0FACED/lira/releases/tag/v$version',
  ),
  apk: AppUpdateApk(
    name: 'app-release.apk',
    url: Uri.parse(
      'https://github.com/0x0FACED/lira/releases/download/v$version/app-release.apk',
    ),
    sizeBytes: 4,
    sha256: digest,
  ),
);

class _Client extends GitHubUpdateClient {
  AppUpdateRelease release = _release('0.7.0', '0' * 64);
  AppUpdateException? failure;
  Completer<void>? downloadGate;
  final downloadEntered = Completer<void>();
  int downloads = 0;

  @override
  Future<AppUpdateRelease> latest() async {
    if (failure != null) throw failure!;
    return release;
  }

  @override
  Future<File> download(
    AppUpdateRelease release,
    Directory directory, {
    required void Function(int received, int total) onProgress,
  }) async {
    downloads++;
    if (!downloadEntered.isCompleted) downloadEntered.complete();
    if (downloadGate != null) await downloadGate!.future;
    onProgress(2, 4);
    final apk = await File(
      '${directory.path}/app-release.apk',
    ).writeAsBytes([1, 2, 3, 4]);
    onProgress(4, 4);
    return apk;
  }
}

class _Installer extends AndroidUpdateInstaller {
  _Installer(this.directory);

  final Directory directory;
  UpdateInstallResult result = UpdateInstallResult.started;
  PlatformException? failure;
  int installations = 0;
  String? installedVersion;

  @override
  Future<void> cleanup() async {}

  @override
  Future<Directory> updateDirectory() async => directory;

  @override
  Future<UpdateInstallResult> install(
    File apk,
    AppUpdateVersion version,
  ) async {
    if (failure != null) throw failure!;
    installations++;
    installedVersion = version.displayVersion;
    return result;
  }
}
