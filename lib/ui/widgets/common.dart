import 'package:flutter/material.dart';

import '../theme.dart';

/// The streak, warm when today is already solved.
class StreakPill extends StatelessWidget {
  const StreakPill({super.key, required this.days, required this.safe});
  final int days;
  final bool safe;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '$days day streak${safe ? ', solved today' : ''}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: safe ? p.accent : p.sunken, borderRadius: BorderRadius.circular(20)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_fire_department_rounded, size: 20, color: safe ? const Color(0xFFB4441C) : p.inkFaint),
            const SizedBox(width: 4),
            Text(
              '$days',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 16,
                color: safe ? const Color(0xFF1C1B19) : p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A figure with its label, in a soft card.
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.rule),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: p.inkSoft),
            const SizedBox(height: 8),
            FittedBox(child: Text(value, style: Theme.of(context).textTheme.titleLarge)),
            Text(
              label,
              style: TextStyle(color: p.inkSoft, fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

/// A page title for the tab screens.
class PageTitle extends StatelessWidget {
  const PageTitle(this.text, {super.key, this.trailing});
  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
    child: Row(
      children: [
        Expanded(child: Text(text, style: Theme.of(context).textTheme.headlineMedium)),
        ?trailing,
      ],
    ),
  );
}

/// A centred message for an empty or unreachable list.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: p.inkFaint),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            body,
            style: TextStyle(color: p.inkSoft),
            textAlign: TextAlign.center,
          ),
          if (action != null) Padding(padding: const EdgeInsets.only(top: 12), child: action),
        ],
      ),
    );
  }
}
