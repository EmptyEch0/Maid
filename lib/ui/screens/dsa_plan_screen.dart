import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../engine/dsa_plan_seeder.dart';
import '../../providers/app_provider.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/animated_entry.dart';
import '../widgets/universal_reschedule_dialog.dart';

class DsaPlanScreen extends StatefulWidget {
  const DsaPlanScreen({super.key});

  @override
  State<DsaPlanScreen> createState() => _DsaPlanScreenState();
}

class _DsaPlanScreenState extends State<DsaPlanScreen> {
  int _selectedWeek = 1;
  late List<DsaDayPlan> _allPlans;
  bool _isSeeding = false;

  @override
  void initState() {
    super.initState();
    _allPlans = DsaPlanSeeder.generate90DayPlan();
  }

  void _seedPlanToApp() async {
    setState(() => _isSeeding = true);
    final provider = Provider.of<AppProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);

    await DsaPlanSeeder.seedToApp(provider);

    if (mounted) {
      setState(() => _isSeeding = false);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('🎉 90-Day DSA Plan successfully added to your Calendar & Notes!'),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final filteredPlans = _allPlans.where((p) => p.weekNumber == _selectedWeek).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.workspace_premium_rounded, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('90-Day DSA Master Plan'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.schedule_send_rounded),
            tooltip: 'Reschedule Anything',
            onPressed: () => UniversalRescheduleDialog.showUniversalPicker(context),
          ),
          IconButton(
            icon: _isSeeding
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.cloud_download_rounded),
            tooltip: 'Seed Plan to Calendar & Notes',
            onPressed: _isSeeding ? null : _seedPlanToApp,
          ),
        ],
      ),
      body: Column(
        children: [
          // Plan Header Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: GlassContainer(
              padding: const EdgeInsets.all(20),
              borderRadius: 24,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '90-DAY DSA PREPARATION PLAN',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.2,
                                color: colorScheme.primary,
                              ),
                            ),
                            Text(
                              'Aug 17, 2026 → Dec 18, 2026 (Mon-Fri)',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.white70 : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatChip(context, '90', 'Weekdays'),
                      _buildStatChip(context, '18', 'Weeks'),
                      _buildStatChip(context, '350+', 'Problems'),
                      _buildStatChip(context, 'Free', 'Weekends'),
                    ],
                  ),
                  const SizedBox(height: 14),
                  GlassButton(
                    onPressed: _isSeeding ? () {} : _seedPlanToApp,
                    icon: const Icon(Icons.event_available_rounded),
                    label: const Text('Add 90-Day Plan to Calendar & Notes'),
                  ),
                ],
              ),
            ),
          ),

          // Week Selector Bar
          SizedBox(
            height: 46,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 18,
              itemBuilder: (context, idx) {
                final weekNum = idx + 1;
                final isSelected = weekNum == _selectedWeek;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('Week $weekNum'),
                    selected: isSelected,
                    selectedColor: colorScheme.primary.withValues(alpha: 0.2),
                    onSelected: (_) {
                      setState(() => _selectedWeek = weekNum);
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 8),

          // Days List for Selected Week
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredPlans.length,
              itemBuilder: (context, idx) {
                final dayPlan = filteredPlans[idx];
                return AnimatedEntry(
                  index: idx,
                  child: _buildDayCard(context, dayPlan),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(BuildContext context, String value, String label) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDayCard(BuildContext context, DsaDayPlan plan) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Day Number & Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassPillBadge(
                label: 'Day ${plan.dayNumber}',
                color: colorScheme.primary,
              ),
              Row(
                children: [
                  Text(
                    plan.date,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.schedule_send_rounded, size: 18, color: Color(0xFF6366F1)),
                    tooltip: 'Reschedule DSA Topic',
                    onPressed: () => UniversalRescheduleDialog.showUniversalPicker(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),

          Text(
            plan.topic,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          // WATCH
          _buildSectionRow(context, Icons.ondemand_video_rounded, 'WATCH', plan.watch, Colors.blueAccent),
          const SizedBox(height: 8),

          // STUDY
          _buildSectionRow(context, Icons.menu_book_rounded, 'STUDY', plan.study, Colors.amber),
          const SizedBox(height: 8),

          // PRACTICE
          _buildSectionRow(context, Icons.code_rounded, 'PRACTICE', plan.practice, Colors.green),
          const SizedBox(height: 10),

          // Target Chip
          Align(
            alignment: Alignment.centerRight,
            child: GlassPillBadge(
              label: 'Target: ${plan.target}',
              color: colorScheme.tertiary,
              icon: Icons.track_changes_rounded,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionRow(BuildContext context, IconData icon, String label, String content, Color accentColor) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              style: theme.textTheme.bodyMedium,
              children: [
                TextSpan(
                  text: '$label: ',
                  style: TextStyle(fontWeight: FontWeight.bold, color: accentColor, fontSize: 13),
                ),
                TextSpan(text: content, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
