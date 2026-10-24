import 'package:flutter/material.dart';
import '../models/property.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'property_image.dart';

class _Badge extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color bg;
  final Color fg;
  const _Badge(this.text, {this.icon, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Text(text,
              style: TextStyle(
                  color: fg, fontSize: 11, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _FavButton extends StatelessWidget {
  final bool active;
  final VoidCallback onTap;
  const _FavButton({required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(.55),
          shape: BoxShape.circle,
        ),
        child: Icon(
          active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 18,
          color: active ? AppColors.amber : Colors.white,
        ),
      ),
    );
  }
}

class _Specs extends StatelessWidget {
  final Property p;
  const _Specs(this.p);

  @override
  Widget build(BuildContext context) {
    final muted = AppTheme.muted(context);
    Widget spec(IconData i, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(i, size: 16, color: AppTheme.accentText(context)),
            const SizedBox(width: 4),
            Text(t, style: TextStyle(color: muted, fontSize: 12.5)),
          ],
        );
    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        if (p.beds > 0) spec(Icons.bed_rounded, '${p.beds}'),
        if (p.baths > 0) spec(Icons.bathtub_outlined, '${p.baths}'),
        spec(Icons.square_foot_rounded, '${p.area} م²'),
      ],
    );
  }
}

/// كارت العقار المميز (أفقي - سكرول جانبي).
class FeaturedPropertyCard extends StatelessWidget {
  final Property property;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  const FeaturedPropertyCard({
    super.key,
    required this.property,
    required this.isFavorite,
    required this.onFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = property;
    return Container(
      width: 285,
      margin: const EdgeInsetsDirectional.only(end: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  PropertyImage(
                      url: p.imageUrl, width: double.infinity, height: 160),
                  PositionedDirectional(
                    top: 10,
                    start: 10,
                    child: Row(
                      children: [
                        _Badge(p.listingType,
                            bg: AppColors.amber, fg: AppColors.black),
                        if (p.isVerified) ...[
                          const SizedBox(width: 6),
                          _Badge('موثّق',
                              icon: Icons.verified_rounded,
                              bg: Colors.black.withOpacity(.6),
                              fg: AppColors.amber),
                        ],
                      ],
                    ),
                  ),
                  PositionedDirectional(
                    top: 8,
                    end: 8,
                    child: _FavButton(active: isFavorite, onTap: onFavorite),
                  ),
                ],
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.priceLabel,
                          style: TextStyle(
                              color: AppTheme.accentText(context),
                              fontSize: 18,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 2),
                      Text(p.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14.5, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 15, color: AppTheme.muted(context)),
                          const SizedBox(width: 3),
                          Text('${p.district} • ${p.type}',
                              style: TextStyle(
                                  color: AppTheme.muted(context),
                                  fontSize: 12.5)),
                        ],
                      ),
                      const Spacer(),
                      _Specs(p),
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

/// كارت العقار في القائمة الرأسية.
class PropertyListTile extends StatelessWidget {
  final Property property;
  final bool isFavorite;
  final VoidCallback onFavorite;
  final VoidCallback onTap;

  const PropertyListTile({
    super.key,
    required this.property,
    required this.isFavorite,
    required this.onFavorite,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = property;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.outline(context)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 118,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      PropertyImage(url: p.imageUrl),
                      PositionedDirectional(
                        top: 8,
                        start: 8,
                        child: _Badge(p.listingType,
                            bg: AppColors.amber, fg: AppColors.black),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(p.priceLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: AppTheme.accentText(context),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900)),
                            ),
                            GestureDetector(
                              onTap: onFavorite,
                              child: Icon(
                                isFavorite
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 20,
                                color: isFavorite
                                    ? AppColors.amber
                                    : AppTheme.muted(context),
                              ),
                            ),
                          ],
                        ),
                        Text(p.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 14, color: AppTheme.muted(context)),
                            const SizedBox(width: 2),
                            Expanded(
                              child: Text('${p.district} • ${p.type}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: AppTheme.muted(context),
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _Specs(p),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
