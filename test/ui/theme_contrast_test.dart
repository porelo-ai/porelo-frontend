import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:porelo_frontend/src/ui/terminal_look.dart';
import 'package:porelo_frontend/src/ui/theme.dart';
import 'package:porelo_frontend/src/ui/tokens.dart';

/// Holds every colour the interface draws text or a mark in to the surface it is drawn on.
///
/// **A palette taken from a dark website reads on black and vanishes on white**: lime and amber that
/// glow on the ground they were picked for fall below any contrast on a light one. Each pair here is
/// one the frame really draws, and each is measured as WCAG 2 measures it.
void main() {
  for (final (name, theme) in <(String, ThemeData)>[('light', PoreloTheme.light), ('dark', PoreloTheme.dark)]) {
    group('the $name theme', () {
      final s = theme.colorScheme;
      final surfaces = <String, Color>{
        'surface': s.surface,
        'surfaceContainerLowest': s.surfaceContainerLowest,
        'surfaceContainerLow': s.surfaceContainerLow,
        'surfaceContainer': s.surfaceContainer,
        'surfaceContainerHigh': s.surfaceContainerHigh,
        'surfaceContainerHighest': s.surfaceContainerHighest,
      };

      test('has the brightness it is named for', () {
        expect(s.brightness, name == 'light' ? Brightness.light : Brightness.dark);
      });

      for (final (role, colour) in <(String, Color)>[
        ('onSurface', s.onSurface),
        ('onSurfaceVariant', s.onSurfaceVariant),
        ('primary', s.primary),
        ('secondary', s.secondary),
        ('tertiary', s.tertiary),
        ('error', s.error),
      ]) {
        test('$role reads as text on every surface', () {
          for (final MapEntry(key: where, value: ground) in surfaces.entries) {
            expect(
              _contrast(colour, ground),
              greaterThanOrEqualTo(4.5),
              reason: '$role ${_hex(colour)} on $where ${_hex(ground)}',
            );
          }
        });
      }

      for (final (role, text, ground) in <(String, Color, Color)>[
        ('onPrimary on primary', s.onPrimary, s.primary),
        ('onSecondary on secondary', s.onSecondary, s.secondary),
        ('onTertiary on tertiary', s.onTertiary, s.tertiary),
        ('onError on error', s.onError, s.error),
        ('onPrimaryContainer on primaryContainer', s.onPrimaryContainer, s.primaryContainer),
        ('onSecondaryContainer on secondaryContainer', s.onSecondaryContainer, s.secondaryContainer),
        ('onTertiaryContainer on tertiaryContainer', s.onTertiaryContainer, s.tertiaryContainer),
        ('onErrorContainer on errorContainer', s.onErrorContainer, s.errorContainer),
        ('onInverseSurface on inverseSurface', s.onInverseSurface, s.inverseSurface),
      ]) {
        test('$role reads as text', () {
          expect(_contrast(text, ground), greaterThanOrEqualTo(4.5), reason: '${_hex(text)} on ${_hex(ground)}');
        });
      }

      final states = StateColours.of(s);
      for (final (role, colour) in <(String, Color)>[
        ('outline', s.outline),
        ('the working state', states.working),
        ('the waiting state', states.waiting),
        ('the stopped state', states.stopped),
      ]) {
        test('$role stands out as a mark on every surface', () {
          for (final MapEntry(key: where, value: ground) in surfaces.entries) {
            expect(
              _contrast(colour, ground),
              greaterThanOrEqualTo(3),
              reason: '$role ${_hex(colour)} on $where ${_hex(ground)}',
            );
          }
        });
      }
    });
  }

  group('the terminal', () {
    final t = TerminalLook.theme;
    for (final (role, colour) in <(String, Color)>[
      ('its text', t.foreground),
      ('red', t.red),
      ('green', t.green),
      ('yellow', t.yellow),
      ('blue', t.blue),
      ('magenta', t.magenta),
      ('cyan', t.cyan),
      ('white', t.white),
      ('bright red', t.brightRed),
      ('bright green', t.brightGreen),
      ('bright yellow', t.brightYellow),
      ('bright blue', t.brightBlue),
      ('bright magenta', t.brightMagenta),
      ('bright cyan', t.brightCyan),
      ('bright white', t.brightWhite),
    ]) {
      test('$role reads on its background', () {
        expect(
          _contrast(colour, t.background),
          greaterThanOrEqualTo(4.5),
          reason: '$role ${_hex(colour)} on ${_hex(t.background)}',
        );
      });
    }
  });
}

/// The WCAG 2 contrast ratio of two opaque colours.
double _contrast(Color a, Color b) {
  final (la, lb) = (_luminance(a), _luminance(b));
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

double _luminance(Color c) {
  double channel(double v) => v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);
}

String _hex(Color c) => '#${(c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
