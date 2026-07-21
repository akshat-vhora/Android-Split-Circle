import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/friends_providers.dart';
import '../../../services/supabase_service.dart';

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});
  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  MobileScannerController? _scannerController;
  bool _processing = false;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  Future<void> _handleCode(String? code) async {
    if (code == null || _processing) {
      return;
    }
    setState(() => _processing = true);
    try {
      final user = await ref
          .read(friendsRepositoryProvider)
          .findUserByUniqueId(code);
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('User not found')));
        }
      } else if (user.uid == SupabaseService.instance.currentUid) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Cannot add yourself')));
        }
      } else if (!await ref
          .read(friendsRepositoryProvider)
          .canSendRequest(SupabaseService.instance.currentUid, user.uid)) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Already friends')));
        }
      } else {
        final current = await SupabaseService.instance.getCurrentUser();
        await ref
            .read(friendsRepositoryProvider)
            .sendFriendRequest(
              current.uid,
              user.uid,
            );
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Friend added!')));
          context.pop();
        }
      }
    } catch (e) {
      debugPrint('QR scan error: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to process.')));
      }
    }
    if (mounted) {
      setState(() => _processing = false);
    }
  }

  Future<void> _pickFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) {
      return;
    }
    setState(() => _processing = true);
    try {
      final capture = await _scannerController?.analyzeImage(image.path);
      String? code;
      for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
        code = barcode.rawValue;
        if (code != null && code.isNotEmpty) {
          break;
        }
      }
      if (code != null) {
        await _handleCode(code);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No QR code found in image')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to read QR.')));
      }
    }
    if (mounted) {
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan QR Code'),
        actions: [
          IconButton(
            icon: const Icon(Icons.image_outlined),
            onPressed: _pickFromGallery,
          ),
          IconButton(
            icon: const Icon(Icons.flash_on_rounded),
            onPressed: () => _scannerController?.toggleTorch(),
          ),
        ],
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _scannerController,
            onDetect: (capture) {
              final code = capture.barcodes.firstOrNull?.rawValue;
              _handleCode(code);
            },
          ),
          // ── Scan Overlay ────────────────────────────────────
          IgnorePointer(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.6),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          if (_processing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }
}
