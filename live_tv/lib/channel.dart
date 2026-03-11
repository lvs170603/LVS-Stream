class Channel {
  final String name;
  final String icon;
  final String url;
  final String category;

  Channel({
    required this.name,
    required this.icon,
    required this.url,
    required this.category,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      url: json['url'] ?? '',
      category: json['category'] ?? '',
    );
  }
}
