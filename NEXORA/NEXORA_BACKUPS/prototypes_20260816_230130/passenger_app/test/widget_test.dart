import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_passenger/app.dart';

void main() {
  testWidgets('muestra la pantalla principal del pasajero', (tester) async {
    await tester.pumpWidget(const NexoraPassengerApp());

    expect(find.text('¿A dónde vamos?'), findsOneWidget);

    expect(find.text('Viaje inmediato'), findsOneWidget);
  });
}
