import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/models/ai_intelligence.dart';

/// Dedicated UI component rendering structured AI Incident Intelligence for First Responders.
/// 
/// Strictly labeled with "AI Advisory — Verify before action" to remind personnel
/// that recommendations are guidance suggestions and must be verified on scene.
class AIIncidentCard extends StatefulWidget {
  final AIIntelligence intelligence;

  const AIIncidentCard({
    super.key,
    required this.intelligence,
  });

  @override
  State<AIIncidentCard> createState() => _AIIncidentCardState();
}

class _AIIncidentCardState extends State<AIIncidentCard> {
  bool _isExpanded = true;

  Color _getUrgencyColor(String urgency) {
    switch (urgency.toUpperCase()) {
      case 'CRITICAL':
        return AppColors.error;
      case 'HIGH':
        return AppColors.warning;
      case 'MEDIUM':
        return AppColors.info;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ai = widget.intelligence;
    final urgencyColor = _getUrgencyColor(ai.urgencyScore);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1B2E), // Subtle dark indigo-tinted background
        borderRadius: AppDimensions.borderRadiusMd,
        border: Border.all(
          color: const Color(0xFF6366F1).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF6366F1).withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Bar
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.vertical(
              top: const Radius.circular(12),
              bottom: Radius.circular(_isExpanded ? 0 : 12),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFA5B4FC),
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AI INCIDENT INTELLIGENCE',
                    style: TextStyle(
                      color: Color(0xFFE0E7FF),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const Spacer(),
                  // Urgency Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: urgencyColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: urgencyColor.withValues(alpha: 0.6)),
                    ),
                    child: Text(
                      ai.urgencyScore,
                      style: TextStyle(
                        color: urgencyColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.white70,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          if (_isExpanded) ...[
            const Divider(height: 1, color: Color(0xFF312E81)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Mandatory Advisory Disclaimer Banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.amber.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.gavel_rounded, color: Colors.amber, size: 14),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'AI Advisory — Verify before action',
                            style: TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 1. Summary
                  if (ai.summary.isNotEmpty) ...[
                    Text(
                      ai.summary,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 2. Hazards
                  if (ai.hazards.isNotEmpty) ...[
                    const Text(
                      'IDENTIFIED HAZARDS / RISKS',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: ai.hazards.map((hazard) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 12, color: AppColors.error),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  hazard,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // 3. Recommended Responder Guidance
                  if (ai.recommendedActions.isNotEmpty) ...[
                    const Text(
                      'RECOMMENDED RESPONDER GUIDANCE',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...ai.recommendedActions.map((action) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.check_circle_outline, size: 14, color: Color(0xFFA5B4FC)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                action,
                                style: const TextStyle(
                                  color: Color(0xFFE2E8F0),
                                  fontSize: 12,
                                  height: 1.25,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 10),
                  ],

                  // 4. Missing Information Warnings
                  if (ai.missingInfo.isNotEmpty) ...[
                    const Text(
                      'MISSING INFORMATION (VERIFY ON ARRIVAL)',
                      style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...ai.missingInfo.map((info) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.help_outline, size: 14, color: Colors.orangeAccent),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                info,
                                style: const TextStyle(
                                  color: Color(0xFFCBD5E1),
                                  fontSize: 11,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],

                  // Footer: Source and Confidence
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Engine: ${ai.isLlm ? "Gemini AI" : "Deterministic Rule Engine"}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF64748B)),
                      ),
                      Text(
                        'Confidence: ${(ai.confidence * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
