import 'package:flutter/material.dart';

class AppTextStyles {
  static const String fontFamily = 'Inter';

  // SF Pro Bold 40
  static const TextStyle bold40 = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w700,
    fontSize: 40,
  );

  // SF Pro Medium 20, letter spacing -1px
  static const TextStyle medium20 = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 20,
    letterSpacing: -1,
  );

  // SF Pro SemiBold 20
  static const TextStyle semiBold20 = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w600,
    fontSize: 20,
  );

  // SF Pro Medium 16
  static const TextStyle medium16 = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w500,
    fontSize: 16,
  );
}
