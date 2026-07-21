import 'package:flutter/material.dart';
import '../../../shared/widgets/avatar_widget.dart';

class ParticipantChip extends StatelessWidget {
  final String name;
  final bool selected;
  final VoidCallback? onTap;

  const ParticipantChip({
    super.key,
    required this.name,
    this.selected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Chip(
        avatar: AvatarWidget(imageUrl: null, name: name, radius: 14),
        label: Text(
          name,
          style: TextStyle(fontSize: 12, color: selected ? Colors.white : null),
        ),
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primary
            : null,
        side: selected
            ? BorderSide.none
            : BorderSide(color: Colors.grey.shade300),
      ),
    );
  }
}
