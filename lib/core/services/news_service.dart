import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:milow/core/models/news_article.dart';

class NewsService {
  static const String _newsBoxName = 'news_cache';
  static const String _newsKey = 'trucking_news';
  static const String _lastFetchKey = 'last_fetch_time';
  // Cache duration of 24 hours to stay well under 100 requests/day
  static const Duration _cacheDuration = Duration(hours: 24);

  /// Fetch trucking news, using cache if available and valid
  static Future<List<NewsArticle>> getTruckingNews() async {
    final box = await Hive.openBox(_newsBoxName);
    final lastFetch = box.get(_lastFetchKey) as DateTime?;
    final cachedData = box.get(_newsKey);

    // Check if cache is valid
    if (lastFetch != null &&
        cachedData != null &&
        DateTime.now().difference(lastFetch) < _cacheDuration) {
      print('DEBUG: Returning cached news from: $lastFetch');
      final List<dynamic> decoded = jsonDecode(cachedData);
      return decoded.map((json) => NewsArticle.fromJson(json)).toList();
    }

    print(
      'DEBUG: Cache expired or missing (Last fetch: $lastFetch). Fetching from API...',
    );

    // Cache expired or missing, fetch from API
    try {
      return await _fetchFromApi(box);
    } catch (e) {
      print('DEBUG: API Error: $e');
      // If API fails, try to return stale cache if available
      if (cachedData != null) {
        print('DEBUG: Returning stale cache due to API error.');
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((json) => NewsArticle.fromJson(json)).toList();
      }
      rethrow;
    }
  }

  static Future<List<NewsArticle>> _fetchFromApi(Box box) async {
    final apiKey = dotenv.env['NEWS_API_KEY'];
    print('DEBUG: API Key present: ${apiKey != null && apiKey.isNotEmpty}');
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception('NEWS_API_KEY not found in .env');
    }

    final url = Uri.parse(
      'https://newsapi.org/v2/everything?q=trucking OR logistics OR freight transport&language=en&sortBy=publishedAt&apiKey=$apiKey',
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final articlesJson = data['articles'] as List;

      // Convert to NewsArticle objects
      final articles = articlesJson
          .map((json) => NewsArticle.fromJson(json))
          // Filter out removed articles or broken sources
          .where((article) => article.title != '[Removed]')
          .take(20) // Limit to 20 items
          .toList();

      // Cache the raw JSON list string (simpler serialization)
      final cacheJson = jsonEncode(articles.map((a) => a.toJson()).toList());
      await box.put(_newsKey, cacheJson);
      await box.put(_lastFetchKey, DateTime.now());

      return articles;
    } else {
      throw Exception('Failed to load news: ${response.statusCode}');
    }
  }
}
