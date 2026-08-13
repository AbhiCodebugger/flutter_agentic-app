import 'package:flutter/material.dart';
import 'package:flutter_agentic_app/presentation/chat/cloud_llm_chat_screen.dart';
import 'package:flutter_agentic_app/presentation/jokes/jokes_screen.dart';
import 'package:flutter_agentic_app/presentation/multimodal/multimodal_vision_screen.dart';
import 'package:flutter_agentic_app/presentation/voice/voice_agent_screen.dart';
import 'package:flutter_agentic_app/provider/jokes_provider.dart';
import 'package:flutter_agentic_app/provider/vision_provider.dart';
import 'package:flutter_agentic_app/provider/voice_agent_provider.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final features = [
      _FeatureItem(
        title: 'Jokes',
        subtitle: 'Generate topic-based jokes with Gemini',
        icon: Icons.emoji_emotions_outlined,
        color: Colors.amber,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider(
                create: (_) => JokesProvider()..fetchJokes(),
                child: const JokesScreen(),
              ),
            ),
          );
        },
      ),
      _FeatureItem(
        title: 'MultiModal Vision',
        subtitle: 'Analyze images with multimodal AI',
        icon: Icons.image_search_outlined,
        color: Colors.teal,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider(
                create: (_) => VisionProvider(),
                child: const MultimodalVisionScreen(),
              ),
            ),
          );
        },
      ),
      _FeatureItem(
        title: 'Voice Agent',
        subtitle: 'Speak commands and trigger function tools',
        icon: Icons.graphic_eq_rounded,
        color: const Color(0xFF00BCD4),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ChangeNotifierProvider(
                create: (_) => VoiceAgentProvider(),
                child: const VoiceAgentScreen(),
              ),
            ),
          );
        },
      ),
      _FeatureItem(
        title: 'Cloud LLM Chat',
        subtitle: 'Chat with a cloud-hosted language model',
        icon: Icons.chat_bubble_outline,
        color: Colors.indigo,
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const CloudLlmChatScreen(),
            ),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Agentic App'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: features.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final feature = features[index];
          return _FeatureCard(feature: feature);
        },
      ),
    );
  }
}

class _FeatureItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _FeatureItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });
}

class _FeatureCard extends StatelessWidget {
  final _FeatureItem feature;

  const _FeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: feature.onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: feature.color.withValues(alpha: 0.15),
                child: Icon(feature.icon, color: feature.color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      feature.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      feature.subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
