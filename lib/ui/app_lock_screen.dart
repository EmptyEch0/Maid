import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import 'widgets/glass_widgets.dart';

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  String _enteredPin = '';
  String? _errorMessage;

  void _onKeyPress(String digit) {
    if (_enteredPin.length < 4) {
      setState(() {
        _enteredPin += digit;
        _errorMessage = null;
      });

      if (_enteredPin.length == 4) {
        _verify();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _errorMessage = null;
      });
    }
  }

  void _verify() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final success = provider.verifyPin(_enteredPin);
    if (!success) {
      setState(() {
        _enteredPin = '';
        _errorMessage = 'Incorrect PIN. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing Frosted Glass Logo Box
                GlassContainer(
                  padding: const EdgeInsets.all(16),
                  borderRadius: 28,
                  blurSigma: 16,
                  shadows: [
                    BoxShadow(
                      color: colorScheme.primary.withValues(alpha: isDark ? 0.35 : 0.2),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: Colors.white,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset('assets/images/app_logo.png', fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Maid Assistant Locked',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter your 4-digit PIN to access your workspace',
                  style: TextStyle(color: isDark ? Colors.white60 : Colors.grey.shade600, fontSize: 13),
                ),
                const SizedBox(height: 28),

                // PIN Dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (index) {
                    final isFilled = index < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isFilled ? colorScheme.primary : colorScheme.primary.withValues(alpha: 0.15),
                        border: Border.all(
                          color: isFilled ? colorScheme.primary : colorScheme.primary.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                    );
                  }),
                ),

                if (_errorMessage != null) ...[
                  const SizedBox(height: 14),
                  Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                ],

                const SizedBox(height: 32),

                // Frosted Glass Keypad Grid
                GlassContainer(
                  padding: const EdgeInsets.all(20),
                  borderRadius: 28,
                  width: 290,
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 1.25,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: 12,
                    itemBuilder: (context, index) {
                      if (index == 9) return const SizedBox.shrink();
                      if (index == 10) return _buildKeypadButton('0', colorScheme);
                      if (index == 11) {
                        return IconButton(
                          onPressed: _onBackspace,
                          icon: const Icon(Icons.backspace_outlined, size: 22),
                        );
                      }
                      return _buildKeypadButton('${index + 1}', colorScheme);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(String digit, ColorScheme colorScheme) {
    return InkWell(
      onTap: () => _onKeyPress(digit),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: colorScheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: colorScheme.primary.withValues(alpha: 0.15)),
        ),
        child: Center(
          child: Text(
            digit,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
