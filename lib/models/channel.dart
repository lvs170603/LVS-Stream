class Channel {
  final String id;
  final String name;
  final String icon;
  final String url;
  final String category;

  Channel({
    required this.id,
    required this.name,
    required this.icon,
    required this.url,
    required this.category,
  });

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      icon: json['icon'] ?? '',
      url: json['url'] ?? '',
      category: json['category'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'name': name,
      'icon': icon,
      'url': url,
      'category': category,
    };
  }
}
