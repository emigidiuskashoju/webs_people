class Place {
  final int id;
  final String name;
  final String slug;
  final double latitude;
  final double longitude;
  final String? photoUrl;
  final String? logoUrl;
  final String shareLink;

  Place({
    required this.id,
    required this.name,
    required this.slug,
    required this.latitude,
    required this.longitude,
    this.photoUrl,
    this.logoUrl,
    required this.shareLink,
  });

  factory Place.fromJson(Map<String, dynamic> json, String shareLink) {
    return Place(
      id: json['id'],
      name: json['name'],
      slug: json['slug'],
      latitude: double.parse(json['latitude'].toString()),
      longitude: double.parse(json['longitude'].toString()),
      photoUrl: json['photo_url'],
      logoUrl: json['logo_url'],
      shareLink: shareLink,
    );
  }
}