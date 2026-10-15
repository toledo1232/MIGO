import 'package:flutter/material.dart';

class ImmediateRideRequestScreen extends StatefulWidget {
  const ImmediateRideRequestScreen({super.key});

  @override
  State<ImmediateRideRequestScreen> createState() =>
      _ImmediateRideRequestScreenState();
}

class _ImmediateRideRequestScreenState
    extends State<ImmediateRideRequestScreen> {
  final destination = TextEditingController();
  final price = TextEditingController();
  final notes = TextEditingController();
  String payment = 'Efectivo';

  @override
  void dispose() {
    destination.dispose();
    price.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Solicitar viaje')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Viaje inmediato',
            style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 20),
          const TextField(
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Origen',
              hintText: 'Mi ubicación actual',
              prefixIcon: Icon(Icons.my_location_rounded),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: destination,
            decoration: const InputDecoration(
              labelText: 'Destino',
              hintText: '¿A dónde quieres ir?',
              prefixIcon: Icon(Icons.location_on_outlined),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Precio ofrecido',
              prefixText: 'S/ ',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: payment,
            decoration: const InputDecoration(labelText: 'Método de pago'),
            items: const [
              DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
              DropdownMenuItem(value: 'Yape', child: Text('Yape')),
              DropdownMenuItem(value: 'Plin', child: Text('Plin')),
              DropdownMenuItem(value: 'Otro', child: Text('Otro')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() => payment = value);
              }
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: notes,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Nota para el conductor',
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            key: const ValueKey('submit-immediate-ride'),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Solicitud preparada')),
              );
            },
            child: const Text('Solicitar viaje'),
          ),
        ],
      ),
    );
  }
}
