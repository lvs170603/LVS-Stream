import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';

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
        backgroundColor: const Color(0xFF0f0f13),
        appBar: AppBar(
          backgroundColor: const Color(0xFF141419),
          elevation: 0,
          title: const Text('Settings',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          iconTheme: const IconThemeData(color: Colors.white),
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
              _buildSettingsCard(
                title: "Audio Output",
                icon: Icons.speaker,
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: _isMonoApparentFocus ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
                        boxShadow: _isMonoApparentFocus ? [BoxShadow(color: Colors.white.withAlpha(50), blurRadius: 10, spreadRadius: 1)] : [],
                      ),
                      child: Focus(
                        onFocusChange: (val) => setState(() => _isMonoApparentFocus = val),
                        child: SwitchListTile(
                          title: const Text("Mono Audio", style: TextStyle(color: Colors.white, fontSize: 18)),
                          subtitle: const Text("Combine left and right channels into a single mono channel.", style: TextStyle(color: Colors.white54)),
                          value: isMonoAudio,
                          activeColor: const Color(0xFF4CAF50),
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
                          const Text("Audio Balance",
                              style: TextStyle(color: Colors.white, fontSize: 18)),
                          const SizedBox(height: 20),
                          Row(
                            children: [
                              const Text("Left", style: TextStyle(color: Colors.white54)),
                              Expanded(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: _isSliderApparentFocus ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
                                    boxShadow: _isSliderApparentFocus ? [BoxShadow(color: Colors.white.withAlpha(50), blurRadius: 10, spreadRadius: 1)] : [],
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
                                      }
                                      return KeyEventResult.ignored;
                                    },
                                    child: Slider(
                                      focusNode: _balanceSliderFocusNode,
                                      value: audioBalance,
                                      min: -1.0,
                                      max: 1.0,
                                      divisions: 20,
                                      activeColor: const Color(0xFF4CAF50),
                                      inactiveColor: Colors.white12,
                                      onChanged: _updateAudioBalance,
                                    ),
                                  ),
                                ),
                              ),
                              const Text("Right", style: TextStyle(color: Colors.white54)),
                            ],
                          ),
                          Center(
                            child: Text(
                              audioBalance == 0.0
                                  ? "Center"
                                  : (audioBalance < 0
                                      ? "Left ${(_abs(audioBalance) * 100).toInt()}%"
                                      : "Right ${(_abs(audioBalance) * 100).toInt()}%"),
                              style: const TextStyle(color: Colors.white54, fontSize: 14),
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
                    border: _isAutoLaunchApparentFocus ? Border.all(color: Colors.white, width: 2) : Border.all(color: Colors.transparent, width: 2),
                    boxShadow: _isAutoLaunchApparentFocus ? [BoxShadow(color: Colors.white.withAlpha(50), blurRadius: 10, spreadRadius: 1)] : [],
                  ),
                  child: Focus(
                    onFocusChange: (val) => setState(() => _isAutoLaunchApparentFocus = val),
                    child: SwitchListTile(
                      title: const Text("Auto Launch on TV Start", style: TextStyle(color: Colors.white, fontSize: 18)),
                      subtitle: const Text("Automatically open the app when your device boots up.", style: TextStyle(color: Colors.white54)),
                      value: isAutoLaunch,
                      activeColor: const Color(0xFF4CAF50),
                      onChanged: saveAutoLaunch,
                    ),
                  ),
                ),
              ),
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
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E28),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
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
                Icon(icon, color: const Color(0xFF4CAF50), size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          child,
        ],
      ),
    );
  }
}
