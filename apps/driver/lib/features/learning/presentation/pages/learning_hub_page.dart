import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/features/learning/domain/models/learning_resource.dart';
import 'package:milow/features/learning/presentation/widgets/learning_resource_card.dart';

class LearningHubPage extends StatelessWidget {
  const LearningHubPage({super.key});

  static final List<LearningResource> _demoResources = [
    LearningResource(
      id: '1',
      title: 'Pre-Trip Inspection Guide',
      description:
          'A complete walkthrough of the 7-step inspection process to ensure safety and compliance.',
      thumbnailUrl: '',
      type: LearningResourceType.video,
      category: LearningCategory.safety,
      publishedAt: DateTime(2023, 11, 15),
      duration: const Duration(minutes: 12, seconds: 30),
    ),
    LearningResource(
      id: '2',
      title: 'Hours of Service Rules 2024',
      description:
          'Understanding the latest updates to HOS regulations and how to log your time correctly.',
      thumbnailUrl: '',
      type: LearningResourceType.article,
      category: LearningCategory.compliance,
      publishedAt: DateTime(2024, 1, 10),
    ),
    LearningResource(
      id: '3',
      title: 'Winter Driving Tips',
      description:
          'Essential techniques for handling your rig in snow, ice, and freezing temperatures.',
      thumbnailUrl: '',
      type: LearningResourceType.article,
      category: LearningCategory.safety,
      publishedAt: DateTime(2023, 12, 01),
    ),
    LearningResource(
      id: '4',
      title: 'Diesel Exhaust Fluid (DEF) Maintenance',
      description:
          'How to properly maintain your DEF system to avoid engine de-rating.',
      thumbnailUrl: '',
      type: LearningResourceType.video,
      category: LearningCategory.maintenance,
      publishedAt: DateTime(2023, 9, 20),
      duration: const Duration(minutes: 5, seconds: 45),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            title: const Text('Learning Hub'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.all(tokens.spacingM),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final resource = _demoResources[index];
                return LearningResourceCard(
                  resource: resource,
                  onTap: () {
                    // TODO: Navigate to details or open URL
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Opening ${resource.title}...'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                );
              }, childCount: _demoResources.length),
            ),
          ),
        ],
      ),
    );
  }
}
