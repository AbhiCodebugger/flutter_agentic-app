import 'package:flutter/material.dart';
import 'package:flutter_agentic_app/provider/vision_provider.dart';
import 'package:provider/provider.dart';

class MultimodalVisionScreen extends StatelessWidget {
  const MultimodalVisionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MultiModal Vision'),
        actions: [
          Consumer<VisionProvider>(
            builder: (context, provider, _) {
              if (!provider.hasImage) return const SizedBox.shrink();
              return IconButton(
                tooltip: 'Clear image',
                onPressed: provider.isLoading || provider.isCompressing
                    ? null
                    : provider.clearImage,
                icon: const Icon(Icons.delete_outline),
              );
            },
          ),
        ],
      ),
      body: Consumer<VisionProvider>(
        builder: (context, provider, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ImagePreview(provider: provider),
              const SizedBox(height: 16),
              _ActionButtons(provider: provider),
              const SizedBox(height: 16),
              TextField(
                onChanged: provider.updatePrompt,
                enabled: !provider.isLoading && !provider.isCompressing,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Prompt (optional)',
                  hintText:
                      'Ask something specific, or leave blank for a full explanation.',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed:
                    provider.hasImage &&
                        !provider.isLoading &&
                        !provider.isCompressing
                    ? provider.analyzeCurrentImage
                    : null,
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Explain with Gemini'),
              ),
              if (provider.originalBytes != null &&
                  provider.compressedBytes != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Compressed before upload: '
                  '${_formatBytes(provider.originalBytes!)} → '
                  '${_formatBytes(provider.compressedBytes!)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              if (provider.errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  provider.errorMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 20),
              _ExplanationCard(provider: provider),
            ],
          );
        },
      ),
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)}KB';
    return '${(kb / 1024).toStringAsFixed(1)}MB';
  }
}

class _ImagePreview extends StatelessWidget {
  final VisionProvider provider;

  const _ImagePreview({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (provider.imageBytes != null)
                Image.memory(provider.imageBytes!, fit: BoxFit.cover)
              else
                const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_search_outlined, size: 48),
                      SizedBox(height: 8),
                      Text('Capture or choose a photo to analyze'),
                    ],
                  ),
                ),
              if (provider.isCompressing || provider.isLoading)
                ColoredBox(
                  color: Colors.black45,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(color: Colors.white),
                        const SizedBox(height: 12),
                        Text(
                          provider.isCompressing
                              ? 'Compressing image…'
                              : 'Gemini is explaining…',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final VisionProvider provider;

  const _ActionButtons({required this.provider});

  @override
  Widget build(BuildContext context) {
    final busy = provider.isLoading || provider.isCompressing;

    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : provider.captureFromCamera,
            icon: const Icon(Icons.photo_camera_outlined),
            label: const Text('Camera'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: busy ? null : provider.pickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Gallery'),
          ),
        ),
      ],
    );
  }
}

class _ExplanationCard extends StatelessWidget {
  final VisionProvider provider;

  const _ExplanationCard({required this.provider});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = provider.explanation;

    if (text == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'The multimodal response (text + image) will appear here.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gemini explanation',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(text),
          ],
        ),
      ),
    );
  }
}
