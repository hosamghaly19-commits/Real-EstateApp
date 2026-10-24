import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class _BannerData {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool amber;
  const _BannerData(this.title, this.subtitle, this.icon, this.amber);
}

const _banners = [
  _BannerData('معاينة جادة.. بقرار واثق',
      'رسوم معاينة بسيطة تثبت جدية طلبك وتضمن وقتك ووقت المالك.',
      Icons.verified_user_rounded, true),
  _BannerData('أحدث مشاريع المطورين',
      'كمبوندات وأبراج بأنظمة سداد مرنة وتسليم قريب.',
      Icons.apartment_rounded, false),
  _BannerData('مكاتب عقارية موثّقة',
      'تعامل مع وسطاء معتمدين وعروض مراجَعة من فريقنا.',
      Icons.handshake_rounded, false),
];

class PromoBanners extends StatefulWidget {
  const PromoBanners({super.key});

  @override
  State<PromoBanners> createState() => _PromoBannersState();
}

class _PromoBannersState extends State<PromoBanners> {
  final _controller = PageController(viewportFraction: .92);
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 150,
          child: PageView.builder(
            controller: _controller,
            itemCount: _banners.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => _Banner(data: _banners[i]),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_banners.length, (i) {
            final active = i == _index;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: active ? 22 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: active
                    ? AppColors.amber
                    : Theme.of(context).colorScheme.onSurface.withOpacity(.2),
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final _BannerData data;
  const _Banner({required this.data});

  @override
  Widget build(BuildContext context) {
    final fg = data.amber ? AppColors.black : Colors.white;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 6),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: data.amber
              ? [AppColors.amber, AppColors.amberDeep]
              : [AppColors.charcoalLight, AppColors.black],
        ),
        border: data.amber
            ? null
            : Border.all(color: AppColors.amber.withOpacity(.25)),
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            end: -14,
            bottom: -18,
            child: Icon(data.icon,
                size: 130,
                color: (data.amber ? Colors.black : AppColors.amber)
                    .withOpacity(.14)),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(data.title,
                    style: TextStyle(
                        color: fg, fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                SizedBox(
                  width: 220,
                  child: Text(data.subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: fg.withOpacity(.8), fontSize: 12.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
