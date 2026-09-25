import 'package:flutter/material.dart';
import '../constants/app_images.dart';
import '../constants/app_strings.dart';
import '../routes/app_routes.dart';
import '../theme/app_theme.dart';
import '../theme/text_styles.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          Navigator.of(context).pushReplacementNamed(AppRoutes.login);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              AppImages.splashBg,
              fit: BoxFit.cover,
            ),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.35),
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
            Align(
              alignment: const Alignment(0, -0.15),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    AppImages.logo,
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(height: 10),
                  Text(AppStrings.appName, style: CyberniStyles.title),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const _OrnamentDash(),
                      const SizedBox(width: 8),
                      Text(AppStrings.tagline, style: CyberniStyles.subtitle),
                      const SizedBox(width: 8),
                      const _OrnamentDash(),
                    ],
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.diamond_outlined,
                      size: 9, color: AppColors.parchmentSoft),
                  const SizedBox(width: 10),
                  Text(AppStrings.tapToContinue, style: CyberniStyles.cta),
                  const SizedBox(width: 10),
                  const Icon(Icons.diamond_outlined,
                      size: 9, color: AppColors.parchmentSoft),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrnamentDash extends StatelessWidget {
  const _OrnamentDash();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 1,
      color: AppColors.parchmentDim,
    );
  }
}