import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_move/features/passenger/home/passenger_home_view.dart';

void main() {
  testWidgets('Viaje inmediato abre el formulario', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PassengerHomeView())),
    );

    final card = find.byKey(const ValueKey('immediate-ride-card'));

    expect(card, findsOneWidget);

    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('Solicitar viaje'), findsWidgets);
    expect(find.text('Precio ofrecido'), findsOneWidget);
    expect(find.text('Método de pago'), findsOneWidget);
  });
}
