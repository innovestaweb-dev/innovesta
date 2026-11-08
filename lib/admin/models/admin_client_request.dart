class AdminClientRequest {
  final String id;
  final String source;
  final String? name;
  final String? email;
  final String? phone;
  final String? projectType;
  final String? projectStage;
  final String? area;
  final String? location;
  final String? budget;
  final List<String> services;
  final String? details;
  final String? pageUrl;
  final String status;
  final String? adminNotes;
  final DateTime createdAt;
  final DateTime updatedAt;

  final String? company;
  final String? country;
  final String? budgetCurrency;
  final String? estimatedBudget;
  final String? preferredContact;
  final String? timeline;
  final String? designStyles;
  final String? overallMood;
  final String? referenceLinks;
  final String? additionalNotes;
  final String? projectArea;

  const AdminClientRequest({
    required this.id,
    required this.source,
    this.name,
    this.email,
    this.phone,
    this.projectType,
    this.projectStage,
    this.area,
    this.location,
    this.budget,
    this.services = const [],
    this.details,
    this.pageUrl,
    required this.status,
    this.adminNotes,
    required this.createdAt,
    required this.updatedAt,
    this.company,
    this.country,
    this.budgetCurrency,
    this.estimatedBudget,
    this.preferredContact,
    this.timeline,
    this.designStyles,
    this.overallMood,
    this.referenceLinks,
    this.additionalNotes,
    this.projectArea,
  });

  factory AdminClientRequest.fromMap(Map<String, dynamic> map) {
    return AdminClientRequest(
      id: map['id']?.toString() ?? '',
      source: map['source']?.toString() ?? 'form',
      name: map['name']?.toString(),
      email: map['email']?.toString(),
      phone: map['phone']?.toString(),
      projectType: map['project_type']?.toString(),
      projectStage: map['project_stage']?.toString(),
      area: map['area']?.toString(),
      location: map['location']?.toString(),
      budget: map['budget']?.toString(),
      services: map['services'] is List
          ? List<String>.from(
              (map['services'] as List).map((item) => item.toString()),
            )
          : [],
      details: map['details']?.toString(),
      pageUrl: map['page_url']?.toString(),
      status: map['status']?.toString() ?? 'new',
      adminNotes: map['admin_notes']?.toString(),
      createdAt:
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updated_at']?.toString() ?? '') ??
          DateTime.now(),

      company: map['company']?.toString(),
      country: map['country']?.toString(),
      budgetCurrency: map['budget_currency']?.toString(),
      estimatedBudget: map['estimated_budget']?.toString(),
      preferredContact: map['preferred_contact']?.toString(),
      timeline: map['timeline']?.toString(),
      designStyles: map['design_styles']?.toString(),
      overallMood: map['overall_mood']?.toString(),
      referenceLinks: map['reference_links']?.toString(),
      additionalNotes: map['additional_notes']?.toString(),
      projectArea: map['project_area']?.toString(),
    );
  }
}
