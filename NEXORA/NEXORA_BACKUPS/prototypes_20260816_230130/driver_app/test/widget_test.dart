import 'package:flutter_test/flutter_test.dart';
import 'package:nexora_driver/app.dart';

void main() {
  testWidgets('muestra el inicio del conductor', (tester) async {
    await tester.pumpWidget(const NexoraDriverApp());

    expect(find.text('Desconectado'), findsOneWidget);

    expect(find.text('Recargar créditos'), findsOneWidget);
  });
}
