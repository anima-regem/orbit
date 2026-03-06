import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/orbit_analytics_facade.dart';
import '../onboarding/setup_flow_screen.dart';
import 'advanced/orbit_advanced_settings_section.dart';
import 'basic/orbit_basic_settings_section.dart';

enum _SettingsPane { basic, advanced }

class OrbitSettingsScreen extends ConsumerStatefulWidget {
  const OrbitSettingsScreen({super.key});

  @override
  ConsumerState<OrbitSettingsScreen> createState() =>
      _OrbitSettingsScreenState();
}

class _OrbitSettingsScreenState extends ConsumerState<OrbitSettingsScreen> {
  _SettingsPane _pane = _SettingsPane.basic;
  bool _advancedTracked = false;

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (_pane) {
      _SettingsPane.basic => const OrbitBasicSettingsSection(),
      _SettingsPane.advanced => OrbitAdvancedSettingsSection(
        onReRunSetup: _openSetupWizard,
      ),
    };

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
          child: Row(
            children: <Widget>[
              Expanded(
                child: SegmentedButton<_SettingsPane>(
                  showSelectedIcon: false,
                  segments: const <ButtonSegment<_SettingsPane>>[
                    ButtonSegment<_SettingsPane>(
                      value: _SettingsPane.basic,
                      label: Text('Basic'),
                      icon: Icon(Icons.tune_rounded),
                    ),
                    ButtonSegment<_SettingsPane>(
                      value: _SettingsPane.advanced,
                      label: Text('Advanced'),
                      icon: Icon(Icons.science_rounded),
                    ),
                  ],
                  selected: <_SettingsPane>{_pane},
                  onSelectionChanged: (Set<_SettingsPane> next) {
                    if (next.isEmpty) {
                      return;
                    }
                    final _SettingsPane value = next.first;
                    setState(() {
                      _pane = value;
                    });
                    if (value == _SettingsPane.advanced && !_advancedTracked) {
                      _advancedTracked = true;
                      unawaited(
                        ref
                            .read(orbitAnalyticsFacadeProvider)
                            .track('advanced_settings_opened'),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeOutCubic,
            child: KeyedSubtree(
              key: ValueKey<_SettingsPane>(_pane),
              child: body,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _openSetupWizard() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const SetupFlowScreen(),
        fullscreenDialog: true,
      ),
    );
  }
}
