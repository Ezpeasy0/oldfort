import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/settings/settings_controller.dart';
import '../../../core/widgets/app_widgets.dart';

const double _maxExtraScale = 0.5; // 100% = 1.0 + 0.5 = x1.5

int _scaleToPercent(double scale) =>
    (((scale - 1.0) / _maxExtraScale) * 100).round().clamp(0, 100).toInt();

double _percentToScale(int percent) => 1.0 + (percent / 100) * _maxExtraScale;

class DisplaySettingsPage extends ConsumerWidget {
  const DisplaySettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final settings = ref.watch(settingsProvider);
    final controller = ref.read(settingsProvider.notifier);
    final percent = _scaleToPercent(settings.textScale);

    void setPercent(int value) =>
        controller.setTextScale(_percentToScale(value.clamp(0, 100).toInt()));

    final labelStyle = TextStyle(fontSize: 20, color: scheme.tertiary);
    final smallStyle = TextStyle(fontSize: 16, color: scheme.onSurfaceVariant);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const BackTextButton(),
            const PageTitle('ปรับขนาดตัวอักษร\nและธีม'),
            const SizedBox(height: 32),
            Text('ขนาดตัวอักษร', style: labelStyle),
            const SizedBox(height: 12),
            Row(
              children: [
                _RoundIconButton(
                  icon: Icons.remove,
                  tooltip: 'เล็กลง',
                  onPressed: percent > 0 ? () => setPercent(percent - 10) : null,
                ),
                Expanded(
                  child: Slider(
                    value: percent.toDouble(),
                    min: 0,
                    max: 100,
                    divisions: 10,
                    label: '$percent%',
                    activeColor: scheme.primary,
                    onChanged: (value) => setPercent(value.round()),
                  ),
                ),
                _RoundIconButton(
                  icon: Icons.add,
                  tooltip: 'ใหญ่ขึ้น',
                  onPressed:
                      percent < 100 ? () => setPercent(percent + 10) : null,
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('0%', style: smallStyle),
                  Text(
                    '$percent%',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text('100%', style: smallStyle),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'ตัวอย่าง: สวัสดีครับ ยินดีต้อนรับสู่ Oldfort',
                style: TextStyle(fontSize: 18),
              ),
            ),
            const SizedBox(height: 32),
            Text('ธีม', style: labelStyle),
            const SizedBox(height: 12),
            SegmentedTabs(
              labels: const ['โหมดสว่าง', 'โหมดมืด'],
              selectedIndex: settings.themeMode == ThemeMode.dark ? 1 : 0,
              onChanged: (index) => controller
                  .setThemeMode(index == 1 ? ThemeMode.dark : ThemeMode.light),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IconButton.filledTonal(
      tooltip: tooltip,
      iconSize: 28,
      style: IconButton.styleFrom(
        backgroundColor: scheme.surfaceContainerHighest,
        foregroundColor: scheme.onSurface,
        minimumSize: const Size(52, 52),
      ),
      onPressed: onPressed,
      icon: Icon(icon),
    );
  }
}