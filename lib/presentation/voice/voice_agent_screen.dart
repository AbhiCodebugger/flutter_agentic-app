import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_agentic_app/provider/voice_agent_provider.dart';
import 'package:provider/provider.dart';

class VoiceAgentScreen extends StatefulWidget {
  const VoiceAgentScreen({super.key});

  @override
  State<VoiceAgentScreen> createState() => _VoiceAgentScreenState();
}

class _VoiceAgentScreenState extends State<VoiceAgentScreen>
    with SingleTickerProviderStateMixin {
  final _textController = TextEditingController();
  late final AnimationController _pulseController;

  static const _bg = Color(0xFF05070F);
  static const _cyan = Color(0xFF00E5FF);
  static const _violet = Color(0xFF7C4DFF);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.white,
        title: const Text('Voice Agent'),
        actions: [
          IconButton(
            tooltip: 'Reset session',
            onPressed: () => context.read<VoiceAgentProvider>().clearSession(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.35),
            radius: 1.1,
            colors: [Color(0xFF10182B), _bg],
          ),
        ),
        child: SafeArea(
          child: Consumer<VoiceAgentProvider>(
            builder: (context, provider, _) {
              return Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      children: [
                        _StatusHeader(phase: provider.phase),
                        const SizedBox(height: 28),
                        Center(
                          child: _VoiceOrb(
                            controller: _pulseController,
                            phase: provider.phase,
                            soundLevel: provider.soundLevel,
                            onTap: provider.toggleListening,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _hintForPhase(provider),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            letterSpacing: 0.4,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (provider.partialTranscript.isNotEmpty)
                          _GlassPanel(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TRANSCRIPT',
                                  style: TextStyle(
                                    color: _cyan.withValues(alpha: 0.8),
                                    fontSize: 11,
                                    letterSpacing: 1.6,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  provider.partialTranscript,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        if (provider.activeTools.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ...provider.activeTools.map(
                            (tool) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ToolChip(tool: tool),
                            ),
                          ),
                        ],
                        if (provider.lastReply.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _GlassPanel(
                            accent: _violet,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AGENT',
                                  style: TextStyle(
                                    color: _violet.withValues(alpha: 0.9),
                                    fontSize: 11,
                                    letterSpacing: 1.6,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  provider.lastReply,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (provider.errorMessage != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            provider.errorMessage!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Color(0xFFFF6B8A)),
                          ),
                        ],
                        if (provider.turns.length > 1) ...[
                          const SizedBox(height: 28),
                          Text(
                            'SESSION MEMORY',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 11,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...provider.turns.skip(1).take(4).map(
                            (turn) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _HistoryCard(turn: turn),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  _Composer(
                    controller: _textController,
                    enabled: provider.phase != VoiceAgentPhase.thinking,
                    onSubmit: () async {
                      final text = _textController.text;
                      _textController.clear();
                      await provider.submitText(text);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _hintForPhase(VoiceAgentProvider provider) {
    return switch (provider.phase) {
      VoiceAgentPhase.idle =>
        'Tap the orb and say “What’s the weather in New York?”',
      VoiceAgentPhase.listening => 'Listening… speak naturally',
      VoiceAgentPhase.thinking => 'Routing tools & synthesizing reply…',
      VoiceAgentPhase.speaking => 'Reply ready',
    };
  }
}

class _StatusHeader extends StatelessWidget {
  final VoiceAgentPhase phase;

  const _StatusHeader({required this.phase});

  @override
  Widget build(BuildContext context) {
    final label = switch (phase) {
      VoiceAgentPhase.idle => 'STANDBY',
      VoiceAgentPhase.listening => 'LIVE MIC',
      VoiceAgentPhase.thinking => 'TOOL ROUTING',
      VoiceAgentPhase.speaking => 'RESPONSE',
    };

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: phase == VoiceAgentPhase.listening
                ? const Color(0xFF00E5FF)
                : phase == VoiceAgentPhase.thinking
                ? const Color(0xFFFFB86C)
                : const Color(0xFF7C4DFF),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.5),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.8),
            letterSpacing: 2,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        Text(
          'FUNCTION TOOLS ONLINE',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 10,
            letterSpacing: 1.1,
          ),
        ),
      ],
    );
  }
}

class _VoiceOrb extends StatelessWidget {
  final AnimationController controller;
  final VoiceAgentPhase phase;
  final double soundLevel;
  final VoidCallback onTap;

  const _VoiceOrb({
    required this.controller,
    required this.phase,
    required this.soundLevel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active =
        phase == VoiceAgentPhase.listening || phase == VoiceAgentPhase.thinking;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final t = controller.value;
        final levelBoost = phase == VoiceAgentPhase.listening
            ? (soundLevel.abs() / 40).clamp(0.0, 0.35)
            : 0.0;

        return SizedBox(
          width: 220,
          height: 220,
          child: Stack(
            alignment: Alignment.center,
            children: [
              for (var i = 0; i < 3; i++)
                CustomPaint(
                  size: const Size(220, 220),
                  painter: _RingPainter(
                    progress: (t + i / 3) % 1.0,
                    intensity: active ? 0.55 + levelBoost : 0.2,
                    color: i.isEven
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFF7C4DFF),
                  ),
                ),
              GestureDetector(
                onTap: onTap,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: 108 + levelBoost * 40,
                  height: 108 + levelBoost * 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: phase == VoiceAgentPhase.listening
                          ? const [Color(0xFF00E5FF), Color(0xFF2979FF)]
                          : const [Color(0xFF7C4DFF), Color(0xFF00E5FF)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                        blurRadius: 28,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    phase == VoiceAgentPhase.listening
                        ? Icons.graphic_eq_rounded
                        : phase == VoiceAgentPhase.thinking
                        ? Icons.auto_awesome
                        : Icons.mic_none_rounded,
                    color: Colors.white,
                    size: 42,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final double intensity;
  final Color color;

  _RingPainter({
    required this.progress,
    required this.intensity,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * (0.28 + progress * 0.28);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..color = color.withValues(alpha: (1 - progress) * intensity);

    canvas.drawCircle(center, radius, paint);

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
      ..color = color.withValues(alpha: (1 - progress) * intensity * 0.35);
    canvas.drawCircle(center, radius, glow);

    // Soft arc accent
    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = color.withValues(alpha: (1 - progress) * intensity);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      progress * math.pi * 2,
      math.pi * 0.55,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.intensity != intensity ||
        oldDelegate.color != color;
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  final Color accent;

  const _GlassPanel({
    required this.child,
    this.accent = const Color(0xFF00E5FF),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 18,
          ),
        ],
      ),
      child: child,
    );
  }
}

class _ToolChip extends StatelessWidget {
  final ToolCallLog tool;

  const _ToolChip({required this.tool});

  @override
  Widget build(BuildContext context) {
    final running = !tool.isComplete;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0B1220),
        border: Border.all(
          color: running
              ? const Color(0xFFFFB86C).withValues(alpha: 0.55)
              : const Color(0xFF00E5FF).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          Icon(
            running ? Icons.bolt : Icons.check_circle_outline,
            size: 18,
            color: running
                ? const Color(0xFFFFB86C)
                : const Color(0xFF00E5FF),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tool.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  running
                      ? 'Calling with ${tool.args}'
                      : 'Returned ${tool.result}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final VoiceTurn turn;

  const _HistoryCard({required this.turn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.03),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'You: ${turn.userText}',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75)),
          ),
          if (turn.agentText != null) ...[
            const SizedBox(height: 6),
            Text(
              'Agent: ${turn.agentText}',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
            ),
          ],
          if (turn.tools.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Tools: ${turn.tools.map((t) => t.name).join(', ')}',
              style: const TextStyle(
                color: Color(0xFF00E5FF),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSubmit;

  const _Composer({
    required this.controller,
    required this.enabled,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              style: const TextStyle(color: Colors.white),
              cursorColor: const Color(0xFF00E5FF),
              decoration: InputDecoration(
                hintText: 'Or type a command…',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: Color(0xFF00E5FF)),
                ),
              ),
              onSubmitted: (_) => onSubmit(),
            ),
          ),
          const SizedBox(width: 10),
          IconButton.filled(
            onPressed: enabled ? onSubmit : null,
            style: IconButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: const Color(0xFF05070F),
            ),
            icon: const Icon(Icons.send_rounded),
          ),
        ],
      ),
    );
  }
}
