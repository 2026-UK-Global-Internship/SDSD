import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'home_screen.dart';

class CharacterColorScreen extends StatefulWidget {
  const CharacterColorScreen({super.key, required this.name});

  final String name;

  @override
  State<CharacterColorScreen> createState() => _CharacterColorScreenState();
}

class _CharacterColorScreenState extends State<CharacterColorScreen> {
  Color _selectedColor = const Color(0xFFB44DDB); // 기본 보라색

  static const _gradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFBBF24), Color(0xFFF472B6)],
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: _gradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 130),
                // TODO: 여기에 나중에 흰색 Dusty (고른 색으로 칠해짐)
                const Text(
                  "Choose Dusty's\ncolor.",
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 40,
                    height: 1.1,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Personalize your pet with a color.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w500,
                    fontSize: 20,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 24),
                // 컬러 피커
                Expanded(
                  child: SingleChildScrollView(
                    child: ColorPicker(
                      pickerColor: _selectedColor,
                      onColorChanged: (color) {
                        setState(() => _selectedColor = color);
                      },
                      colorPickerWidth: 320,
                      pickerAreaHeightPercent: 0.9,
                      enableAlpha: true,
                      labelTypes: const [],
                      displayThumbColor: true,
                      paletteType: PaletteType.hsvWithHue,
                      pickerAreaBorderRadius: const BorderRadius.all(
                        Radius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 100),
                // Continue 버튼
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: 고른 색 저장 + 홈으로 이동
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (_) => HomeScreen(name: widget.name),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: const Text(
                      'Continue',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
