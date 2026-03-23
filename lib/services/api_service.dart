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
        List<Channel> channels = body.map((dynamic item) => Channel.fromJson(item)).toList();
        return channels;
      } else {
        throw Exception('Failed to load channels: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching channels: $e');
    }
  }
}
