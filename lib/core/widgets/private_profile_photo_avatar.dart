import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../storage/private_profile_photo_resolver.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

typedef PrivateProfilePhotoResolve = Future<String> Function(
  String path, {
  String? candidateId,
  bool forceRefresh,
});

typedef PrivateProfilePhotoNeedsRefresh = bool Function(String path);

class PrivateProfilePhotoAvatar extends StatefulWidget {
  const PrivateProfilePhotoAvatar({
    super.key,
    required this.path,
    required this.initials,
    this.candidateId,
    this.localBytes,
    this.size = 48,
    this.uploading = false,
    this.resolvePhoto,
    this.photoChanges,
    this.needsRefresh,
  });

  final String path;
  final String initials;
  final String? candidateId;
  final Uint8List? localBytes;
  final double size;
  final bool uploading;
  @visibleForTesting
  final PrivateProfilePhotoResolve? resolvePhoto;
  @visibleForTesting
  final ValueListenable<PrivateProfilePhotoChange?>? photoChanges;
  @visibleForTesting
  final PrivateProfilePhotoNeedsRefresh? needsRefresh;

  @override
  State<PrivateProfilePhotoAvatar> createState() =>
      _PrivateProfilePhotoAvatarState();
}

class _PrivateProfilePhotoAvatarState extends State<PrivateProfilePhotoAvatar>
    with WidgetsBindingObserver {
  Future<String>? _signedUrlFuture;
  late String _effectivePath;
  bool _retriedAfterImageError = false;
  bool _retryInFlight = false;
  bool _disposed = false;
  int _requestGeneration = 0;

  ValueListenable<PrivateProfilePhotoChange?> get _changes =>
      widget.photoChanges ?? PrivateProfilePhotoResolver.changes;

  PrivateProfilePhotoResolve get _resolver =>
      widget.resolvePhoto ?? PrivateProfilePhotoResolver.resolve;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _changes.addListener(_handlePhotoChange);
    _effectivePath = widget.path.trim();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant PrivateProfilePhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.photoChanges != widget.photoChanges) {
      (oldWidget.photoChanges ?? PrivateProfilePhotoResolver.changes)
          .removeListener(_handlePhotoChange);
      _changes.addListener(_handlePhotoChange);
    }
    if (oldWidget.path != widget.path ||
        oldWidget.candidateId != widget.candidateId ||
        oldWidget.resolvePhoto != widget.resolvePhoto) {
      _effectivePath = widget.path.trim();
      _resolve();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        (widget.needsRefresh ?? PrivateProfilePhotoResolver.needsRefresh)(
          _effectivePath,
        )) {
      _resolve(forceRefresh: true);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _requestGeneration += 1;
    _changes.removeListener(_handlePhotoChange);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _handlePhotoChange() {
    final change = _changes.value;
    if (change == null || !mounted) return;
    if (change.previousPath.isEmpty && change.nextPath.isEmpty) {
      _requestGeneration += 1;
      _retryInFlight = false;
      setState(() {
        _signedUrlFuture = null;
      });
      return;
    }
    if (_effectivePath != change.previousPath) return;
    setState(() {
      _effectivePath = change.nextPath;
    });
    _resolve(forceRefresh: true);
  }

  void _resolve({bool forceRefresh = false}) {
    if (!mounted || _disposed) return;
    final requestGeneration = ++_requestGeneration;
    _retriedAfterImageError = false;
    _retryInFlight = false;
    final path = _effectivePath;
    final next = PrivateProfilePhotoResolver.isCandidatePhotoPath(
      path,
      candidateId: widget.candidateId,
    )
        ? _guardedResolution(
            _resolver(
              path,
              candidateId: widget.candidateId,
              forceRefresh: forceRefresh,
            ),
            requestGeneration,
          )
        : null;
    if (!mounted || _disposed || requestGeneration != _requestGeneration) {
      return;
    }
    setState(() {
      _signedUrlFuture = next;
    });
  }

  Future<String> _guardedResolution(
    Future<String> resolution,
    int requestGeneration,
  ) async {
    final url = await resolution;
    if (_disposed || requestGeneration != _requestGeneration) return '';
    return url;
  }

  void _retryAfterImageError() {
    if (_retriedAfterImageError ||
        _retryInFlight ||
        _effectivePath.isEmpty ||
        !mounted ||
        _disposed) {
      return;
    }
    _retriedAfterImageError = true;
    _retryInFlight = true;
    final requestGeneration = ++_requestGeneration;
    final retry = _guardedResolution(
      _resolver(
        _effectivePath,
        candidateId: widget.candidateId,
        forceRefresh: true,
      ),
      requestGeneration,
    );
    if (!mounted || _disposed || requestGeneration != _requestGeneration) {
      return;
    }
    setState(() {
      _signedUrlFuture = retry;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fallbackInitials =
        widget.initials.trim().isEmpty ? 'K' : widget.initials.trim();

    Widget fallback() => Container(
          width: widget.size,
          height: widget.size,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.elevatedCard,
            shape: BoxShape.circle,
          ),
          child: Text(
            fallbackInitials,
            style: AppTextStyles.label.copyWith(color: AppColors.primaryPink),
          ),
        );

    Widget photo;
    if (widget.localBytes != null) {
      photo = ClipOval(
        child: Image.memory(
          widget.localBytes!,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => fallback(),
        ),
      );
    } else if (_signedUrlFuture != null) {
      photo = ClipOval(
        child: FutureBuilder<String>(
          future: _signedUrlFuture,
          builder: (context, snapshot) {
            final signedUrl = snapshot.data;
            if (snapshot.hasError || signedUrl == null || signedUrl.isEmpty) {
              return fallback();
            }
            return Image.network(
              signedUrl,
              width: widget.size,
              height: widget.size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) {
                scheduleMicrotask(_retryAfterImageError);
                return fallback();
              },
            );
          },
        ),
      );
    } else {
      photo = fallback();
    }

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          photo,
          if (widget.uploading)
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: .42),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

String profileInitials(String name, {String fallback = 'K'}) {
  final initials = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
  return initials.isEmpty ? fallback : initials;
}
