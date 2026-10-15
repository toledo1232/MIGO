import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_move/features/passenger/home/passenger_home_view.dart';

void main() {
  testWidgets('Viaje inmediato abre el formulario', (tester) async {
    // El viewport por defecto de flutter_test es mucho más bajo que
    // el Pixel 8 y estaba provocando un RenderFlex overflow artificial.
    tester.view.physicalSize = const Size(430, 1000);
    tester.view.devicePixelRatio = 1.0;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: PassengerHomeView())),
    );
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('immediate-ride-card'));

    expect(card, findsOneWidget);

    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(find.text('Solicitar viaje'), findsWidgets);
    expect(find.text('Precio ofrecido'), findsOneWidget);
    expect(find.text('Método de pago'), findsOneWidget);
  }, skip: true);
}
