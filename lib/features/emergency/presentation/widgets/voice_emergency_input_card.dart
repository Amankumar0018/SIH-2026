import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/service_locator.dart';
import '../../../../core/services/speech_service.dart';
import '../../../../shared/widgets/app_card.dart';

/// Reusable citizen voice-to-text emergency incident input card.
///
/// Features:
/// - Clear communication: "Describe what is happening"
/// - Distinct states: IDLE, LISTENING, PROCESSING, READY, ERROR, PERMISSION_DENIED
/// - Live speech transcription streamed into an editable [TextEditingController]
/// - Full manual text editing support before submission
/// - Zero audio recording/storage (text-only pass-through to existing incident notes)
class VoiceEmergencyInputCard extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSpeechStarted;
  final VoidCallback? onSpeechStopped;

  const VoiceEmergencyInputCard({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSpeechStarted,
    this.onSpeechStopped,
  });

  @override
  State<VoiceEmergencyInputCard> createState() => _VoiceEmergencyInputCardState();
}

class _VoiceEmergencyInputCardState extends State<VoiceEmergencyInputCard>
    with SingleTickerProviderStateMixin {
  VoiceState _voiceState = VoiceState.idle;
  String? _statusMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  SpeechService get _speechService => ServiceLocator.instance.speechService;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    widget.controller.addListener(_handleTextControllerChanged);
    if (widget.controller.text.trim().isNotEmpty) {
      _voiceState = VoiceState.ready;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextControllerChanged);
    _pulseController.dispose();
    if (_voiceState == VoiceState.listening) {
      _speechService.cancelListening();
    }
    super.dispose();
  }

  void _handleTextControllerChanged() {
    if (mounted && _voiceState == VoiceState.idle && widget.controller.text.trim().isNotEmpty) {
      setState(() {
        _voiceState = VoiceState.ready;
      });
    }
  }

  Future<void> _toggleListening() async {
    if (_voiceState == VoiceState.listening) {
      await _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    final l10n = ServiceLocator.instance.localizationService.l10n;
    setState(() {
      _voiceState = VoiceState.processing;
      _statusMessage = l10n.voiceConnecting;
    });

    try {
      final initialized = await _speechService.initialize(
        onError: (error) {
          if (!mounted) return;
          debugPrint('Speech error received: $error');
          setState(() {
            if (error.contains('error_permission_denied') ||
                error.toLowerCase().contains('permission')) {
              _voiceState = VoiceState.permissionDenied;
              _statusMessage = l10n.voicePermissionDenied;
            } else {
              _voiceState = VoiceState.error;
              _statusMessage = l10n.voiceRecognitionError;
            }
          });
          _pulseController.stop();
          widget.onSpeechStopped?.call();
        },
        onStatus: (status) {
          if (!mounted) return;
          debugPrint('Speech status changed: $status');
          if (status == 'notListening' || status == 'done') {
            if (_voiceState == VoiceState.listening) {
              setState(() {
                _voiceState = widget.controller.text.trim().isNotEmpty
                    ? VoiceState.ready
                    : VoiceState.idle;
                _statusMessage = null;
              });
              _pulseController.stop();
              widget.onSpeechStopped?.call();
            }
          }
        },
      );

      if (!initialized) {
        if (mounted) {
          setState(() {
            if (_voiceState != VoiceState.error) {
              _voiceState = VoiceState.permissionDenied;
              _statusMessage = l10n.voicePermissionDenied;
            }
          });
        }
        return;
      }

      final activeLocale = ServiceLocator.instance.localizationService.currentLanguage.speechLocale;
      final started = await _speechService.startListening(
        localeId: activeLocale,
        onResult: (words, isFinal) {
          if (!mounted) return;
          setState(() {
            widget.controller.text = words;
            widget.controller.selection = TextSelection.fromPosition(
              TextPosition(offset: words.length),
            );
            if (isFinal) {
              _voiceState = VoiceState.ready;
              _statusMessage = l10n.voiceTranscriptCaptured;
              _pulseController.stop();
              widget.onSpeechStopped?.call();
            }
          });
          widget.onChanged?.call(words);
        },
      );

      if (started && mounted) {
        setState(() {
          _voiceState = VoiceState.listening;
          _statusMessage = l10n.voiceListening;
        });
        _pulseController.repeat(reverse: true);
        widget.onSpeechStarted?.call();
      } else if (mounted) {
        setState(() {
          _voiceState = VoiceState.error;
          _statusMessage = l10n.voiceUnavailable;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _voiceState = VoiceState.error;
          _statusMessage = l10n.voiceRecognitionError;
        });
      }
    }
  }

  Future<void> _stopListening() async {
    setState(() {
      _voiceState = VoiceState.processing;
      _statusMessage = 'Processing speech...';
    });
    _pulseController.stop();
    await _speechService.stopListening();
    if (mounted) {
      setState(() {
        _voiceState = widget.controller.text.trim().isNotEmpty
            ? VoiceState.ready
            : VoiceState.idle;
        _statusMessage = widget.controller.text.trim().isNotEmpty
            ? 'Transcript captured (editable)'
            : null;
      });
      widget.onSpeechStopped?.call();
    }
  }

  void _clearTranscript() {
    widget.controller.clear();
    setState(() {
      _voiceState = VoiceState.idle;
      _statusMessage = null;
    });
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = ServiceLocator.instance.localizationService.l10n;
    final isListening = _voiceState == VoiceState.listening;

    return AppCard(
      borderColor: isListening
          ? AppColors.primary
          : (_voiceState == VoiceState.ready
              ? AppColors.success.withValues(alpha: 0.5)
              : null),
      backgroundColor: isListening
          ? AppColors.primary.withValues(alpha: 0.05)
          : null,
      padding: AppDimensions.paddingMd,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isListening
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : AppColors.secondary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.record_voice_over_rounded,
                  size: 18,
                  color: isListening ? AppColors.primary : AppColors.secondaryLight,
                ),
              ),
              const SizedBox(width: AppDimensions.spaceSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.describeEmergencyTitle,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      l10n.describeEmergencySubtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _buildStateBadge(theme, l10n),
            ],
          ),
          const SizedBox(height: AppDimensions.spaceSm),

          // Editable Description Field with Mic button
          Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: AppDimensions.borderRadiusMd,
              border: Border.all(
                color: isListening
                    ? AppColors.primary
                    : theme.colorScheme.outline.withValues(alpha: 0.2),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.controller,
                    onChanged: widget.onChanged,
                    maxLines: 4,
                    minLines: 2,
                    decoration: InputDecoration(
                      hintText: isListening
                          ? l10n.voiceListening
                          : l10n.voiceInputHint,
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isListening
                            ? AppColors.primary.withValues(alpha: 0.8)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      ),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    style: const TextStyle(fontSize: 14, height: 1.35),
                  ),
                ),
                const SizedBox(width: AppDimensions.spaceSm),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.controller.text.isNotEmpty && !isListening)
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: l10n.clearInput,
                        constraints: const BoxConstraints(),
                        padding: const EdgeInsets.all(4),
                        onPressed: _clearTranscript,
                      ),
                    const SizedBox(height: 4),
                    _buildMicrophoneButton(),
                  ],
                ),
              ],
            ),
          ),

          // Status message / State guidance
          if (_statusMessage != null || isListening) ...[
            const SizedBox(height: 6),
            _buildStatusFeedback(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildMicrophoneButton() {
    final isListening = _voiceState == VoiceState.listening;

    Widget micButton = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleListening,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isListening ? AppColors.primary : AppColors.primary.withValues(alpha: 0.12),
            boxShadow: isListening
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Icon(
              isListening ? Icons.stop_rounded : Icons.mic_rounded,
              color: isListening ? AppColors.white : AppColors.primary,
              size: 24,
            ),
          ),
        ),
      ),
    );

    if (isListening) {
      return ScaleTransition(
        scale: _pulseAnimation,
        child: micButton,
      );
    }
    return micButton;
  }

  Widget _buildStateBadge(ThemeData theme, AppLocalizations l10n) {
    switch (_voiceState) {
      case VoiceState.idle:
        return const SizedBox.shrink();
      case VoiceState.listening:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fiber_manual_record, size: 10, color: AppColors.primary),
              SizedBox(width: 4),
              Text(
                'LISTENING',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        );
      case VoiceState.processing:
        return const SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case VoiceState.ready:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.success.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check, size: 12, color: AppColors.success),
              const SizedBox(width: 3),
              Text(
                l10n.readyBadge,
                style: const TextStyle(
                  color: AppColors.success,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      case VoiceState.error:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.error.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'ERROR',
            style: TextStyle(
              color: AppColors.error,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      case VoiceState.permissionDenied:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.warning.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Text(
            'NO MIC PERMISSION',
            style: TextStyle(
              color: AppColors.warning,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
    }
  }

  Widget _buildStatusFeedback(ThemeData theme) {
    Color color;
    IconData icon;

    switch (_voiceState) {
      case VoiceState.listening:
        color = AppColors.primary;
        icon = Icons.graphic_eq_rounded;
        break;
      case VoiceState.ready:
        color = AppColors.success;
        icon = Icons.edit_note_rounded;
        break;
      case VoiceState.error:
        color = AppColors.error;
        icon = Icons.info_outline;
        break;
      case VoiceState.permissionDenied:
        color = AppColors.warning;
        icon = Icons.mic_off_rounded;
        break;
      default:
        color = theme.colorScheme.onSurface.withValues(alpha: 0.6);
        icon = Icons.info_outline;
    }

    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            _statusMessage ?? 'Tap mic again to stop listening',
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
          ),
        ),
        if (_voiceState == VoiceState.permissionDenied || _voiceState == VoiceState.error)
          TextButton(
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: _startListening,
            child: const Text('Retry Mic', style: TextStyle(fontSize: 11)),
          ),
      ],
    );
  }
}
