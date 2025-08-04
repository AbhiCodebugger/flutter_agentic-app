class JokeResponse {
  final int total;
  final int currentPage;
  final List<Jokes> jokes;
  final List<String> topic;

  JokeResponse({
    required this.total,
    required this.currentPage,
    required this.jokes,
    required this.topic,
  });

  factory JokeResponse.fromJson(Map<String, dynamic> json) => JokeResponse(
    total: json['total'],
    currentPage: json['current_page'],
    jokes: List<Jokes>.from(
      (json['jokes'] as List).map((q) => Jokes.fromJson(q)),
    ),
    topic: json['topic'].cast<String>(),
  );
}

class Jokes {
  final String joke;
  final String author;
  final String date;

  Jokes({required this.joke, required this.author, required this.date});

  factory Jokes.fromJson(Map<String, dynamic> json) =>
      Jokes(joke: json['joke'], author: json['author'], date: json['date']);
}
