import 'package:flutter/material.dart';
import 'package:menuray_merchant/features/templates/primary_swatches.dart';
import 'package:menuray_merchant/theme/app_colors.dart';

class SwatchTile extends StatelessWidget {
  const SwatchTile({
    super.key,
    required this.hex,
    required this.isSelected,
    required this.onTap,
  });

  final String hex;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = parseHexColor(hex);
    return InkWell(
      key: Key('swatch-$hex'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
          boxShadow: const [
            BoxShadow(
                color: Color(0x10000000),
                blurRadius: 2,
                offset: Offset(0, 1)),
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 22)
            : null,
      ),
    );
  }
}
