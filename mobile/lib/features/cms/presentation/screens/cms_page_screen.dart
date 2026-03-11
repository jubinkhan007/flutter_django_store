import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../data/models/cms_models.dart';
import '../providers/cms_provider.dart';

class CmsPageScreen extends StatefulWidget {
  final String? slug;
  final String? pageType;
  final String? titleOverride;

  const CmsPageScreen({
    super.key,
    this.slug,
    this.pageType,
    this.titleOverride,
  });

  @override
  State<CmsPageScreen> createState() => _CmsPageScreenState();
}

class _CmsPageScreenState extends State<CmsPageScreen> {
  late Future<CmsPageDetail> _pageFuture;

  @override
  void initState() {
    super.initState();
    _pageFuture = context.read<CmsProvider>().fetchPage(
      slug: widget.slug,
      pageType: widget.pageType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.titleOverride ?? 'Information')),
      body: FutureBuilder(
        future: _pageFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Text(
                  snapshot.error.toString().replaceFirst('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.error),
                ),
              ),
            );
          }

          final page = snapshot.data;
          if (page == null) {
            return const Center(child: Text('Page not found'));
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Text(
                page.title,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.lightTextPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Html(
                data: page.content,
                onLinkTap: (url, _, __) async {
                  if (url == null || url.trim().isEmpty) return;
                  final uri = Uri.tryParse(url.trim());
                  if (uri != null) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
