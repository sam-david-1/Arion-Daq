import 'package:flutter/material.dart';
import '../theme/racing_theme.dart';

class TrackMapTab extends StatelessWidget {
  const TrackMapTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: RacingTheme.background,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.satellite_alt, size: 64, color: RacingTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              'GPS Module Not Connected',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(color: RacingTheme.textSecondary),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect Neo-6M and add LAT, LON columns to CSV',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
