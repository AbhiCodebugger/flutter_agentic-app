import 'package:flutter/material.dart';
import 'package:flutter_agentic_app/model/joke.dart';
import 'package:flutter_agentic_app/provider/jokes_provider.dart';
import 'package:provider/provider.dart';

class JokesScreen extends StatefulWidget {
  const JokesScreen({super.key});

  @override
  State<JokesScreen> createState() => _JokesScreenState();
}

class _JokesScreenState extends State<JokesScreen> {
  final _scrollController = ScrollController();
  final _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.9) {
      final provider = context.read<JokesProvider>();
      if (provider.hasMore && !provider.isLoading) {
        provider.fetchJokes();
      }
    }
  }

  void _onTopicChanged(String newTopic) {
    final provider = context.read<JokesProvider>();
    if (provider.currentTopic != newTopic) {
      provider.changeTopic(newTopic);
      _refreshIndicatorKey.currentState?.show();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Jokes')),
      body: Consumer<JokesProvider>(
        builder: (context, provider, _) {
          return Column(
            children: [
              _buildTopicChips(provider),
              const SizedBox(height: 10),
              Expanded(child: _buildContent(provider)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTopicChips(JokesProvider provider) {
    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: provider.topics.length,
        itemBuilder: (context, index) {
          final topic = provider.topics[index];
          return ChoiceChip(
            label: Text(topic),
            selected: provider.currentTopic == topic,
            onSelected: (_) => _onTopicChanged(topic),
          );
        },
        separatorBuilder: (_, __) => const SizedBox(width: 8),
      ),
    );
  }

  Widget _buildContent(JokesProvider provider) {
    if (provider.isLoading && provider.jokes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.jokes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              provider.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _refreshIndicatorKey.currentState?.show(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }

    if (provider.jokes.isEmpty && !provider.isLoading) {
      return const Center(
        child: Text('No jokes found for this topic. Try another one!'),
      );
    }

    return _buildJokesList(provider);
  }

  Widget _buildJokesList(JokesProvider provider) {
    return RefreshIndicator(
      key: _refreshIndicatorKey,
      onRefresh: () => provider.fetchJokes(isRefresh: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount:
            provider.jokes.length +
            (provider.isLoading && provider.jokes.isNotEmpty ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == provider.jokes.length) {
            return const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final joke = provider.jokes[index];
          return _JokeCard(joke: joke);
        },
      ),
    );
  }
}

class _JokeCard extends StatelessWidget {
  final Jokes joke;

  const _JokeCard({required this.joke});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '"${joke.joke}"',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              '- ${joke.author}',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              joke.date,
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}
