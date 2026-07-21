import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/friends_providers.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/loading_dialog.dart';
import '../../../services/supabase_service.dart';

class AddFriendScreen extends ConsumerStatefulWidget {
  const AddFriendScreen({super.key});
  @override
  ConsumerState<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends ConsumerState<AddFriendScreen> {
  final _controller = TextEditingController();
  final _scannerController = MobileScannerController();
  bool _searching = false;
  dynamic _foundUser;
  String? _error;
  bool _requestSent = false;

  @override
  void dispose() {
    _controller.dispose();
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) {
      return;
    }
    setState(() {
      _searching = true;
      _foundUser = null;
      _error = null;
    });
    try {
      final user = await ref
          .read(friendsRepositoryProvider)
          .findUserByUniqueId(query);
      if (user == null) {
        setState(() => _error = 'User not found');
      } else if (user.uid == SupabaseService.instance.currentUid) {
        setState(() => _error = 'Cannot add yourself');
      } else {
        final canSend = await ref
            .read(friendsRepositoryProvider)
            .canSendRequest(SupabaseService.instance.currentUid, user.uid);
        if (!canSend) {
          setState(() => _error = 'Already friends');
          return;
        }
        setState(() {
          _foundUser = user;
          _requestSent = false;
        });
      }
    } catch (e) {
      setState(() => _error = 'Search failed');
    }
    setState(() => _searching = false);
  }

  Future<void> _sendRequest() async {
    if (_foundUser == null) {
      return;
    }
    showLoadingDialog(context, message: 'Adding friend...');
    try {
      final current = await SupabaseService.instance.getCurrentUser();
      await ref
          .read(friendsRepositoryProvider)
          .sendFriendRequest(
            current.uid,
            _foundUser!.uid,
          );
      if (mounted) {
        Navigator.pop(context);
        setState(() => _requestSent = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Friend added!')));
      }
    } catch (e) {
      debugPrint('Add friend error: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to add friend. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _handleCode(String? code) async {
    if (code == null || code.isEmpty) {
      return;
    }
    _controller.text = code;
    await _search();
  }

  void _scanQr() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.55,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    const Text(
                      'Scan QR Code',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: MobileScanner(
                  onDetect: (capture) {
                    final code = capture.barcodes.firstOrNull?.rawValue;
                    Navigator.pop(context);
                    _handleCode(code);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _uploadQr() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) {
      return;
    }
    showLoadingDialog(context, message: 'Reading QR...');
    try {
      final capture = await _scannerController.analyzeImage(image.path);
      String? code;
      for (final barcode in capture?.barcodes ?? const <Barcode>[]) {
        final raw = barcode.rawValue;
        if (raw != null && raw.isNotEmpty) {
          code = raw;
          break;
        }
      }
      if (mounted) {
        Navigator.pop(context);
      }
      if (code != null && mounted) {
        _controller.text = code;
        await _search();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No QR code found in image.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Failed to read QR.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textMuted = Theme.of(context).colorScheme.onSurfaceVariant;
    final surface = isDark
        ? const Color(0xFF16162A).withValues(alpha: 0.6)
        : Colors.white.withValues(alpha: 0.8);

    return Scaffold(
      appBar: AppBar(title: const Text('Add Friend')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ── Search Section ──────────────────────────────────
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.04),
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.person_search_rounded,
                        color: Theme.of(context).colorScheme.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Find by ID',
                      style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Enter unique ID',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _controller.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _controller.clear();
                              setState(() {
                                _foundUser = null;
                                _error = null;
                              });
                            },
                          )
                        : null,
                  ),
                  onChanged: (_) => setState(() {
                    _foundUser = null;
                    _error = null;
                  }),
                  onSubmitted: (_) => _search(),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton.icon(
                    onPressed: _searching ? null : _search,
                    icon: _searching
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.search, size: 18),
                    label: Text(_searching ? 'Searching...' : 'Search'),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _qrOption(
                        context,
                        icon: Icons.qr_code_scanner_rounded,
                        label: 'Scan QR',
                        description: 'Use camera',
                        onTap: _scanQr,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _qrOption(
                        context,
                        icon: Icons.image_outlined,
                        label: 'Upload QR',
                        description: 'From gallery',
                        onTap: _uploadQr,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Result ──────────────────────────────────────────
          if (_searching)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFEF4444),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(
                        color: Color(0xFFEF4444),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (_foundUser != null)
            Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.black.withValues(alpha: 0.04),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  AvatarWidget(
                    imageUrl: null,
                    name: _foundUser!.displayName,
                    radius: 28,
                    fontSize: 20,
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _foundUser!.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _foundUser!.email,
                          style: TextStyle(fontSize: 13, color: textMuted),
                        ),
                      ],
                    ),
                  ),
                  _requestSent
                      ? Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFFD166,
                            ).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(
                                0xFFFFD166,
                              ).withValues(alpha: 0.2),
                            ),
                          ),
                          child: const Icon(
                            Icons.schedule_rounded,
                            color: Color(0xFFFFD166),
                            size: 22,
                          ),
                        )
                      : SizedBox(
                          width: 42,
                          height: 42,
                          child: Material(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: _sendRequest,
                              child: const Icon(
                                Icons.person_add_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _qrOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String description,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark
          ? const Color(0xFF1C1C2E).withValues(alpha: 0.75)
          : const Color(0xFFFFFBFA).withValues(alpha: 0.95),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.06)
                  : Colors.black.withValues(alpha: 0.04),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
