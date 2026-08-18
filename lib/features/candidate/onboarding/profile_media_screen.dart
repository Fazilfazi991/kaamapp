import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/constants/app_routes.dart';
import '../../../core/storage/private_profile_photo_resolver.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/primary_button.dart';
import '../../../core/widgets/private_profile_photo_avatar.dart';
import '../../../core/widgets/progress_stepper.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/secondary_button.dart';
import '../../supabase_backend/kaam_backend.dart';

class ProfileMediaScreen extends StatefulWidget {
  const ProfileMediaScreen({super.key});

  @override
  State<ProfileMediaScreen> createState() => _ProfileMediaScreenState();
}

class _ProfileMediaScreenState extends State<ProfileMediaScreen> {
  static const maxPhotoBytes = 5 * 1024 * 1024;
  static const maxCvBytes = 10 * 1024 * 1024;

  final repository = const CandidateProfileRepository();
  final storage = const KaamStorageRepository();
  final picker = ImagePicker();

  CandidateProfileData profile = const CandidateProfileData();
  bool loading = true;
  bool uploadingPhoto = false;
  bool uploadingCv = false;
  String? error;
  Uint8List? localPhotoBytes;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final loaded = await repository.loadCurrentProfile();
      if (mounted) {
        setState(() {
          profile = loaded;
        });
      }
    } catch (_) {
      if (mounted) _show('We could not load your profile media.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    if (uploadingPhoto) return;
    if (source == ImageSource.camera) {
      final permission = await Permission.camera.request();
      if (!mounted) return;
      if (!permission.isGranted) {
        _show(
          'Camera permission is required to take a profile photo. You can enable it from your device settings.',
        );
        return;
      }
    }
    final previousPath = profile.profilePhotoUrl;
    final previousLocalBytes = localPhotoBytes;
    setState(() {
      uploadingPhoto = true;
      error = null;
    });
    try {
      final image = await picker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (!mounted) return;
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      final extension = _extension(image.name);
      if (!const ['jpg', 'jpeg', 'png', 'webp'].contains(extension)) {
        throw const _MediaException(
          'Unsupported photo format. Please upload a JPG, JPEG, PNG, or WEBP image.',
        );
      }
      if (bytes.isEmpty) {
        throw const _MediaException(
          'This photo is empty. Please choose another image.',
        );
      }
      if (bytes.length > maxPhotoBytes) {
        throw const _MediaException(
          'This photo is too large. Please choose a smaller image.',
        );
      }
      setState(() {
        localPhotoBytes = bytes;
      });
      final upload = await storage.uploadPrivateFile(
        bytes: bytes,
        fileName: image.name,
        folder: 'candidate-profile-photos',
      );
      final updated = await repository.updateProfilePhoto(
        upload.path,
        fileName: image.name,
      );
      PrivateProfilePhotoResolver.replace(
        previousPath,
        updated.profilePhotoUrl,
      );
      if (!mounted) return;
      setState(() {
        profile = updated;
        localPhotoBytes = bytes;
      });
      _show('Profile photo saved.');
    } on _MediaException catch (exception) {
      if (!mounted) return;
      setState(() {
        localPhotoBytes = previousLocalBytes;
        error = exception.message;
      });
    } catch (exception) {
      _debugMediaUpload(
        stage: 'profile_photo_upload_failed',
        extension: '',
        fileSize: null,
        error: exception,
      );
      if (!mounted) return;
      setState(() {
        localPhotoBytes = previousLocalBytes;
        error =
            'We could not upload your profile photo right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          uploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _pickCv() async {
    if (uploadingCv) return;
    setState(() {
      uploadingCv = true;
      error = null;
    });
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        withReadStream: true,
        type: FileType.any,
      );
      if (!mounted) return;
      final file = result?.files.single;
      if (file == null) return;
      final extension = _extension(file.name);
      if (!const ['pdf', 'doc', 'docx'].contains(extension)) {
        throw const _MediaException(
          'Unsupported CV format. Please upload a PDF, DOC, or DOCX file.',
        );
      }
      final bytes = await _readPlatformFileBytes(file);
      if (!mounted) return;
      if (bytes.isEmpty) {
        throw const _MediaException(
          'This CV is empty. Please choose another file.',
        );
      }
      if (bytes.length > maxCvBytes) {
        throw const _MediaException(
          'This file is too large. Please upload a CV smaller than 10 MB.',
        );
      }
      _debugMediaUpload(
        stage: 'cv_upload_started',
        extension: extension,
        fileSize: bytes.length,
      );
      final upload = await storage.uploadPrivateFile(
        bytes: bytes,
        fileName: file.name,
        folder: 'candidate-cv',
      );
      final updated = await repository.updateResumePath(
        upload.path,
        fileName: file.name,
        fileSize: bytes.length,
      );
      if (!mounted) return;
      setState(() {
        profile = updated;
      });
      _show('CV uploaded successfully.');
    } on _MediaException catch (exception) {
      if (!mounted) return;
      setState(() {
        error = exception.message;
      });
    } on _FileReadException catch (exception) {
      _debugMediaUpload(
        stage: 'cv_read_failed',
        extension: exception.extension,
        fileSize: exception.fileSize,
        error: exception,
      );
      if (!mounted) return;
      setState(() {
        error = 'We could not read this file. Please choose another file.';
      });
    } catch (exception) {
      _debugMediaUpload(
        stage: 'cv_upload_failed',
        extension: '',
        fileSize: null,
        error: exception,
      );
      if (!mounted) return;
      setState(() {
        error = 'We could not upload your CV right now. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          uploadingCv = false;
        });
      }
    }
  }

  Future<void> _removePhoto() async {
    if (uploadingPhoto) return;
    final previousPath = profile.profilePhotoUrl;
    setState(() {
      uploadingPhoto = true;
      error = null;
    });
    try {
      final updated = await repository.updateProfilePhoto('');
      PrivateProfilePhotoResolver.replace(previousPath, '');
      if (!mounted) return;
      setState(() {
        profile = updated;
        localPhotoBytes = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          error =
              'We could not remove your profile photo right now. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          uploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _removeCv() async {
    try {
      final updated = await repository.updateResumePath('');
      if (!mounted) return;
      setState(() {
        profile = updated;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        error = 'We could not remove your CV right now. Please try again.';
      });
    }
  }

  Future<Uint8List> _readPlatformFileBytes(PlatformFile file) async {
    final extension = _extension(file.name);
    final bytes = file.bytes;
    if (bytes != null) return bytes;

    final stream = file.readStream;
    if (stream != null) {
      try {
        final chunks = <int>[];
        await for (final chunk in stream) {
          chunks.addAll(chunk);
        }
        return Uint8List.fromList(chunks);
      } catch (error) {
        throw _FileReadException(
          extension: extension,
          fileSize: file.size,
          cause: error,
        );
      }
    }

    final path = file.path;
    if (path != null &&
        path.trim().isNotEmpty &&
        !path.startsWith('content://')) {
      try {
        return await File(path).readAsBytes();
      } catch (error) {
        throw _FileReadException(
          extension: extension,
          fileSize: file.size,
          cause: error,
        );
      }
    }

    throw _FileReadException(extension: extension, fileSize: file.size);
  }

  String _extension(String name) {
    final parts = name.toLowerCase().split('.');
    return parts.length < 2 ? '' : parts.last;
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      title: 'Profile Photo and CV',
      showBack: true,
      children: [
        const ProgressStepper(current: 5, total: 6),
        const SizedBox(height: 22),
        const Text('Add your photo and CV', style: AppTextStyles.headline),
        const SizedBox(height: 8),
        const Text(
          'These files are stored privately and can be replaced later.',
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 16),
        if (loading) const LinearProgressIndicator(),
        if (error != null) ...[
          AppCard(
            child: Text(
              error!,
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
          ),
          const SizedBox(height: 12),
        ],
        _PhotoCard(
          uploading: uploadingPhoto,
          savedPath: profile.profilePhotoUrl,
          localBytes: localPhotoBytes,
          initials: profileInitials(profile.fullName),
          onCamera: () => _pickPhoto(ImageSource.camera),
          onGallery: () => _pickPhoto(ImageSource.gallery),
          onRemove: profile.profilePhotoUrl.isEmpty ? null : _removePhoto,
        ),
        const SizedBox(height: 14),
        _CvCard(
          uploading: uploadingCv,
          fileName: profile.resumeFileName.isNotEmpty
              ? profile.resumeFileName
              : _fileName(profile.resumeUrl),
          fileSize: profile.resumeFileSize,
          onChoose: _pickCv,
          onRemove: profile.resumeUrl.isEmpty ? null : _removeCv,
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Review Profile',
          icon: Icons.arrow_forward_rounded,
          onPressed: uploadingPhoto || uploadingCv
              ? null
              : () =>
                  Navigator.of(context).pushNamed(AppRoutes.profileComplete),
        ),
      ],
    );
  }

  String _fileName(String path) => path.isEmpty ? '' : path.split('/').last;
}

class _PhotoCard extends StatelessWidget {
  const _PhotoCard({
    required this.uploading,
    required this.savedPath,
    required this.localBytes,
    required this.initials,
    required this.onCamera,
    required this.onGallery,
    required this.onRemove,
  });

  final bool uploading;
  final String savedPath;
  final Uint8List? localBytes;
  final String initials;
  final VoidCallback onCamera;
  final VoidCallback onGallery;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Profile Photo', style: AppTextStyles.title),
          const SizedBox(height: 12),
          Center(
            child: PrivateProfilePhotoAvatar(
              path: savedPath,
              initials: initials,
              localBytes: localBytes,
              size: 104,
              uploading: uploading,
            ),
          ),
          const SizedBox(height: 12),
          if (uploading) const LinearProgressIndicator(),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: savedPath.isEmpty ? 'Take Photo' : 'Replace Photo',
                  onPressed: uploading ? null : onCamera,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SecondaryButton(
                  label: 'Choose from Gallery',
                  onPressed: uploading ? null : onGallery,
                ),
              ),
            ],
          ),
          if (onRemove != null) ...[
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Remove Photo',
              onPressed: uploading ? null : onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

class _CvCard extends StatelessWidget {
  const _CvCard({
    required this.uploading,
    required this.fileName,
    required this.fileSize,
    required this.onChoose,
    required this.onRemove,
  });

  final bool uploading;
  final String fileName;
  final int? fileSize;
  final VoidCallback onChoose;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final hasCv = fileName.isNotEmpty;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CV', style: AppTextStyles.title),
          const SizedBox(height: 6),
          const Text(
            'Supported formats: PDF, DOC, DOCX',
            style: AppTextStyles.muted,
          ),
          const SizedBox(height: 12),
          if (uploading) const LinearProgressIndicator(),
          if (hasCv) ...[
            Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  color: AppColors.softPink,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            ),
            if (fileSize != null)
              Text(
                '${(fileSize! / 1024).ceil()} KB',
                style: AppTextStyles.muted,
              ),
            const SizedBox(height: 12),
          ],
          PrimaryButton(
            label: hasCv ? 'Replace CV' : 'Choose CV',
            icon: Icons.upload_file_outlined,
            onPressed: uploading ? null : onChoose,
          ),
          if (onRemove != null) ...[
            const SizedBox(height: 10),
            SecondaryButton(
              label: 'Remove CV',
              onPressed: uploading ? null : onRemove,
            ),
          ],
        ],
      ),
    );
  }
}

class _MediaException implements Exception {
  const _MediaException(this.message);

  final String message;
}

class _FileReadException implements Exception {
  const _FileReadException({
    required this.extension,
    required this.fileSize,
    this.cause,
  });

  final String extension;
  final int? fileSize;
  final Object? cause;
}

void _debugMediaUpload({
  required String stage,
  required String extension,
  required int? fileSize,
  Object? error,
}) {
  if (!kDebugMode) return;
  final code = error == null ? 'none' : error.runtimeType.toString();
  debugPrint(
    '[ProfileMedia] stage=$stage extension=$extension size=${fileSize ?? 0} code=$code',
  );
}
