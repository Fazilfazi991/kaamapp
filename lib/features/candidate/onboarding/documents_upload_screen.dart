import 'dart:typed_data';

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
import '../documents/identity_document_image_quality.dart';
import '../documents/passport_file_validator.dart';

class DocumentsUploadScreen extends StatefulWidget {
  const DocumentsUploadScreen({super.key});

  @override
  State<DocumentsUploadScreen> createState() => _DocumentsUploadScreenState();
}

enum CandidateDocumentEntryMode { onboarding, dashboard, notification, profile }

String passportStorageDocumentType({required bool isFront}) =>
    isFront ? 'passport' : 'passport-back';

class CandidateDocumentEntryArgs {
  const CandidateDocumentEntryArgs({
    required this.mode,
    this.documentType,
    this.documentId,
    this.documentVersionId,
    this.reviewEventId,
    this.publicReason,
    this.entrySource,
  });
  const CandidateDocumentEntryArgs.dashboard({this.documentType})
      : mode = CandidateDocumentEntryMode.dashboard,
        documentId = null,
        documentVersionId = null,
        reviewEventId = null,
        publicReason = null,
        entrySource = 'dashboard';

  final CandidateDocumentEntryMode mode;
  final IdentityDocumentType? documentType;
  final String? documentId;
  final String? documentVersionId;
  final String? reviewEventId;
  final String? publicReason;
  final String? entrySource;
}

class CandidateDocumentsResult {
  const CandidateDocumentsResult(
      {this.documentChanged = false, this.changedType});
  final bool documentChanged;
  final IdentityDocumentType? changedType;
}

class _DocumentsUploadScreenState extends State<DocumentsUploadScreen> {
  static const maxDocumentBytes = PassportFileValidator.maxBytes;
  static const unsupportedDocumentMessage =
      'Unsupported file format. Please upload a JPG, JPEG, PNG, or PDF file.';
  final storage = const KaamStorageRepository();
  final profiles = const CandidateProfileRepository();
  final ocr = const SupabaseIdentityOcrService();
  final imagePicker = ImagePicker();
  final passportFileValidator = PassportFileValidator();
  final passportFileReader = const PassportPlatformFileReader();

  CandidateIdentityDocumentData identity =
      const CandidateIdentityDocumentData();
  bool loading = true;
  bool uploading = false;
  bool passportFrontUploading = false;
  bool passportBackUploading = false;
  String uploadMessage = '';
  String? selectedFileName;
  String? passportFrontError;
  String? passportBackError;
  String? visaError;
  final passportFrontKey = GlobalKey();
  final passportBackKey = GlobalKey();
  final visaKey = GlobalKey();
  KaamUploadResult? passportFrontUpload;
  KaamUploadResult? passportBackUpload;
  String? passportFrontFileName;
  String? passportBackFileName;
  Uint8List? passportFrontPreviewBytes;
  Uint8List? passportBackPreviewBytes;
  PassportExtractionResult? passportFrontExtraction;
  String? passportFrontOcrError;
  IdentityDocumentReviewArgs? pendingReview;
  bool continuing = false;
  bool documentChanged = false;

  CandidateDocumentEntryArgs get entryArgs {
    final value = ModalRoute.of(context)?.settings.arguments;
    return value is CandidateDocumentEntryArgs
        ? value
        : const CandidateDocumentEntryArgs(
            mode: CandidateDocumentEntryMode.onboarding,
          );
  }

  bool get isOnboarding =>
      entryArgs.mode == CandidateDocumentEntryMode.onboarding;

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
          'We could not load your document status. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _chooseVisa() => _chooseDocument(IdentityDocumentType.visa);

  void _clearErrorFor(IdentityDocumentType type, [_PassportSide? side]) {
    if (type == IdentityDocumentType.visa) {
      visaError = null;
    } else if (side == _PassportSide.back) {
      passportBackError = null;
    } else {
      passportFrontError = null;
    }
  }

  void _setErrorFor(IdentityDocumentType type, String message,
      [_PassportSide? side]) {
    if (type == IdentityDocumentType.visa) {
      visaError = message;
    } else if (side == _PassportSide.back) {
      passportBackError = message;
    } else {
      passportFrontError = message;
    }
  }

  void _announceAndFocusError(IdentityDocumentType type,
      [_PassportSide? side]) {
    final label = type == IdentityDocumentType.visa
        ? 'Visa image'
        : side == _PassportSide.back
            ? 'Passport Back'
            : 'Passport Front';
    _showMessage('$label could not be accepted.');
    final key = type == IdentityDocumentType.visa
        ? visaKey
        : side == _PassportSide.back
            ? passportBackKey
            : passportFrontKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = key.currentContext;
      if (target != null && mounted) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 300),
          alignment: .15,
        );
      }
    });
  }

  Future<void> _choosePassportSide(_PassportSide side) async {
    final source = await _pickUploadSource(IdentityDocumentType.passport);
    if (source == null) return;
    await _choosePassportSideSource(side, source);
  }

  Future<void> _choosePassportSideSource(
    _PassportSide side,
    _DocumentUploadSource source,
  ) async {
    if (passportFrontUploading || passportBackUploading || uploading) return;
    final previousUpload =
        side == _PassportSide.front ? passportFrontUpload : passportBackUpload;
    final previousFileName = side == _PassportSide.front
        ? passportFrontFileName
        : passportBackFileName;
    final previousPreview = side == _PassportSide.front
        ? passportFrontPreviewBytes
        : passportBackPreviewBytes;
    final previousExtraction = passportFrontExtraction;
    final previousOcrError = passportFrontOcrError;
    final previousPendingReview = pendingReview;
    setState(() {
      if (side == _PassportSide.front) {
        passportFrontUploading = true;
      } else {
        passportBackUploading = true;
      }
      _clearErrorFor(IdentityDocumentType.passport, side);
    });
    try {
      final picked = source == _DocumentUploadSource.camera
          ? await _takePhoto(IdentityDocumentType.passport)
          : await _pickFile(IdentityDocumentType.passport);
      if (picked == null) return;
      if (!mounted) return;
      setState(() {
        final previewBytes = Uint8List.fromList(picked.bytes);
        if (side == _PassportSide.front) {
          passportFrontFileName = picked.fileName;
          passportFrontPreviewBytes = previewBytes;
        } else {
          passportBackFileName = picked.fileName;
          passportBackPreviewBytes = previewBytes;
        }
      });

      final upload = await storage.uploadCandidateIdentityDocument(
        bytes: picked.bytes,
        fileName: picked.fileName,
        documentType:
            passportStorageDocumentType(isFront: side == _PassportSide.front),
      );

      PassportExtractionResult? extraction;
      if (side == _PassportSide.front) {
        try {
          extraction = await ocr.extract(
            type: IdentityDocumentType.passport,
            upload: upload,
            fileName: picked.fileName,
          );
        } catch (_) {
          throw const _UploadException(
            'We could not validate this passport identity page. Use a clear photo of the passport information page.',
          );
        }
      } else {
        try {
          await ocr.validatePassportBack(
              upload: upload, fileName: picked.fileName);
        } catch (_) {
          throw const _UploadException(
            'We could not validate this passport back. Use a clear photo of the document back.',
          );
        }
      }

      if (!mounted) return;
      setState(() {
        if (side == _PassportSide.front) {
          passportFrontUpload = upload;
          passportFrontFileName = picked.fileName;
          passportFrontExtraction =
              extraction ?? PassportExtractionResult.empty();
          passportFrontOcrError = null;
        } else {
          passportBackUpload = upload;
          passportBackFileName = picked.fileName;
        }
        _refreshPassportReview();
      });
    } on _UploadException catch (error) {
      if (mounted) {
        setState(() {
          _restorePassportSide(
            side,
            upload: previousUpload,
            fileName: previousFileName,
            preview: previousPreview,
            extraction: previousExtraction,
            ocrError: previousOcrError,
          );
          pendingReview = previousPendingReview;
          _setErrorFor(IdentityDocumentType.passport, error.message, side);
        });
      }
      _announceAndFocusError(IdentityDocumentType.passport, side);
    } catch (_) {
      if (mounted) {
        setState(() {
          _restorePassportSide(
            side,
            upload: previousUpload,
            fileName: previousFileName,
            preview: previousPreview,
            extraction: previousExtraction,
            ocrError: previousOcrError,
          );
          pendingReview = previousPendingReview;
          _setErrorFor(
              IdentityDocumentType.passport,
              side == _PassportSide.front
                  ? 'We could not replace the passport front. Please try again.'
                  : 'We could not replace the passport back. Please try again.',
              side);
        });
      }
      _announceAndFocusError(IdentityDocumentType.passport, side);
    } finally {
      if (mounted) {
        setState(() {
          if (side == _PassportSide.front) {
            passportFrontUploading = false;
          } else {
            passportBackUploading = false;
          }
        });
      }
    }
  }

  void _restorePassportSide(
    _PassportSide side, {
    required KaamUploadResult? upload,
    required String? fileName,
    required Uint8List? preview,
    required PassportExtractionResult? extraction,
    required String? ocrError,
  }) {
    if (side == _PassportSide.front) {
      passportFrontUpload = upload;
      passportFrontFileName = fileName;
      passportFrontPreviewBytes = preview;
      passportFrontExtraction = extraction;
      passportFrontOcrError = ocrError;
    } else {
      passportBackUpload = upload;
      passportBackFileName = fileName;
      passportBackPreviewBytes = preview;
    }
  }

  void _removePassportSide(_PassportSide side) {
    setState(() {
      pendingReview = null;
      if (side == _PassportSide.front) {
        passportFrontUpload = null;
        passportFrontFileName = null;
        passportFrontPreviewBytes = null;
        passportFrontExtraction = null;
        passportFrontOcrError = null;
      } else {
        passportBackUpload = null;
        passportBackFileName = null;
        passportBackPreviewBytes = null;
      }
      _refreshPassportReview();
    });
  }

  void _refreshPassportReview() {
    if (passportFrontUpload == null && passportBackUpload == null) {
      pendingReview = null;
      return;
    }
    final front = passportFrontUpload ??
        _savedPassportUpload(identity.passportFileUrl, 'Passport front');
    final back = passportBackUpload ??
        _savedPassportUpload(identity.passportBackFileUrl, 'Passport back');
    if (front == null || back == null) {
      pendingReview = null;
      return;
    }
    pendingReview = IdentityDocumentReviewArgs(
      type: IdentityDocumentType.passport,
      upload: front,
      backUpload: back,
      backFileName: passportBackFileName,
      extraction: passportFrontExtraction ?? PassportExtractionResult.empty(),
      ocrError: passportFrontOcrError,
    );
    selectedFileName = passportFrontFileName;
  }

  KaamUploadResult? _savedPassportUpload(String path, String displayName) {
    if (path.trim().isEmpty) return null;
    return KaamUploadResult.privateReference(
      path: path,
      displayName: displayName,
    );
  }

  Future<void> _chooseDocument(IdentityDocumentType type) async {
    if (uploading) return;
    final source = await _pickUploadSource(type);
    if (source == null) return;

    if (uploading) return;
    setState(() {
      uploading = true;
      _clearErrorFor(type);
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
      setState(
        () => uploadMessage =
            'Reading ${documentLabel(type).toLowerCase()} details...',
      );

      PassportExtractionResult extraction;
      try {
        extraction = await ocr.extract(
          type: type,
          upload: upload,
          fileName: picked.fileName,
        );
      } catch (_) {
        throw _UploadException(
          'We could not validate this ${documentLabel(type).toLowerCase()}. Use a clear, readable identity document.',
        );
      }
      if (!mounted) return;
      setState(() {
        pendingReview = IdentityDocumentReviewArgs(
          type: type,
          upload: upload,
          extraction: extraction,
          ocrError: null,
        );
      });
    } on _UploadException catch (error) {
      if (mounted) {
        setState(() => _setErrorFor(type, error.message));
      }
      _announceAndFocusError(type);
    } catch (_) {
      if (mounted) {
        setState(
          () => _setErrorFor(
            type,
            'Upload failed. Check your connection and try again.',
          ),
        );
      }
      _announceAndFocusError(type);
    } finally {
      if (mounted) {
        setState(() {
          uploading = false;
          uploadMessage = '';
        });
      }
    }
  }

  Future<_DocumentUploadSource?> _pickUploadSource(IdentityDocumentType type) {
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
              const Text(
                'Choose how you want to add the document.',
                style: AppTextStyles.muted,
              ),
              const SizedBox(height: 14),
              _UploadSourceTile(
                icon: Icons.photo_camera_outlined,
                title: 'Take Photo',
                subtitle: 'Open the camera and capture the document.',
                onTap: () => Navigator.of(
                  sheetContext,
                ).pop(_DocumentUploadSource.camera),
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
      withReadStream: true,
      type: FileType.any,
    );
    final file = result?.files.single;
    if (file == null) return null;
    late final Uint8List bytes;
    try {
      bytes = await passportFileReader.read(file);
    } on PassportFileReadException catch (error) {
      throw _UploadException(error.message);
    }
    await _validatePickedFile(type: type, fileName: file.name, bytes: bytes);
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
    final fileName =
        '${type.name}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    await _validatePickedFile(
      type: type,
      fileName: fileName,
      bytes: bytes,
    );
    return _PickedDocument(
      bytes: bytes,
      fileName: fileName,
    );
  }

  Future<void> _validatePickedFile({
    required IdentityDocumentType type,
    required String fileName,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) {
      throw _UploadException(
        type == IdentityDocumentType.passport
            ? const PassportFileValidationResult(
                PassportFileValidationCode.empty,
              ).message
            : 'We could not read this file. Please choose another one.',
      );
    }
    if (bytes.length > maxDocumentBytes) {
      throw _UploadException(
        type == IdentityDocumentType.passport
            ? const PassportFileValidationResult(
                PassportFileValidationCode.tooLarge,
              ).message
            : 'This file is too large. Please choose a smaller image.',
      );
    }
    final result = await passportFileValidator.validate(
      fileName: fileName,
      bytes: bytes,
    );
    if (result.isValid) {
      if (result.kind != PassportFileKind.pdf) {
        final qualityError = await IdentityDocumentImageQuality.rejectionReason(
          bytes,
        );
        if (qualityError != null) throw _UploadException(qualityError);
      }
      return;
    }
    if (type == IdentityDocumentType.passport) {
      throw _UploadException(result.message);
    }
    final message = switch (result.code) {
      PassportFileValidationCode.video =>
        'Videos cannot be used as identity documents. Please choose an image.',
      PassportFileValidationCode.tooLarge =>
        'This file is too large. Please choose a smaller image.',
      PassportFileValidationCode.empty ||
      PassportFileValidationCode.unreadable =>
        'We could not read this file. Please choose another one.',
      _ => unsupportedDocumentMessage,
    };
    throw _UploadException(message);
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
    final saved = await Navigator.of(
      context,
    ).pushNamed(AppRoutes.identityDocumentReview, arguments: review);
    if (saved == true && mounted) {
      setState(() {
        pendingReview = null;
        selectedFileName = null;
        passportFrontUpload = null;
        passportBackUpload = null;
        passportFrontFileName = null;
        passportBackFileName = null;
        passportFrontPreviewBytes = null;
        passportBackPreviewBytes = null;
        passportFrontExtraction = null;
        passportFrontOcrError = null;
      });
      await _load();
      documentChanged = true;
      if (!mounted) return;
      final type =
          review.type == IdentityDocumentType.passport ? 'Passport' : 'Visa';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                '$type submitted for review. We\'ll notify you when the review is complete.')),
      );
    }
  }

  void _done() {
    Navigator.of(context).pop(
      CandidateDocumentsResult(documentChanged: documentChanged),
    );
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
              const Text(
                'Continue without a document?',
                style: AppTextStyles.title,
              ),
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

  Future<void> _continueOnboarding() async {
    if (!identity.hasPassport ||
        uploading ||
        passportFrontUploading ||
        passportBackUploading ||
        pendingReview != null ||
        continuing) {
      return;
    }
    setState(() => continuing = true);
    try {
      if (mounted) Navigator.of(context).pushNamed(AppRoutes.basicDetails);
    } finally {
      if (mounted) setState(() => continuing = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final passportSaved = identity.hasPassport;
    final visaSaved = identity.hasVisa;
    final passportBusy = passportFrontUploading || passportBackUploading;
    return ScreenScaffold(
      title: isOnboarding ? 'KAAM' : 'Documents',
      showBack: true,
      actions: isOnboarding
          ? null
          : [
              TextButton(
                  onPressed: uploading || passportBusy ? null : _done,
                  child: const Text('Done'))
            ],
      padding: const EdgeInsets.fromLTRB(22, 16, 22, 28),
      children: [
        if (isOnboarding) const _OnboardingProgress(),
        SizedBox(height: isOnboarding ? 24 : 4),
        Text(
          isOnboarding ? 'Verify your identity' : 'Manage your documents',
          style: AppTextStyles.headline,
        ),
        const SizedBox(height: 8),
        Text(
          isOnboarding
              ? 'Upload clear identity document photos. We\'ll extract details securely and ask you to review them before submission.'
              : 'Manage your passport and visa documents. Upload clear and valid documents; we\'ll notify you after review.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 16),
        const _PrivacyReassurance(),
        const SizedBox(height: 22),
        if (loading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: CircularProgressIndicator(),
            ),
          )
        else if (uploading)
          _ProcessingPanel(message: uploadMessage)
        else if (pendingReview?.type == IdentityDocumentType.passport)
          _PassportPickerPanel(
            frontFileName: passportFrontFileName,
            backFileName: passportBackFileName,
            frontSavedPath: identity.passportFileUrl,
            backSavedPath: identity.passportBackFileUrl,
            frontPreviewBytes: passportFrontPreviewBytes,
            backPreviewBytes: passportBackPreviewBytes,
            frontUploading: passportFrontUploading,
            backUploading: passportBackUploading,
            frontError: passportFrontError,
            backError: passportBackError,
            frontKey: passportFrontKey,
            backKey: passportBackKey,
            onChooseFront: () => _choosePassportSide(_PassportSide.front),
            onChooseBack: () => _choosePassportSide(_PassportSide.back),
            onTakeFront: () => _choosePassportSideSource(
              _PassportSide.front,
              _DocumentUploadSource.camera,
            ),
            onTakeBack: () => _choosePassportSideSource(
              _PassportSide.back,
              _DocumentUploadSource.camera,
            ),
            onFileFront: () => _choosePassportSideSource(
              _PassportSide.front,
              _DocumentUploadSource.file,
            ),
            onFileBack: () => _choosePassportSideSource(
              _PassportSide.back,
              _DocumentUploadSource.file,
            ),
            onRemoveFront: () => _removePassportSide(_PassportSide.front),
            onRemoveBack: () => _removePassportSide(_PassportSide.back),
            onReview: _reviewDetails,
            manuallyReview: pendingReview!.ocrError != null,
          )
        else if (pendingReview != null)
          _ReadyForReviewPanel(
            fileName: selectedFileName ?? 'Document',
            type: pendingReview!.type,
            manuallyReview: pendingReview!.ocrError != null,
            onReplace: () => _chooseDocument(pendingReview!.type),
            onReview: _reviewDetails,
          )
        else if (passportSaved)
          _PassportPickerPanel(
            frontFileName: passportFrontFileName,
            backFileName: passportBackFileName,
            frontSavedPath: identity.passportFileUrl,
            backSavedPath: identity.passportBackFileUrl,
            frontPreviewBytes: passportFrontPreviewBytes,
            backPreviewBytes: passportBackPreviewBytes,
            frontUploading: passportFrontUploading,
            backUploading: passportBackUploading,
            frontError: passportFrontError,
            backError: passportBackError,
            frontKey: passportFrontKey,
            backKey: passportBackKey,
            status: DocumentStatusService.label(
              identity.passportStatus,
              uploaded: true,
              expiry: identity.passportExpiryDate,
            ),
            onChooseFront: () => _choosePassportSide(_PassportSide.front),
            onChooseBack: () => _choosePassportSide(_PassportSide.back),
            onTakeFront: () => _choosePassportSideSource(
              _PassportSide.front,
              _DocumentUploadSource.camera,
            ),
            onTakeBack: () => _choosePassportSideSource(
              _PassportSide.back,
              _DocumentUploadSource.camera,
            ),
            onFileFront: () => _choosePassportSideSource(
              _PassportSide.front,
              _DocumentUploadSource.file,
            ),
            onFileBack: () => _choosePassportSideSource(
              _PassportSide.back,
              _DocumentUploadSource.file,
            ),
            onRemoveFront: () => _removePassportSide(_PassportSide.front),
            onRemoveBack: () => _removePassportSide(_PassportSide.back),
            onViewFront: () => Navigator.of(context).pushNamed(
              AppRoutes.identityDocumentViewer,
              arguments: IdentityDocumentViewerArgs(
                title: 'Passport Front',
                path: identity.passportFileUrl,
              ),
            ),
            onViewBack: () => Navigator.of(context).pushNamed(
              AppRoutes.identityDocumentViewer,
              arguments: IdentityDocumentViewerArgs(
                title: 'Passport Back',
                path: identity.passportBackFileUrl,
              ),
            ),
            onReview: null,
          )
        else
          _PassportPickerPanel(
            frontFileName: passportFrontFileName,
            backFileName: passportBackFileName,
            frontSavedPath: identity.passportFileUrl,
            backSavedPath: identity.passportBackFileUrl,
            frontPreviewBytes: passportFrontPreviewBytes,
            backPreviewBytes: passportBackPreviewBytes,
            frontUploading: passportFrontUploading,
            backUploading: passportBackUploading,
            frontError: passportFrontError,
            backError: passportBackError,
            frontKey: passportFrontKey,
            backKey: passportBackKey,
            onChooseFront: () => _choosePassportSide(_PassportSide.front),
            onChooseBack: () => _choosePassportSide(_PassportSide.back),
            onTakeFront: () => _choosePassportSideSource(
              _PassportSide.front,
              _DocumentUploadSource.camera,
            ),
            onTakeBack: () => _choosePassportSideSource(
              _PassportSide.back,
              _DocumentUploadSource.camera,
            ),
            onFileFront: () => _choosePassportSideSource(
              _PassportSide.front,
              _DocumentUploadSource.file,
            ),
            onFileBack: () => _choosePassportSideSource(
              _PassportSide.back,
              _DocumentUploadSource.file,
            ),
            onRemoveFront: () => _removePassportSide(_PassportSide.front),
            onRemoveBack: () => _removePassportSide(_PassportSide.back),
            onReview: pendingReview == null ? null : _reviewDetails,
          ),
        const SizedBox(height: 14),
        if (!loading && !uploading && !passportBusy && pendingReview == null)
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
                  title: 'Visa / Emirates ID',
                  path: identity.visaFileUrl,
                ),
              ),
            )
          else
            _DocumentPickerPanel(
              key: visaKey,
              type: IdentityDocumentType.visa,
              onChoose: _chooseVisa,
              error: visaError,
            ),
        const SizedBox(height: 24),
        if (isOnboarding)
          PrimaryButton(
            label: continuing ? 'Continuing...' : 'Continue',
            icon: Icons.arrow_forward_rounded,
            onPressed: passportSaved &&
                    !uploading &&
                    !passportBusy &&
                    pendingReview == null &&
                    passportFrontError == null &&
                    passportBackError == null
                ? _continueOnboarding
                : null,
          ),
        if (isOnboarding && !passportSaved) ...[
          const SizedBox(height: 8),
          const Text(
            'Upload and save passport front and back to continue.',
            textAlign: TextAlign.center,
            style: AppTextStyles.muted,
          ),
        ],
        if (isOnboarding) ...[
          const SizedBox(height: 10),
          Center(
              child: TextButton(
                  onPressed: uploading ? null : _confirmSkip,
                  child: const Text("I'll do this later"))),
        ],
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

enum _PassportSide { front, back }

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
        const Text(
          'Step 1 of 5  ·  Identity verification',
          style: AppTextStyles.muted,
        ),
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

class _PassportPickerPanel extends StatelessWidget {
  const _PassportPickerPanel({
    required this.frontFileName,
    required this.backFileName,
    required this.frontSavedPath,
    required this.backSavedPath,
    required this.frontPreviewBytes,
    required this.backPreviewBytes,
    required this.frontUploading,
    required this.backUploading,
    this.frontError,
    this.backError,
    this.frontKey,
    this.backKey,
    required this.onChooseFront,
    required this.onChooseBack,
    required this.onTakeFront,
    required this.onTakeBack,
    required this.onFileFront,
    required this.onFileBack,
    required this.onRemoveFront,
    required this.onRemoveBack,
    required this.onReview,
    this.onViewFront,
    this.onViewBack,
    this.status,
    this.manuallyReview = false,
  });

  final String? frontFileName;
  final String? backFileName;
  final String frontSavedPath;
  final String backSavedPath;
  final Uint8List? frontPreviewBytes;
  final Uint8List? backPreviewBytes;
  final bool frontUploading;
  final bool backUploading;
  final String? frontError;
  final String? backError;
  final GlobalKey? frontKey;
  final GlobalKey? backKey;
  final VoidCallback onChooseFront;
  final VoidCallback onChooseBack;
  final VoidCallback onTakeFront;
  final VoidCallback onTakeBack;
  final VoidCallback onFileFront;
  final VoidCallback onFileBack;
  final VoidCallback onRemoveFront;
  final VoidCallback onRemoveBack;
  final VoidCallback? onReview;
  final VoidCallback? onViewFront;
  final VoidCallback? onViewBack;
  final String? status;
  final bool manuallyReview;

  @override
  Widget build(BuildContext context) {
    final frontReady =
        frontFileName != null || frontSavedPath.trim().isNotEmpty;
    final backReady = backFileName != null || backSavedPath.trim().isNotEmpty;
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
          Text(
            status == null ? 'Upload Passport' : 'Passport saved',
            style: AppTextStyles.title,
          ),
          const SizedBox(height: 6),
          Text(
            status == null
                ? 'Add clear images of both sides before review.'
                : 'Status: $status',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 16),
          _PassportSideSlot(
            key: frontKey,
            title: 'Passport Front',
            fileName: frontFileName,
            savedPath: frontSavedPath,
            previewBytes: frontPreviewBytes,
            uploading: frontUploading,
            onChoose: onChooseFront,
            onTakePhoto: onTakeFront,
            onChooseFile: onFileFront,
            onRemove: onRemoveFront,
            onView: onViewFront,
            error: frontError,
          ),
          const SizedBox(height: 12),
          _PassportSideSlot(
            key: backKey,
            title: 'Passport Back',
            fileName: backFileName,
            savedPath: backSavedPath,
            previewBytes: backPreviewBytes,
            uploading: backUploading,
            onChoose: onChooseBack,
            onTakePhoto: onTakeBack,
            onChooseFile: onFileBack,
            onRemove: onRemoveBack,
            onView: onViewBack,
            error: backError,
          ),
          const SizedBox(height: 16),
          Text(
            frontReady && backReady
                ? 'Passport images ready to review'
                : 'Upload front and back passport images to continue.',
            style: frontReady && backReady
                ? AppTextStyles.label.copyWith(color: AppColors.success)
                : AppTextStyles.muted,
          ),
          if (onReview != null) ...[
            const SizedBox(height: 14),
            PrimaryButton(
              label: manuallyReview
                  ? 'Enter Passport Details'
                  : 'Review Extracted Details',
              icon: Icons.fact_check_outlined,
              onPressed: frontReady && backReady ? onReview : null,
            ),
          ],
        ],
      ),
    );
  }
}

class _PassportSideSlot extends StatelessWidget {
  const _PassportSideSlot({
    super.key,
    required this.title,
    required this.fileName,
    required this.savedPath,
    required this.previewBytes,
    required this.uploading,
    required this.onChoose,
    required this.onTakePhoto,
    required this.onChooseFile,
    required this.onRemove,
    this.onView,
    this.error,
  });

  final String title;
  final String? fileName;
  final String savedPath;
  final Uint8List? previewBytes;
  final bool uploading;
  final VoidCallback onChoose;
  final VoidCallback onTakePhoto;
  final VoidCallback onChooseFile;
  final VoidCallback onRemove;
  final VoidCallback? onView;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final ready = fileName != null || savedPath.trim().isNotEmpty;
    final sideLabel = title == 'Passport Front' ? 'Front' : 'Back';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.elevatedCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ready ? Icons.check_circle_outline : Icons.badge_outlined,
                color: ready ? AppColors.success : AppColors.softPink,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(title, style: AppTextStyles.label)),
            ],
          ),
          const SizedBox(height: 10),
          _PassportImagePreview(
            previewBytes: previewBytes,
            fileName: fileName,
            savedPath: savedPath,
            uploading: uploading,
            onTap: onView,
          ),
          const SizedBox(height: 12),
          if (error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(error!, style: AppTextStyles.body),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: uploading ? null : onChoose,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
            const SizedBox(height: 4),
          ],
          if (!ready)
            SecondaryButton(
              label: 'Upload $title',
              onPressed: uploading ? null : onChoose,
            )
          else
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Replace $sideLabel',
                    onPressed: uploading ? null : onChoose,
                  ),
                ),
                if (onView != null || fileName != null) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: SecondaryButton(
                      label: onView != null ? 'View $sideLabel' : 'Remove',
                      onPressed: uploading ? null : (onView ?? onRemove),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _PassportImagePreview extends StatefulWidget {
  const _PassportImagePreview({
    required this.previewBytes,
    required this.fileName,
    required this.savedPath,
    required this.uploading,
    this.onTap,
  });

  final Uint8List? previewBytes;
  final String? fileName;
  final String savedPath;
  final bool uploading;
  final VoidCallback? onTap;

  @override
  State<_PassportImagePreview> createState() => _PassportImagePreviewState();
}

class _PassportImagePreviewState extends State<_PassportImagePreview> {
  final storage = const KaamStorageRepository();
  Future<String>? signedUrl;

  @override
  void initState() {
    super.initState();
    _refreshSignedUrl();
  }

  @override
  void didUpdateWidget(covariant _PassportImagePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.savedPath != widget.savedPath) {
      _refreshSignedUrl();
    }
  }

  void _refreshSignedUrl() {
    signedUrl = widget.savedPath.trim().isEmpty
        ? null
        : storage.signedPrivateUrl(widget.savedPath);
  }

  bool get _isPdf {
    final name = (widget.fileName ?? widget.savedPath).toLowerCase();
    return name.endsWith('.pdf');
  }

  @override
  Widget build(BuildContext context) {
    Widget preview;
    if (widget.previewBytes != null && !_isPdf) {
      preview = Image.memory(
        widget.previewBytes!,
        fit: BoxFit.cover,
        cacheWidth: (MediaQuery.devicePixelRatioOf(context) * 600).round(),
        gaplessPlayback: true,
        errorBuilder: (_, __, ___) => const _PassportPreviewPlaceholder(),
      );
    } else if (signedUrl != null && !_isPdf) {
      preview = FutureBuilder<String>(
        future: signedUrl,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return Image.network(
              snapshot.data!,
              fit: BoxFit.cover,
              cacheWidth:
                  (MediaQuery.devicePixelRatioOf(context) * 600).round(),
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const _PassportPreviewPlaceholder(),
            );
          }
          if (snapshot.hasError) {
            return const _PassportPreviewPlaceholder();
          }
          return const Center(child: CircularProgressIndicator());
        },
      );
    } else {
      preview = const _PassportPreviewPlaceholder();
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: double.infinity,
          height: 164,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: AppColors.card, child: preview),
              if (widget.uploading)
                ColoredBox(
                  color: Colors.black.withValues(alpha: .46),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: Colors.white),
                        SizedBox(height: 10),
                        Text(
                          'Uploading...',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PassportPreviewPlaceholder extends StatelessWidget {
  const _PassportPreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.badge_outlined,
            size: 38,
            color: AppColors.secondaryText,
          ),
          SizedBox(height: 8),
          Text(
            'JPG, PNG, or PDF up to 10 MB.',
            style: AppTextStyles.muted,
          ),
        ],
      ),
    );
  }
}

class _DocumentPickerPanel extends StatelessWidget {
  const _DocumentPickerPanel({
    super.key,
    required this.type,
    required this.onChoose,
    this.error,
  });

  final IdentityDocumentType type;
  final VoidCallback onChoose;
  final String? error;

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
            child: const Icon(
              Icons.badge_outlined,
              color: AppColors.softPink,
              size: 28,
            ),
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
              border: Border.all(
                color: AppColors.border,
                style: BorderStyle.solid,
              ),
            ),
            child: const Text(
              'Use a clear, well-lit image. JPG, PNG, or PDF up to 10 MB.',
              textAlign: TextAlign.center,
              style: AppTextStyles.muted,
            ),
          ),
          const SizedBox(height: 18),
          if (error != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.error.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(error!, style: AppTextStyles.body),
            ),
            const SizedBox(height: 12),
          ],
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
          Text(
            message.isEmpty ? 'Reading passport details...' : message,
            style: AppTextStyles.title,
          ),
          const SizedBox(height: 7),
          const Text(
            'This may take a few seconds.',
            style: AppTextStyles.muted,
          ),
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
          : type == IdentityDocumentType.passport
              ? 'Passport images ready to review'
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
                const Icon(
                  Icons.insert_drive_file_outlined,
                  size: 18,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.muted,
                  ),
                ),
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

class _UploadException implements Exception {
  const _UploadException(this.message);

  final String message;
}
