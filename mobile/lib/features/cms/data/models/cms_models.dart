import '../../../../core/config/api_config.dart';

class CmsSettingEntry {
  final String type;
  final dynamic value;
  final String updatedAt;

  const CmsSettingEntry({
    required this.type,
    required this.value,
    required this.updatedAt,
  });

  factory CmsSettingEntry.fromJson(Map<String, dynamic> json) {
    return CmsSettingEntry(
      type: (json['type'] ?? 'TEXT').toString(),
      value: json['value'],
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    'value': value,
    'updated_at': updatedAt,
  };
}

class CmsBanner {
  final int id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final String targetType;
  final String targetValue;
  final String position;
  final String platform;
  final String updatedAt;

  const CmsBanner({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.targetType,
    required this.targetValue,
    required this.position,
    required this.platform,
    required this.updatedAt,
  });

  factory CmsBanner.fromJson(Map<String, dynamic> json) {
    return CmsBanner(
      id: json['id'] ?? 0,
      title: (json['title'] ?? '').toString(),
      subtitle: (json['subtitle'] ?? '').toString(),
      imageUrl: ApiConfig.resolveUrl((json['image_url'] ?? '').toString()),
      targetType: (json['target_type'] ?? 'NONE').toString(),
      targetValue: (json['target_value'] ?? '').toString(),
      position: (json['position'] ?? '').toString(),
      platform: (json['platform'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'subtitle': subtitle,
    'image_url': imageUrl,
    'target_type': targetType,
    'target_value': targetValue,
    'position': position,
    'platform': platform,
    'updated_at': updatedAt,
  };
}

class CmsFaqItem {
  final int id;
  final String category;
  final String question;
  final String answer;
  final int displayOrder;
  final String updatedAt;

  const CmsFaqItem({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    required this.displayOrder,
    required this.updatedAt,
  });

  factory CmsFaqItem.fromJson(Map<String, dynamic> json) {
    return CmsFaqItem(
      id: json['id'] ?? 0,
      category: (json['category'] ?? '').toString(),
      question: (json['question'] ?? '').toString(),
      answer: (json['answer'] ?? '').toString(),
      displayOrder: json['display_order'] ?? 0,
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'question': question,
    'answer': answer,
    'display_order': displayOrder,
    'updated_at': updatedAt,
  };
}

class CmsFaqCategory {
  final String category;
  final List<CmsFaqItem> items;

  const CmsFaqCategory({required this.category, required this.items});

  factory CmsFaqCategory.fromJson(Map<String, dynamic> json) {
    return CmsFaqCategory(
      category: (json['category'] ?? '').toString(),
      items: (json['items'] as List? ?? [])
          .map((item) => CmsFaqItem.fromJson((item as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'category': category,
    'items': items.map((item) => item.toJson()).toList(),
  };
}

class CmsPageSummary {
  final String title;
  final String slug;
  final String pageType;
  final String updatedAt;

  const CmsPageSummary({
    required this.title,
    required this.slug,
    required this.pageType,
    required this.updatedAt,
  });

  factory CmsPageSummary.fromJson(Map<String, dynamic> json) {
    return CmsPageSummary(
      title: (json['title'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      pageType: (json['page_type'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'slug': slug,
    'page_type': pageType,
    'updated_at': updatedAt,
  };
}

class CmsPageDetail {
  final String title;
  final String slug;
  final String pageType;
  final String content;
  final String metaTitle;
  final String metaDescription;
  final String updatedAt;

  const CmsPageDetail({
    required this.title,
    required this.slug,
    required this.pageType,
    required this.content,
    required this.metaTitle,
    required this.metaDescription,
    required this.updatedAt,
  });

  factory CmsPageDetail.fromJson(Map<String, dynamic> json) {
    return CmsPageDetail(
      title: (json['title'] ?? '').toString(),
      slug: (json['slug'] ?? '').toString(),
      pageType: (json['page_type'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      metaTitle: (json['meta_title'] ?? '').toString(),
      metaDescription: (json['meta_description'] ?? '').toString(),
      updatedAt: (json['updated_at'] ?? '').toString(),
    );
  }
}

class CmsBootstrap {
  final String updatedAt;
  final Map<String, Map<String, CmsSettingEntry>> siteSettings;
  final Map<String, List<CmsBanner>> bannersByPosition;
  final List<CmsFaqCategory> faqCategories;
  final List<CmsPageSummary> pages;

  const CmsBootstrap({
    required this.updatedAt,
    required this.siteSettings,
    required this.bannersByPosition,
    required this.faqCategories,
    required this.pages,
  });

  factory CmsBootstrap.fromJson(Map<String, dynamic> json) {
    final rawSettings =
        (json['site_settings'] as Map?)?.cast<String, dynamic>() ?? const {};
    final parsedSettings = <String, Map<String, CmsSettingEntry>>{};
    rawSettings.forEach((group, entries) {
      final groupEntries = (entries as Map?)?.cast<String, dynamic>() ?? const {};
      parsedSettings[group] = groupEntries.map(
        (key, value) => MapEntry(
          key,
          CmsSettingEntry.fromJson((value as Map).cast<String, dynamic>()),
        ),
      );
    });

    final rawBanners =
        (json['banners'] as Map?)?.cast<String, dynamic>() ?? const {};
    final parsedBanners = <String, List<CmsBanner>>{};
    rawBanners.forEach((position, items) {
      parsedBanners[position] = (items as List? ?? [])
          .map((item) => CmsBanner.fromJson((item as Map).cast<String, dynamic>()))
          .toList();
    });

    return CmsBootstrap(
      updatedAt: (json['updated_at'] ?? '').toString(),
      siteSettings: parsedSettings,
      bannersByPosition: parsedBanners,
      faqCategories: (json['faqs'] as List? ?? [])
          .map((item) => CmsFaqCategory.fromJson((item as Map).cast<String, dynamic>()))
          .toList(),
      pages: (json['pages'] as List? ?? [])
          .map((item) => CmsPageSummary.fromJson((item as Map).cast<String, dynamic>()))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'updated_at': updatedAt,
    'site_settings': siteSettings.map(
      (group, entries) => MapEntry(
        group,
        entries.map((key, value) => MapEntry(key, value.toJson())),
      ),
    ),
    'banners': bannersByPosition.map(
      (position, items) => MapEntry(
        position,
        items.map((item) => item.toJson()).toList(),
      ),
    ),
    'faqs': faqCategories.map((category) => category.toJson()).toList(),
    'pages': pages.map((page) => page.toJson()).toList(),
  };

  CmsSettingEntry? setting(String key) {
    for (final groupEntries in siteSettings.values) {
      final value = groupEntries[key];
      if (value != null) return value;
    }
    return null;
  }

  String? stringSetting(String key) {
    final raw = setting(key)?.value;
    if (raw == null) return null;
    final value = raw.toString().trim();
    return value.isEmpty ? null : value;
  }

  bool boolSetting(String key, {bool fallback = false}) {
    final raw = setting(key)?.value;
    if (raw is bool) return raw;
    if (raw == null) return fallback;
    final value = raw.toString().trim().toLowerCase();
    return {'1', 'true', 'yes', 'y', 'on'}.contains(value);
  }

  List<CmsBanner> bannersForPosition(String position) {
    return bannersByPosition[position] ?? const [];
  }

  CmsPageSummary? pageByType(String pageType) {
    for (final page in pages) {
      if (page.pageType == pageType) return page;
    }
    return null;
  }

  List<CmsPageSummary> pagesByTypes(List<String> pageTypes) {
    final pageTypeSet = pageTypes.toSet();
    return pages.where((page) => pageTypeSet.contains(page.pageType)).toList();
  }
}
