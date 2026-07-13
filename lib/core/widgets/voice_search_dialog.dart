import 'dart:async';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../constants/app_colors.dart';

class VoiceSearchDialog extends StatefulWidget {
  const VoiceSearchDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const VoiceSearchDialog(),
    );
  }

  @override
  State<VoiceSearchDialog> createState() => _VoiceSearchDialogState();
}

class _VoiceSearchDialogState extends State<VoiceSearchDialog> with SingleTickerProviderStateMixin {
  late stt.SpeechToText _speech;
  bool _isListening = false;
  bool _speechAvailable = false;
  String _text = 'Say something...';
  double _soundLevel = 0.0;
  
  // Simulated waves controller
  late AnimationController _waveController;
  final TextEditingController _fallbackController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _initSpeech();
  }

  @override
  void dispose() {
    _waveController.dispose();
    _fallbackController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'listening') {
            setState(() => _isListening = true);
          } else {
            setState(() => _isListening = false);
          }
        },
        onError: (val) {
          debugPrint('Speech init error: $val');
          setState(() {
            _speechAvailable = false;
            _text = 'Offline/Mock Mode. Type search query below:';
          });
        },
      );
      if (available) {
        setState(() {
          _speechAvailable = true;
          _text = 'Listening... Speak now';
        });
        _startListening();
      } else {
        setState(() {
          _speechAvailable = false;
          _text = 'Speech recognition unavailable. Type below:';
        });
      }
    } catch (e) {
      debugPrint('Speech exception: $e');
      setState(() {
        _speechAvailable = false;
        _text = 'Speech recognition error. Type below:';
      });
    }
  }

  void _startListening() async {
    if (!_speechAvailable) return;
    await _speech.listen(
      onResult: (val) {
        setState(() {
          _text = val.recognizedWords;
          if (val.finalResult) {
            // Close after 1 second if final result is recognized
            Future.delayed(const Duration(milliseconds: 1000), () {
              if (mounted) {
                Navigator.of(context).pop(_text);
              }
            });
          }
        });
      },
      onSoundLevelChange: (level) {
        setState(() {
          _soundLevel = level;
        });
      },
    );
    setState(() => _isListening = true);
  }

  void _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Voice Search',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),

            // Sound Wave Indicator
            Center(
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, child) {
                  double levelScale = _speechAvailable ? (1.0 + _soundLevel * 0.2) : (1.0 + _waveController.value * 0.3);
                  return Container(
                    height: 80,
                    width: 80,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Transform.scale(
                        scale: levelScale,
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: _isListening ? AppColors.primary : Colors.grey,
                          child: const Icon(
                            Icons.mic_rounded,
                            color: Colors.white,
                            size: 26,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),

            // Recognized text
            Text(
              _text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
              ),
            ),
            
            // Fallback manual simulation
            if (!_speechAvailable) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _fallbackController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Simulation search term',
                  hintText: 'Enter search keywords',
                  prefixIcon: Icon(Icons.keyboard_rounded),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    Navigator.of(context).pop(val.trim());
                  }
                },
              ),
            ],
            const SizedBox(height: 24),

            // Dialog controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                ),
                if (_speechAvailable)
                  ElevatedButton(
                    onPressed: _isListening ? _stopListening : _startListening,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isListening ? Colors.red : AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_isListening ? 'Stop' : 'Listen'),
                  )
                else
                  ElevatedButton(
                    onPressed: () {
                      final term = _fallbackController.text.trim();
                      if (term.isNotEmpty) {
                        Navigator.of(context).pop(term);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Search'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
