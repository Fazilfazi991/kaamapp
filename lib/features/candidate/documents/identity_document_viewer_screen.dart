import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../supabase_backend/kaam_backend.dart';

class IdentityDocumentViewerArgs {
  const IdentityDocumentViewerArgs({
    required this.title,
    required this.path,
  });

  final String title;
  final String path;
}

class IdentityDocumentViewerScreen extends StatefulWidget {
  const IdentityDocumentViewerScreen({super.key});

  @override
  State<IdentityDocumentViewerScreen> createState() => _IdentityDocumentViewerScreenState();
}

class _IdentityDocumentViewerScreenState extends State<IdentityDocumentViewerScreen> {
  final storage = const KaamStorageRepository();
  double zoom = 1;
  int turns = 0;
  late Future<String> urlFuture = _loadUrl();

  IdentityDocumentViewerArgs? get args {
    final value = ModalRoute.of(context)?.settings.arguments;
    return value is IdentityDocumentViewerArgs ? value : null;
  }

  Future<String> _loadUrl() async {
    final path = args?.path ?? '';
    return storage.signedPrivateUrl(path);
  }

  @override
  Widget build(BuildContext context) {
    final currentArgs = args;
    if (currentArgs == null) {
      return const ScreenScaffold(
        title: 'Document Viewer',
        showBack: true,
        children: [Text('Document details are missing.')],
      );
    }
    return ScreenScaffold(
      title: currentArgs.title,
      showBack: true,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Rotate',
              onPressed: () => setState(() => turns = (turns + 1) % 4),
              icon: const Icon(Icons.rotate_right_rounded),
            ),
            IconButton(
              tooltip: 'Fit screen',
              onPressed: () => setState(() => zoom = 1),
              icon: const Icon(Icons.fit_screen_rounded),
            ),
            Expanded(
              child: Slider(
                value: zoom,
                min: 1,
                max: 3,
                divisions: 4,
                label: '${zoom.toStringAsFixed(1)}x',
                onChanged: (value) => setState(() => zoom = value),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FutureBuilder<String>(
          future: urlFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return AppCard(
                child: Text(
                  'Could not open secure document: ${snapshot.error}',
                  style: AppTextStyles.body,
                ),
              );
            }
            final url = snapshot.data ?? '';
            final isPdf = currentArgs.path.toLowerCase().endsWith('.pdf');
            if (isPdf) {
              return AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Secure PDF link', style: AppTextStyles.title),
                    const SizedBox(height: 8),
                    const Text(
                      'PDF preview support is limited in this build. Use this temporary signed link to view the document.',
                      style: AppTextStyles.body,
                    ),
                    const SizedBox(height: 12),
                    SelectableText(url, style: AppTextStyles.muted),
                  ],
                ),
              );
            }
            return ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: AppColors.elevatedCard,
                height: 520,
                child: InteractiveViewer(
                  minScale: 1,
                  maxScale: 5,
                  child: Center(
                    child: Transform.rotate(
                      angle: turns * math.pi / 2,
                      child: Transform.scale(
                        scale: zoom,
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Padding(
                            padding: EdgeInsets.all(18),
                            child: Text(
                              'Preview failed. The signed link may have expired.',
                              style: AppTextStyles.body,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
