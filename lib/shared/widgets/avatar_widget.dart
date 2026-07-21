import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AvatarWidget extends StatelessWidget {
  final String? imageUrl;
  final String? name;
  final double radius;
  final double fontSize;

  const AvatarWidget({
    super.key,
    this.imageUrl,
    this.name,
    this.radius = 20,
    this.fontSize = 18,
  });

  @override
  Widget build(BuildContext context) {
    final safeName = (name ?? '?').trim().replaceAll(' ', '');
    final initial = safeName.isNotEmpty
        ? safeName[0].toUpperCase() + safeName[1].toLowerCase()
        : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.2),
      child: Text(
        initial,
        style: GoogleFonts.comicNeue(
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }
}
