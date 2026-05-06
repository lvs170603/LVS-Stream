import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/channel.dart';

class ApiService {
  // Use the production backend on Render
  static const String baseUrl = 'https://lvs-streem-backend.onrender.com/api';

  Future<List<Channel>> fetchChannels() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/channels'));

      if (response.statusCode == 200) {
        List<dynamic> body = jsonDecode(response.body);
        List<Channel> channels = body
            .map((dynamic item) => Channel.fromJson(item))
            .where((channel) => channel.isActive)
            .toList();
        return channels;
      } else {
        throw Exception('Failed to load channels: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching channels: $e');
    }
  }

  /// Fetches the stream/webPlayer URL for a specific channel from the backend.
  /// Returns the URL string. Throws an exception on failure.
  Future<String> fetchStreamUrl(String channelId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/channels/$channelId/stream-url'),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final url = data['streamUrl'] as String? ?? '';
        if (url.isEmpty) throw Exception('Stream URL is empty for this channel');
        return url;
      } else {
        throw Exception('Backend error ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to fetch stream URL: $e');
    }
  }
}
