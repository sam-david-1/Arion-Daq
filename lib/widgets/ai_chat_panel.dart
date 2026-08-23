import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../state/daq_provider.dart';
import '../theme/racing_theme.dart';
import '../services/settings_service.dart';

class AiChatPanel extends StatefulWidget {
  const AiChatPanel({super.key});

  @override
  State<AiChatPanel> createState() => _AiChatPanelState();
}

class _AiChatPanelState extends State<AiChatPanel> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendMessage(DaqProvider provider) async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

    await provider.askAi(text);
    
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Widget _buildModelIcon(String model) {
    bool isGemini = model.toLowerCase().contains('gemini');
    return Container(
      width: 14, height: 14,
      decoration: BoxDecoration(
        color: isGemini ? Colors.blueAccent : Colors.orangeAccent, 
        shape: BoxShape.circle
      ),
      child: Center(
        child: Text(
          isGemini ? 'G' : 'Q', 
          style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)
        )
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DaqProvider>(
      builder: (context, provider, child) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
        bool hasData = provider.loadedLogData.isNotEmpty;
        
        return Container(
          decoration: BoxDecoration(
            color: RacingTheme.panel,
            border: Border(right: BorderSide(color: RacingTheme.border, width: 1)),
          ),
          child: Column(
            children: [
              // Top Section (48px)
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: RacingTheme.border))),
                width: double.infinity,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('AI ANALYST', style: TextStyle(fontSize: 11, letterSpacing: 1.0, color: RacingTheme.primaryAccent, fontWeight: FontWeight.bold)),
                        Text(provider.activeTabName, style: TextStyle(fontSize: 10, color: RacingTheme.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Model Selector Row (removed)
              
              // Chat History
              Expanded(
                child: !hasData 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.smart_toy, size: 24, color: RacingTheme.textMuted),
                        const SizedBox(height: 8),
                        Text('Load a session to\nbegin AI analysis', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: RacingTheme.textMuted)),
                      ],
                    ),
                  )
                : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  itemCount: provider.chatHistory.length,
                  itemBuilder: (context, index) {
                    final msg = provider.chatHistory[index];
                    bool isUser = msg.role == 'user';
                    bool isError = msg.role == 'error';
                    
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (!isUser) Padding(
                            padding: const EdgeInsets.only(right: 6, top: 4),
                            child: isError ? Icon(Icons.error, size: 14, color: Colors.white) : _buildModelIcon(msg.model),
                          ),
                          Flexible(
                            child: Column(
                              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isError ? Colors.red : (isUser ? RacingTheme.primaryAccent : RacingTheme.chatBubble),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: MarkdownBody(
                                    data: msg.content,
                                    styleSheet: MarkdownStyleSheet(
                                      p: TextStyle(fontSize: 11, color: isUser ? RacingTheme.primaryAccentText : RacingTheme.textPrimary),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}',
                                      style: TextStyle(fontSize: 9, color: RacingTheme.textMuted),
                                    ),
                                    const SizedBox(width: 8),
                                    InkWell(
                                      onTap: () {
                                        Clipboard.setData(ClipboardData(text: msg.content));
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                                        );
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                        child: Icon(Icons.copy, size: 10, color: RacingTheme.textMuted),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              if (provider.isAiLoading)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: RacingTheme.primaryAccent)),
                      const SizedBox(width: 8),
                      Text('AI is thinking...', style: TextStyle(fontSize: 10, color: RacingTheme.primaryAccent, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),
              
              // Input Row (fixed bottom)
              Container(
                decoration: BoxDecoration(border: Border(top: BorderSide(color: RacingTheme.border))),
                padding: const EdgeInsets.all(8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(color: RacingTheme.background, borderRadius: BorderRadius.circular(4), border: Border.all(color: RacingTheme.border)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: SettingsService().aiProvider,
                          dropdownColor: RacingTheme.panel,
                          iconSize: 14,
                          style: TextStyle(color: RacingTheme.primaryAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          items: const [
                            DropdownMenuItem(value: 'gemini', child: Text('GEMINI')),
                            DropdownMenuItem(value: 'groq', child: Text('GROQ')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              SettingsService().setAiProvider(val).then((_) {
                                setState(() {});
                              });
                            }
                          },
                        ),
                      ),
                    ),
                    Expanded(
                      child: Focus(
                        onKeyEvent: (node, event) {
                          if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.enter && !HardwareKeyboard.instance.isShiftPressed) {
                            _sendMessage(provider);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: _controller,
                          maxLines: 3,
                          minLines: 1,
                          style: TextStyle(fontSize: 11, color: RacingTheme.textPrimary),
                          enabled: !provider.isAiLoading,
                          decoration: InputDecoration(
                            hintText: 'Ask about this session...',
                            hintStyle: TextStyle(fontSize: 11, color: RacingTheme.textMuted),
                            filled: true,
                            fillColor: RacingTheme.chatBubble,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            border: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: RacingTheme.border)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      height: 32,
                      width: 32,
                      decoration: BoxDecoration(color: (provider.isAiLoading) ? Colors.grey : RacingTheme.primaryAccent, borderRadius: BorderRadius.circular(4)),
                      child: IconButton(
                        icon: const Icon(Icons.send, size: 16, color: Colors.black),
                        padding: EdgeInsets.zero,
                        onPressed: (provider.isAiLoading) ? null : () => _sendMessage(provider),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
