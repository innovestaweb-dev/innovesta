class AdminProject {
  final String? id;
  final String title;
  final String slug;
  final String? category;
  final String? location;
  final String? area;
  final String? description;
  final Map<String, dynamic> specifications;
  final String? coverImage;
  final List<String> gallery;
  final String? videoUrl;
  final bool isPublished;
  final int displayOrder;

  const AdminProject({
    this.id,
    required this.title,
    required this.slug,
    this.category,
    this.location,
    this.area,
    this.description,
    this.specifications = const {},
    this.coverImage,
    this.gallery = const [],
    this.videoUrl,
    this.isPublished = false,
    this.displayOrder = 0,
  });

  factory AdminProject.fromMap(Map<String, dynamic> map) {
    return AdminProject(
      id: map['id']?.toString(),
      title: map['title'] ?? '',
      slug: map['slug'] ?? '',
      category: map['category'],
      location: map['location'],
      area: map['area'],
      description: map['description'],
      specifications: Map<String, dynamic>.from(map['specifications'] ?? {}),
      coverImage: map['cover_image'],
      gallery: List<String>.from(map['gallery'] ?? []),
      videoUrl: map['video_url'],
      isPublished: map['is_published'] ?? false,
      displayOrder: map['display_order'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'slug': slug,
      'category': category,
      'location': location,
      'area': area,
      'description': description,
      'specifications': specifications,
      'cover_image': coverImage,
      'gallery': gallery,
      'video_url': videoUrl,
      'is_published': isPublished,
      'display_order': displayOrder,
    };
  }
}
