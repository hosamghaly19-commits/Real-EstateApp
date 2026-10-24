import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PropertyImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;

  const PropertyImage({super.key, required this.url, this.width, this.height});

  Widget _placeholder() => Container(
        width: width,
        height: height,
        color: AppColors.charcoalLight,
        child: Icon(Icons.apartment_rounded,
            size: 36, color: AppColors.amber.withOpacity(.5)),
      );

  @override
  Widget build(BuildContext context) {
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      loadingBuilder: (_, child, progress) =>
          progress == null ? child : _placeholder(),
      errorBuilder: (_, __, ___) => _placeholder(),
    );
  }
}
