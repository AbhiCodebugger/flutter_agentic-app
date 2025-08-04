import 'dart:developer';

import 'package:flutter_agentic_app/model/joke.dart';
import 'package:flutter_agentic_app/provider/base_provider.dart';
import 'package:flutter_agentic_app/services/gemini_service.dart';

class JokesProvider extends BaseProvider {
  // Private state variables
  List<Jokes> _jokes = [];
  int _currentPage = 1;
  final int _limit = 15;
  bool _hasMore = true;
  String _currentTopic = "Corporate";

  // Public getters to access state safely
  List<Jokes> get jokes => _jokes;
  bool get hasMore => _hasMore;
  String get currentTopic => _currentTopic;
  final List<String> topics = const ["Puns", "Tech", "Corporate", "Marriage"];

  // Fetches jokes, handling both new topics and pagination.
  Future<void> fetchJokes({bool isRefresh = false}) async {
    if (isLoading) return; // Prevent multiple simultaneous requests

    setLoading(true);
    clearError();

    // Reset state if it's a refresh (new topic or pull-to-refresh)
    if (isRefresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    try {
      final json = await GeminiService.instance.generateJokes(
        topics: [_currentTopic], // Fetch jokes for the current topic
        page: _currentPage,
        limit: _limit,
      );

      if (json == null) {
        setError('Failed to fetch jokes. The server returned no data.');
        return; // Early exit
      }

      final response = JokeResponse.fromJson(json);

      if (isRefresh) {
        _jokes = response.jokes; // Replace the list on refresh
      } else {
        _jokes.addAll(response.jokes); // Add to the list when loading more
      }

      _hasMore = (_jokes.length < response.total);
      if (_hasMore) {
        _currentPage++;
      }
    } catch (e, stackTrace) {
      log('Error in fetchJokes: $e', stackTrace: stackTrace);
      setError('An unexpected error occurred. Please try again.');
    } finally {
      setLoading(false); // This will also call notifyListeners()
    }
  }

  // Changes the current topic and fetches new jokes.
  void changeTopic(String newTopic) {
    if (newTopic != _currentTopic) {
      _currentTopic = newTopic;
      // The UI will now be responsible for triggering the refresh.
      // This allows the UI to show a loading indicator before fetching.
      notifyListeners();
    }
  }
}
