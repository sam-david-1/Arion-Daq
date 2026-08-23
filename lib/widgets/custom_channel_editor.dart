import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/settings_service.dart';
import '../services/math_channel_service.dart';
import '../state/daq_provider.dart';
import '../theme/racing_theme.dart';

class CustomChannelEditor extends StatefulWidget {
  const CustomChannelEditor({super.key});

  @override
  State<CustomChannelEditor> createState() => _CustomChannelEditorState();
}

class _CustomChannelEditorState extends State<CustomChannelEditor> {
  List<CustomChannel> _channels = [];

  @override
  void initState() {
    super.initState();
    _loadChannels();
  }

  void _loadChannels() {
    final jsonList = SettingsService().customChannelsJson;
    setState(() {
      _channels = jsonList.map((e) => CustomChannel.fromJson(e)).toList();
    });
  }

  void _saveChannels() async {
    await SettingsService().setCustomChannelsJson(_channels.map((e) => e.toJson()).toList());
    if (mounted) {
      Provider.of<DaqProvider>(context, listen: false).refreshCustomChannels();
    }
  }

  void _showAddEditDialog([CustomChannel? channel]) {
    final isEditing = channel != null;
    final nameController = TextEditingController(text: channel?.name ?? '');
    final expressionController = TextEditingController(text: channel?.expression ?? '');
    final unitController = TextEditingController(text: channel?.unit ?? '');
    String? errorText;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: RacingTheme.panel,
              title: Text(isEditing ? 'Edit Math Channel' : 'Add Math Channel', style: const TextStyle(color: Colors.white)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Channel Name',
                        labelStyle: TextStyle(color: RacingTheme.textSecondary),
                        filled: true,
                        fillColor: RacingTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: expressionController,
                      style: const TextStyle(color: Colors.white, fontFamily: 'JetBrains Mono'),
                      decoration: InputDecoration(
                        labelText: 'Formula (e.g., deriv(Brake_Bar) * 2)',
                        labelStyle: TextStyle(color: RacingTheme.textSecondary),
                        filled: true,
                        fillColor: RacingTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        errorText: errorText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: unitController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        labelText: 'Unit (e.g., psi/s)',
                        labelStyle: TextStyle(color: RacingTheme.textSecondary),
                        filled: true,
                        fillColor: RacingTheme.background,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Available variables: TPS_Deg, Brake_Bar, Angle.\nUse deriv(channel) for rate of change.',
                      style: TextStyle(color: RacingTheme.textSecondary, fontSize: 12),
                    )
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel', style: TextStyle(color: RacingTheme.textSecondary)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: RacingTheme.primaryAccent),
                  onPressed: () {
                    final name = nameController.text.trim();
                    final expr = expressionController.text.trim();
                    final unit = unitController.text.trim();

                    if (name.isEmpty || expr.isEmpty) {
                      setModalState(() => errorText = 'Name and Formula cannot be empty');
                      return;
                    }

                    if (!MathChannelService().validateExpression(expr)) {
                      setModalState(() => errorText = 'Invalid math expression');
                      return;
                    }

                    if (isEditing) {
                      channel.name = name;
                      channel.expression = expr;
                      channel.unit = unit;
                    } else {
                      _channels.add(CustomChannel(
                        id: const Uuid().v4(),
                        name: name,
                        expression: expr,
                        unit: unit,
                      ));
                    }

                    _saveChannels();
                    Navigator.pop(context);
                    setState(() {});
                  },
                  child: const Text('Save', style: TextStyle(color: Colors.black)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _deleteChannel(CustomChannel channel) {
    setState(() {
      _channels.remove(channel);
    });
    _saveChannels();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: RacingTheme.panel,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 600,
        height: 500,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Math Channels', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: RacingTheme.primaryAccent),
                  onPressed: () => _showAddEditDialog(),
                  icon: const Icon(Icons.add, color: Colors.black, size: 16),
                  label: const Text('Add Channel', style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _channels.isEmpty
                  ? Center(child: Text('No custom channels defined.', style: TextStyle(color: RacingTheme.textSecondary)))
                  : ListView.builder(
                      itemCount: _channels.length,
                      itemBuilder: (context, index) {
                        final channel = _channels[index];
                        return Card(
                          color: RacingTheme.background,
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(channel.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            subtitle: Text('${channel.expression}  [${channel.unit}]', style: TextStyle(color: RacingTheme.textSecondary, fontFamily: 'JetBrains Mono')),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blueAccent),
                                  onPressed: () => _showAddEditDialog(channel),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.redAccent),
                                  onPressed: () => _deleteChannel(channel),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Close', style: TextStyle(color: RacingTheme.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
