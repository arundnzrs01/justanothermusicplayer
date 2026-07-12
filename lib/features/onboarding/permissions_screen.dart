import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _kPermissionsDoneKey = 'startup_permissions_done';

/// Requests storage, audio, and notification permissions on first launch.
class StartupPermissions {
  static Future<bool> isComplete() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kPermissionsDoneKey) ?? false;
  }

  static Future<void> markComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPermissionsDoneKey, true);
  }

  static Future<PermissionRequestResult> requestAll() async {
    final results = <Permission, PermissionStatus>{
      Permission.notification: await Permission.notification.request(),
      Permission.audio: await Permission.audio.request(),
      // Legacy storage for older Android; ignored on API 33+.
      Permission.storage: await Permission.storage.request(),
    };

    final allGranted = results.values.every(
      (s) => s.isGranted || s.isLimited,
    );

    if (allGranted) {
      await markComplete();
    }

    return PermissionRequestResult(
      allGranted: allGranted,
      statuses: results,
    );
  }

  static Future<bool> openSettingsIfNeeded() async {
    return openAppSettings();
  }
}

class PermissionRequestResult {
  const PermissionRequestResult({
    required this.allGranted,
    this.statuses = const {},
  });

  final bool allGranted;
  final Map<Permission, PermissionStatus> statuses;
}

/// First-run screen that explains and requests required permissions.
class PermissionsOnboardingScreen extends StatefulWidget {
  const PermissionsOnboardingScreen({
    super.key,
    required this.onComplete,
  });

  final VoidCallback onComplete;

  @override
  State<PermissionsOnboardingScreen> createState() =>
      _PermissionsOnboardingScreenState();
}

class _PermissionsOnboardingScreenState extends State<PermissionsOnboardingScreen> {
  bool _busy = false;
  String? _message;

  Future<void> _request() async {
    setState(() {
      _busy = true;
      _message = null;
    });

    final result = await StartupPermissions.requestAll();

    if (!mounted) return;

    setState(() {
      _busy = false;
      _message = result.allGranted
          ? null
          : 'Some permissions were denied. JAMP needs storage and audio access for downloads and playback, and notifications for download progress.';
    });

    if (result.allGranted) {
      widget.onComplete();
    }
  }

  Future<void> _skip() async {
    await StartupPermissions.markComplete();
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.security, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Permissions',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'JAMP needs a few permissions to work properly:',
                style: theme.textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              _PermissionRow(
                icon: Icons.folder_outlined,
                title: 'Storage',
                subtitle: 'Save downloaded music to your device',
              ),
              _PermissionRow(
                icon: Icons.library_music_outlined,
                title: 'Music & audio',
                subtitle: 'Scan and play your library',
              ),
              _PermissionRow(
                icon: Icons.notifications_outlined,
                title: 'Notifications',
                subtitle: 'Show download progress',
              ),
              if (_message != null) ...[
                const SizedBox(height: 16),
                Text(
                  _message!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const Spacer(),
              FilledButton(
                onPressed: _busy ? null : _request,
                child: _busy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Grant permissions'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _busy ? null : () async {
                  await StartupPermissions.openSettingsIfNeeded();
                },
                child: const Text('Open settings'),
              ),
              TextButton(
                onPressed: _busy ? null : _skip,
                child: const Text('Continue without granting'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
