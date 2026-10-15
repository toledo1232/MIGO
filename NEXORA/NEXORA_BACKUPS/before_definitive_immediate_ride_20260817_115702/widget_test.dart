import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_move/features/passenger/ride_request/immediate_ride_request_screen.dart';

void main() {
  testWidgets('Viaje inmediato muestra el formulario', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: ImmediateRideRequestScreen()),
    );

    expect(find.text('Viaje inmediato'), findsOneWidget);

    expect(find.text('Origen'), findsOneWidget);

    expect(find.text('Destino'), findsOneWidget);

    expect(find.text('Tu oferta'), findsOneWidget);

    expect(find.text('Método de pago'), findsOneWidget);

    expect(find.text('Solicitar viaje'), findsOneWidget);
  });
}
