import 'package:flutter/material.dart';
import '../theme/app_text_styles.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/dusty.png', width: 140),
            const SizedBox(height: 24),
            Text(
              'SDSD',
              style: AppTextStyles.bold40.copyWith(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            Text(
              'Stop the Dump, Save Daily.',
              style: AppTextStyles.medium16.copyWith(
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
