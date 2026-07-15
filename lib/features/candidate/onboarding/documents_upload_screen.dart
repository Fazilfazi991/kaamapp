import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../supabase_backend/kaam_backend.dart';
import '../documents/document_status_service.dart';
import '../documents/identity_document_ocr_service.dart';
import '../documents/identity_document_viewer_screen.dart';

class DocumentsUploadScreen extends StatefulWidget {
  const DocumentsUploadScreen({super.key});

  @override
  State<DocumentsUploadScreen> createState() => _DocumentsUploadScreenState();
}

class _DocumentsUploadScreenState extends State<DocumentsUploadScreen> {
  final storage = const KaamStorageRepository();
  final profiles = const CandidateProfileRepository();
  final ocr = const SupabaseIdentityOcrService();
  final imagePicker = ImagePicker();

  CandidateIdentityDocumentData identity =
      const CandidateIdentityDocumentData();
  bool loading = true;
  bool uploading = false;
  String uploadMessage = '';
  String? selectedFileName;
  String? uploadError;
  IdentityDocumentType uploadErrorType = IdentityDocumentType.passport;
  IdentityDocumentReviewArgs? pendingReview;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await profiles.loadIdentityDocuments();
      if (mounted) {
        setState(() => identity = loaded);
      }
    } catch (_) {
      if (mounted) {
        _showMessage(
            'We could not load your document status. Check your connection and try again.');
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _choosePassport() =>
      _chooseDocument(IdentityDocumentType.passport);
  Future<void> _chooseVisa() => _chooseDocument(IdentityDocumentType.visa);

  Future<void> _chooseDocument(IdentityDocumentType type) async {
    if (uploading) return;
    final source = await _pickUploadSource(type);
    if (source == null) return;

    if (uploading) return;
    setState(() {
      uploading = true;
      uploadError = null;
      uploadErrorType = type;
      pendingReview = null;
      uploadMessage = source == _DocumentUploadSource.camera
          ? 'Opening camera...'
          : 'Choosing ${documentLabel(type).toLowerCase()} file...';
    });
    try {
      final picked = source == _DocumentUploadSource.camera
          ? await _takePhoto(type)
          : await _pickFile(type);
      if (picked == null) return;
      if (picked.bytes.length > 10 * 1024 * 1024) {
        throw const _UploadException(
            'This file is larger than 10 MB. Choose a smaller file.');
      }

      if (mounted) {
        setState(() {
          selectedFileName = picked.fileName;
          uploadMessage =
              'Uploading ${documentLabel(type).toLowerCase()} securely...';
        });
      }
      final upload = await storage.uploadCandidateIdentityDocument(
        bytes: picked.bytes,
        fileName: picked.fileName,
        documentType: type.name,
      );
      if (!mounted) return;
      setState(() => uploadMessage =
          'Reading ${documentLabel(type).toLowerCase()} details...');

      PassportExtractionResult extraction;
      String? ocrError;
      try {
        extraction = await ocr.extract(
          type: type,
          upload: upload,
          fileName: picked.fileName,
        );
      } catch (_) {
        extraction = PassportExtractionResult.empty();
        ocrError =
            'We could not read this ${documentLabel(type).toLowerCase()} automatically. You can enter the details manually.';
      }
      if (!mounted) return;
      setState(() {
        pendingReview = IdentityDocumentReviewArgs(
          type: type,
          upload: upload,
          extraction: extraction,
          ocrError: ocrError,
        );
      });
    } on _UploadException catch (error) {
      if (mounted) {
        setState(() => uploadError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => uploadError =
            'Upload failed. Check your connection and try again.');
      }
    } finally {
      if (mounted) {
        setState(() {
          uploading = false;
          uploadMessage = '';
        });
      }
    }
  }

  Future<_DocumentUploadSource?> _pickUploadSource(
    IdentityDocumentType type,
  ) {
    return showModalBottomSheet<_DocumentUploadSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Upload ${documentLabel(type)}', style: AppTextStyles.title),
              const SizedBox(height: 8),
              const Text('Choose how you want to add the document.',
                  style: AppTextStyles.muted),
              const SizedBox(height: 14),
              _UploadSourceTile(
                icon: Icons.photo_camera_outlined,
                title: 'Take Photo',
                subtitle: 'Open the camera and capture the document.',
                onTap: () => Navigator.of(sheetContext)
                    .pop(_DocumentUploadSource.camera),
              ),
              const SizedBox(height: 8),
              _UploadSourceTile(
                icon: Icons.upload_file_outlined,
                title: 'Choose from Gallery / Files',
                subtitle: 'Select an existing JPG, PNG or PDF file.',
                onTap: () =>
                    Navigator.of(sheetContext).pop(_DocumentUploadSource.file),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<_PickedDocument?> _pickFile(IdentityDocumentType type) async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'pdf'],
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return null;
    final extension = file.extension?.toLowerCase() ?? '';
    if (!const ['jpg', 'jpeg', 'png', 'pdf'].contains(extension)) {
      throw const _UploadException('Use a JPG, PNG, or PDF file.');
    }
    return _PickedDocument(bytes: bytes, fileName: file.name);
  }

  Future<_PickedDocument?> _takePhoto(IdentityDocumentType type) async {
    var permission = await Permission.camera.request();
    if (!permission.isGranted) {
      final retry = await _showCameraPermissionDialog(permission);
      if (retry == true) {
        permission = await Permission.camera.request();
      }
      if (!permission.isGranted) {
        return null;
      }
    }
    if (!permission.isGranted) {
      return null;
    }
    final image = await imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 88,
      maxWidth: 1800,
      maxHeight: 2400,
    );
    if (image == null) return null;
    final bytes = await image.readAsBytes();
    return _PickedDocument(
      bytes: bytes,
      fileName: '${type.name}_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
  }

  Future<bool?> _showCameraPermissionDialog(PermissionStatus status) async {
    if (!mounted) return false;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Camera permission needed'),
        content: const Text(
          'KAAM needs camera access to take a document photo. You can retry permission or open app settings.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Retry'),
          ),
          if (status.isPermanentlyDenied || status.isRestricted)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
  }

  Future<void> _reviewDetails() async {
    final review = pendingReview;
    if (review == null) return;
    final saved = await Navigator.of(context).pushNamed(
      AppRoutes.identityDocumentReview,
      arguments: review,
    );
    if (saved == true && mounted) {
      setState(() {
        pendingReview = null;
        selectedFileName = null;
      });
      await _load();
    }
  }

  Future<void> _confirmSkip() async {
    final skip = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Continue without a document?',
                  style: AppTextStyles.title),
              const SizedBox(height: 10),
              const Text(
                'You can continue now, but your profile may remain incomplete until your identity document is verified.',
                style: AppTextStyles.body,
              ),
              const SizedBox(height: 22),
              PrimaryButton(
                label: 'Continue without document',
                onPressed: () => Navigator.of(sheetContext).pop(true),
              ),
              const SizedBox(height: 10),
              SecondaryButton(
                label: 'Go back',
                onPressed: () => Navigator.of(sheetContext).pop(false),
              ),
            ],
          ),
        ),
      ),
    );
    if (skip == true && mounted) {
      Navigator.of(context).pushNamed(AppRoutes.basicDetails);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final passportSaved = identity.hasPassport;
    final visaSaved = identity.hasVisa;
    return ScreenScaffold(
      title: 'KAAM',
      showBack: true,
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      children: [
        const _OnboardingProgress(),
        const SizedBox(height: 24),
        const Text('Verify your identity', style: AppTextStyles.headline),
        const SizedBox(height: 8),
        const Text(
          'Upload clear identity document photos. We\'ll extract details securely and ask you to review them before submission.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 16),
        const _PrivacyReassurance(),
        const SizedBox(height: 22),
        if (loading)
          const Center(
              child: Padding(
                  padding: EdgeInsets.all(28),
                  child: CircularProgressIndicator()))
        else if (uploading)
          _ProcessingPanel(message: uploadMessage)
        else if (pendingReview != null)
          _ReadyForReviewPanel(
            fileName: selectedFileName ?? 'Document',
            type: pendingReview!.type,
            manuallyReview: pendingReview!.ocrError != null,
            onReplace: () => _chooseDocument(pendingReview!.type),
            onReview: _reviewDetails,
          )
        else if (passportSaved)
          _SavedPassportPanel(
            type: IdentityDocumentType.passport,
            fileName: _fileName(identity.passportFileUrl),
            status: DocumentStatusService.label(
              identity.passportStatus,
              uploaded: true,
              expiry: identity.passportExpiryDate,
            ),
            onReplace: _choosePassport,
            onView: () => Navigator.of(context).pushNamed(
              AppRoutes.identityDocumentViewer,
              arguments: IdentityDocumentViewerArgs(
                  title: 'Passport', path: identity.passportFileUrl),
            ),
          )
        else
          _DocumentPickerPanel(
            type: IdentityDocumentType.passport,
            onChoose: _choosePassport,
          ),
        const SizedBox(height: 14),
        if (!loading && !uploading && pendingReview == null)
          if (visaSaved)
            _SavedPassportPanel(
              type: IdentityDocumentType.visa,
              fileName: _fileName(identity.visaFileUrl),
              status: DocumentStatusService.label(
                identity.visaStatus,
                uploaded: true,
                expiry: identity.visaExpiryDate,
              ),
              onReplace: _chooseVisa,
              onView: () => Navigator.of(context).pushNamed(
                AppRoutes.identityDocumentViewer,
                arguments: IdentityDocumentViewerArgs(
                    title: 'Visa / Emirates ID', path: identity.visaFileUrl),
              ),
            )
          else
            _DocumentPickerPanel(
              type: IdentityDocumentType.visa,
              onChoose: _chooseVisa,
            ),
        if (uploadError != null) ...[
          const SizedBox(height: 14),
          _ErrorPanel(
              message: uploadError!,
              onRetry: () => _chooseDocument(uploadErrorType)),
        ],
        const SizedBox(height: 24),
        if (passportSaved)
          PrimaryButton(
            label: 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.basicDetails),
          ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: uploading ? null : _confirmSkip,
            child: const Text("I'll do this later"),
          ),
        ),
      ],
    );
  }

  String _fileName(String path) {
    if (path.isEmpty) return 'Document uploaded';
    return path.split('/').last;
  }
}

String documentLabel(IdentityDocumentType type) =>
    type == IdentityDocumentType.passport ? 'Passport' : 'Visa / Emirates ID';

enum _DocumentUploadSource { camera, file }

class _PickedDocument {
  const _PickedDocument({required this.bytes, required this.fileName});

  final List<int> bytes;
  final String fileName;
}

class _OnboardingProgress extends StatelessWidget {
  const _OnboardingProgress();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Step 1 of 5  ·  Identity verification',
            style: AppTextStyles.muted),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: const LinearProgressIndicator(
            value: .2,
            minHeight: 7,
            backgroundColor: AppColors.border,
            valueColor: AlwaysStoppedAnimation(AppColors.primaryPink),
          ),
        ),
      ],
    );
  }
}

class _PrivacyReassurance extends StatelessWidget {
  const _PrivacyReassurance();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.elevatedCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_user_outlined, color: AppColors.softPink),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your document is stored securely and is never approved automatically.',
              style: AppTextStyles.muted,
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadSourceTile extends StatelessWidget {
  const _UploadSourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: AppColors.primaryPink),
      title: Text(title, style: AppTextStyles.label),
      subtitle: Text(subtitle, style: AppTextStyles.muted),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

class _DocumentPickerPanel extends StatelessWidget {
  const _DocumentPickerPanel({required this.type, required this.onChoose});

  final IdentityDocumentType type;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primaryPink.withValues(alpha: .13),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.badge_outlined,
                color: AppColors.softPink, size: 28),
          ),
          const SizedBox(height: 14),
          Text('Upload ${documentLabel(type)}', style: AppTextStyles.title),
          const SizedBox(height: 5),
          Text(
            type == IdentityDocumentType.passport
                ? 'Photo page only'
                : 'Visa page or Emirates ID',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: AppColors.border, style: BorderStyle.solid),
            ),
            child: const Text(
              'Use a clear, well-lit image. JPG, PNG, or PDF up to 10 MB.',
              textAlign: TextAlign.center,
              style: AppTextStyles.muted,
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(
            label: 'Upload ${documentLabel(type)}',
            icon: Icons.upload_file_outlined,
            onPressed: onChoose,
          ),
        ],
      ),
    );
  }
}

class _ProcessingPanel extends StatelessWidget {
  const _ProcessingPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 18),
          Text(message.isEmpty ? 'Reading passport details...' : message,
              style: AppTextStyles.title),
          const SizedBox(height: 7),
          const Text('This may take a few seconds.',
              style: AppTextStyles.muted),
        ],
      ),
    );
  }
}

class _ReadyForReviewPanel extends StatelessWidget {
  const _ReadyForReviewPanel({
    required this.fileName,
    required this.type,
    required this.manuallyReview,
    required this.onReplace,
    required this.onReview,
  });

  final String fileName;
  final IdentityDocumentType type;
  final bool manuallyReview;
  final VoidCallback onReplace;
  final VoidCallback onReview;

  @override
  Widget build(BuildContext context) {
    return _DocumentStatePanel(
      icon: manuallyReview ? Icons.edit_document : Icons.check_circle_outline,
      iconColor: manuallyReview ? AppColors.warning : AppColors.success,
      title: manuallyReview
          ? 'Ready for manual review'
          : '${documentLabel(type)} ready to review',
      detail: manuallyReview
          ? 'We could not read every detail. You can enter them securely on the next screen.'
          : 'We found ${documentLabel(type).toLowerCase()} details for you to check before saving.',
      fileName: fileName,
      primaryLabel: 'Review Extracted Details',
      onPrimary: onReview,
      onSecondary: onReplace,
      secondaryLabel: 'Replace',
    );
  }
}

class _SavedPassportPanel extends StatelessWidget {
  const _SavedPassportPanel({
    required this.type,
    required this.fileName,
    required this.status,
    required this.onReplace,
    required this.onView,
  });

  final IdentityDocumentType type;
  final String fileName;
  final String status;
  final VoidCallback onReplace;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return _DocumentStatePanel(
      icon: Icons.check_circle_outline,
      iconColor: AppColors.success,
      title: '${documentLabel(type)} saved',
      detail: 'Status: $status',
      fileName: fileName,
      primaryLabel: 'View ${documentLabel(type)}',
      onPrimary: onView,
      onSecondary: onReplace,
      secondaryLabel: 'Replace',
    );
  }
}

class _DocumentStatePanel extends StatelessWidget {
  const _DocumentStatePanel({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.detail,
    required this.fileName,
    required this.primaryLabel,
    required this.onPrimary,
    required this.onSecondary,
    required this.secondaryLabel,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String detail;
  final String fileName;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final String secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTextStyles.title)),
            ],
          ),
          const SizedBox(height: 12),
          Text(detail, style: AppTextStyles.body),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.elevatedCard,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.insert_drive_file_outlined,
                    size: 18, color: AppColors.secondaryText),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(fileName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.muted)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          PrimaryButton(label: primaryLabel, onPressed: onPrimary),
          const SizedBox(height: 10),
          SecondaryButton(label: secondaryLabel, onPressed: onSecondary),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: .45)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: AppTextStyles.body)),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _UploadException implements Exception {
  const _UploadException(this.message);

  final String message;
}
