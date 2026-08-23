import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../state/daq_provider.dart';
import '../../theme/mobile_theme.dart';

class MobileSettingsScreen extends StatefulWidget {
  const MobileSettingsScreen({super.key});

  @override
  State<MobileSettingsScreen> createState() => _MobileSettingsScreenState();
}

class _MobileSettingsScreenState extends State<MobileSettingsScreen> {
  final _driverNameController = TextEditingController();
  final _driverNumberController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _driverNameController.text = SettingsService().driverName;
    _driverNumberController.text = SettingsService().driverNumber;
  }

  void _saveString(String key, String value) {
    if (key == 'driverName') SettingsService().setDriverName(value);
    if (key == 'driverNumber') SettingsService().setDriverNumber(value);
    Provider.of<DaqProvider>(context, listen: false).reloadSettings();
  }

  void _saveDouble(String key, double value) {
    if (key == 'brakeWarningThreshold') SettingsService().setBrakeWarningThreshold(value);
    if (key == 'brakeDangerThreshold') SettingsService().setBrakeDangerThreshold(value);
    if (key == 'tpsWotThreshold') SettingsService().setTpsWotThreshold(value);
    Provider.of<DaqProvider>(context, listen: false).reloadSettings();
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 32, bottom: 12, left: 24),
      child: Text(title, style: const TextStyle(color: MobileTheme.primaryNeon, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, String key) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: MobileTheme.glassDecoration(radius: 16),
      child: TextField(
        controller: controller,
        style: const TextStyle(color: MobileTheme.textBright, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: MobileTheme.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        onSubmitted: (val) => _saveString(key, val),
      ),
    );
  }

  Widget _buildSliderPref(String label, String key, double value, double min, double max) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: MobileTheme.glassDecoration(radius: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: MobileTheme.textBright, fontSize: 16)),
              Text(value.toStringAsFixed(1), style: const TextStyle(color: MobileTheme.primaryNeon, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Fira Code')),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: MobileTheme.primaryNeon,
              inactiveTrackColor: Colors.white.withOpacity(0.1),
              thumbColor: MobileTheme.primaryNeon,
              overlayColor: MobileTheme.primaryNeon.withOpacity(0.2),
              trackHeight: 4,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              onChanged: (val) {
                setState(() {
                  _saveDouble(key, val);
                });
              },
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 120),
      children: [
        _buildSectionHeader('DRIVER PROFILE'),
        _buildTextField('Driver Name', _driverNameController, 'driverName'),
        _buildTextField('Driver Number', _driverNumberController, 'driverNumber'),
        
        _buildSectionHeader('THRESHOLDS'),
        _buildSliderPref('Brake Warning (bar)', 'brakeWarningThreshold', SettingsService().brakeWarningThreshold, 10, 80),
        _buildSliderPref('Brake Danger (bar)', 'brakeDangerThreshold', SettingsService().brakeDangerThreshold, 20, 100),
        _buildSliderPref('TPS WOT Threshold (%)', 'tpsWotThreshold', SettingsService().tpsWotThreshold, 50, 100),
      ],
    );
  }
}
