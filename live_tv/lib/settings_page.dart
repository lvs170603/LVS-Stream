import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'services/ad_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({Key? key}) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Box settingsBox;
  bool isMonoAudio = false;
  bool isAutoLaunch = false;
  double audioBalance = 0.0; // -1.0 (Left) to 1.0 (Right)
  late FocusNode _balanceSliderFocusNode;
  bool _isSliderApparentFocus = false;
  bool _isMonoApparentFocus = false;
  bool _isAutoLaunchApparentFocus = false;

  static const MethodChannel _bootChannel = MethodChannel('tv_boot_control');

  @override
  void initState() {
    super.initState();
    _balanceSliderFocusNode = FocusNode();
    settingsBox = Hive.box('settingsBox');
    
    // Load previously saved settings
    isMonoAudio = settingsBox.get('monoAudio', defaultValue: false);
    isAutoLaunch = getAutoLaunch();
    audioBalance = settingsBox.get('audioBalance', defaultValue: 0.0);
  }

  @override
  void dispose() {
    _balanceSliderFocusNode.dispose();
    super.dispose();
  }

  Future<bool> _onWillPop() async {
    if (_balanceSliderFocusNode.hasFocus) {
      _balanceSliderFocusNode.unfocus();
      return false; // Prevent popping, just remove focus
    }
    return true; // Allow normal pop
  }

  void _updateMonoAudio(bool value) {
    setState(() {
      isMonoAudio = value;
    });
    settingsBox.put('monoAudio', value);
  }

  // Load function
  bool getAutoLaunch() {
    return settingsBox.get('auto_launch_enabled', defaultValue: false);
  }

  // Save function
  Future<void> saveAutoLaunch(bool value) async {
    setState(() {
      isAutoLaunch = value;
    });
    await settingsBox.put('auto_launch_enabled', value);
    try {
      await _bootChannel.invokeMethod('setAutoLaunch', {'enabled': value});
    } catch (e) {
      debugPrint("Failed to sync autoLaunch natively: $e");
    }
  }

  void _updateAudioBalance(double value) {
    setState(() {
      audioBalance = value;
    });
    settingsBox.put('audioBalance', value);
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          backgroundColor: Theme.of(context).colorScheme.surface,
          elevation: 0,
          title: Text('Settings',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
          iconTheme: IconThemeData(color: Theme.of(context).iconTheme.color),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Theme Section ──────────────────────────────────
              _buildSettingsCard(
                title: "Theme",
                icon: Icons.palette_outlined,
                child: Column(
                  children: [
                    _ThemeOptionTile(
                      label: "System Default",
                      subtitle: "Follow device theme automatically",
                      icon: Icons.brightness_auto_rounded,
                      value: ThemeMode.system,
                    ),
                    Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
                    _ThemeOptionTile(
                      label: "Light",
                      subtitle: "Always use light theme",
                      icon: Icons.light_mode_rounded,
                      value: ThemeMode.light,
                    ),
                    Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
                    _ThemeOptionTile(
                      label: "Dark",
                      subtitle: "Always use dark theme",
                      icon: Icons.dark_mode_rounded,
                      value: ThemeMode.dark,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // ── Audio Section ──────────────────────────────────
              _buildSettingsCard(
                title: "Audio Output",
                icon: Icons.speaker,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: _isMonoApparentFocus ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : Border.all(color: Colors.transparent, width: 2),
                        boxShadow: _isMonoApparentFocus ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withAlpha(50), blurRadius: 10, spreadRadius: 1)] : [],
                      ),
                      child: Focus(
                        onFocusChange: (val) => setState(() => _isMonoApparentFocus = val),
                        child: SwitchListTile(
                          title: Text("Mono Audio", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
                          subtitle: Text("Combine left and right channels into a single mono channel.", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                          value: isMonoAudio,
                          activeColor: Theme.of(context).colorScheme.primary,
                          onChanged: _updateMonoAudio,
                        ),
                      ),
                    ),
                    const Divider(color: Colors.white12),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Audio Balance",
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              Text("Left", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: _isSliderApparentFocus ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : Border.all(color: Colors.transparent, width: 2),
                                    boxShadow: _isSliderApparentFocus ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withAlpha(50), blurRadius: 10, spreadRadius: 1)] : [],
                                  ),
                                  child: Focus(
                                    onFocusChange: (val) => setState(() => _isSliderApparentFocus = val),
                                    onKeyEvent: (node, event) {
                                      if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
                                        return KeyEventResult.ignored;
                                      }
                                      if (event.logicalKey == LogicalKeyboardKey.arrowLeft) {
                                        _updateAudioBalance((audioBalance - 0.1).clamp(-1.0, 1.0));
                                        return KeyEventResult.handled;
                                      } else if (event.logicalKey == LogicalKeyboardKey.arrowRight) {
                                        _updateAudioBalance((audioBalance + 0.1).clamp(-1.0, 1.0));
                                        return KeyEventResult.handled;
                                      } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                                        // Move focus UP to Mono Audio switch — MUST return handled
                                        // to prevent Slider treating arrowUp as arrowRight internally
                                        FocusScope.of(node.context!).focusInDirection(TraversalDirection.up);
                                        return KeyEventResult.handled;
                                      } else if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                                        FocusScope.of(node.context!).focusInDirection(TraversalDirection.down);
                                        return KeyEventResult.handled;
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: Slider(
                                      focusNode: _balanceSliderFocusNode,
                                      value: audioBalance,
                                      min: -1.0,
                                      max: 1.0,
                                      divisions: 20,
                                      activeColor: Theme.of(context).colorScheme.primary,
                                      inactiveColor: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.1),
                                      onChanged: _updateAudioBalance,
                                    ),
                                  ),
                                ),
                              ),
                              Text("Right", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                          Center(
                            child: Text(
                              audioBalance == 0.0
                                  ? "Center"
                                  : (audioBalance < 0
                                      ? "Left ${(_abs(audioBalance) * 100).toInt()}%"
                                      : "Right ${(_abs(audioBalance) * 100).toInt()}%"),
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildSettingsCard(
                title: "System & Startup",
                icon: Icons.power_settings_new,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: _isAutoLaunchApparentFocus ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : Border.all(color: Colors.transparent, width: 2),
                    boxShadow: _isAutoLaunchApparentFocus ? [BoxShadow(color: Theme.of(context).colorScheme.primary.withAlpha(50), blurRadius: 10, spreadRadius: 1)] : [],
                  ),
                  child: Focus(
                    onFocusChange: (val) => setState(() => _isAutoLaunchApparentFocus = val),
                    child: SwitchListTile(
                      title: Text("Auto Launch on TV Start", style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18)),
                      subtitle: Text("Automatically open the app when your device boots up.", style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      value: isAutoLaunch,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: saveAutoLaunch,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Ad Banner at bottom of Settings
              const AdBanner(),
            ],
          ),
        ),
      ),
    );
  }


  double _abs(double val) {
    return val < 0 ? -val : val;
  }

  Widget _buildSettingsCard({required String title, required IconData icon, required Widget child}) {
    return Builder(
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1E1E28) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
                  const SizedBox(width: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(color: Colors.white12, height: 1),
          child,
        ],
      ),
    ),
  );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme option tile — appears inside the Theme settings card.
// TV-safe: shows a visible focus ring on D-pad navigation.
// ─────────────────────────────────────────────────────────────────────────────
class _ThemeOptionTile extends StatefulWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final ThemeMode value;

  const _ThemeOptionTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.value,
  });

  @override
  State<_ThemeOptionTile> createState() => _ThemeOptionTileState();
}

class _ThemeOptionTileState extends State<_ThemeOptionTile> {
  bool _isFocused = false;

  @override
  Widget build(BuildContext context) {
    final provider   = context.watch<ThemeProvider>();
    final isSelected = provider.mode == widget.value;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withOpacity(0.08)
            : Colors.transparent,
        border: _isFocused
            ? Border.all(color: colorScheme.primary, width: 2)
            : Border.all(color: Colors.transparent, width: 2),
        borderRadius: BorderRadius.circular(10),
        boxShadow: _isFocused
            ? [BoxShadow(color: colorScheme.primary.withOpacity(0.25), blurRadius: 12, spreadRadius: 1)]
            : [],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: Focus(
        onFocusChange: (val) => setState(() => _isFocused = val),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => context.read<ThemeProvider>().setMode(widget.value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            child: Row(
              children: [
                // Mode icon
                Icon(
                  widget.icon,
                  size: 26,
                  color: isSelected
                      ? colorScheme.primary
                      : (isDark ? Colors.white54 : const Color(0xFF555555)),
                ),
                const SizedBox(width: 16),

                // Label + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.label,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),

                // Radio check indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? colorScheme.primary : colorScheme.outline,
                      width: 2,
                    ),
                    color: isSelected
                        ? colorScheme.primary
                        : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

