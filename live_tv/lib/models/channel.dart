class Channel {
  final String id;
  final String name;
  final String icon;
  final String url;
  final String category;
  final bool isActive;
  final String webPlayerUrl; // optional AIO/embed URL for WebView playback

  Channel({
    required this.id,
    required this.name,
    required this.icon,
    required this.url,
    required this.category,
    required this.isActive,
    this.webPlayerUrl = '',
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      url: json['url'] ?? '',
      category: json['category'] ?? '',
      isActive: json['isActive'] ?? true,
      webPlayerUrl: json['webPlayerUrl'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'icon': icon,
      'url': url,
      'category': category,
      'isActive': isActive,
      'webPlayerUrl': webPlayerUrl,
    };
  }
}
