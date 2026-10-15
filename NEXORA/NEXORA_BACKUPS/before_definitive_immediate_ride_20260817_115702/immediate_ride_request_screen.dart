import 'package:flutter/material.dart';
import 'package:nexora_ui/nexora_ui.dart';

class ImmediateRideRequestScreen extends StatefulWidget {
  const ImmediateRideRequestScreen({super.key});

  @override
  State<ImmediateRideRequestScreen> createState() =>
      _ImmediateRideRequestScreenState();
}

class _ImmediateRideRequestScreenState
    extends State<ImmediateRideRequestScreen> {
  final _originController = TextEditingController(text: 'Mi ubicación actual');

  final _destinationController = TextEditingController();

  final _priceController = TextEditingController();

  final _notesController = TextEditingController();

  String _paymentMethod = 'Efectivo';

  bool _submitting = false;

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _requestRide() async {
    final destination = _destinationController.text.trim();

    final price = double.tryParse(
      _priceController.text.replaceAll(',', '.').trim(),
    );

    if (destination.isEmpty) {
      _showMessage('Ingresa tu destino.');
      return;
    }

    if (price == null || price <= 0) {
      _showMessage('Ingresa un precio válido.');
      return;
    }

    setState(() {
      _submitting = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 700));

    if (!mounted) {
      return;
    }

    setState(() {
      _submitting = false;
    });

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return _RideSummarySheet(
          origin: _originController.text.trim(),
          destination: destination,
          price: price,
          paymentMethod: _paymentMethod,
          notes: _notesController.text.trim(),
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: NexoraColors.lightGray,
      appBar: AppBar(
        title: const Text('Solicitar viaje'),
        backgroundColor: NexoraColors.lightGray,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Viaje inmediato',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: NexoraColors.deepBlue,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Indica tu destino y cuánto deseas ofrecer por el viaje.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: NexoraColors.mutedText,
                ),
              ),
              const SizedBox(height: 24),

              TextField(
                controller: _originController,
                decoration: const InputDecoration(
                  labelText: 'Origen',
                  prefixIcon: Icon(Icons.my_location_rounded),
                ),
              ),

              const SizedBox(height: 14),

              TextField(
                controller: _destinationController,
                decoration: const InputDecoration(
                  labelText: 'Destino',
                  hintText: '¿A dónde quieres ir?',
                  prefixIcon: Icon(Icons.location_on_outlined),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Tu oferta',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: NexoraColors.deepBlue,
                ),
              ),

              const SizedBox(height: 10),

              TextField(
                controller: _priceController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Precio ofrecido',
                  hintText: 'Ej. 15.00',
                  prefixText: 'S/ ',
                  prefixIcon: Icon(Icons.payments_outlined),
                ),
              ),

              const SizedBox(height: 22),

              const Text(
                'Método de pago',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: NexoraColors.deepBlue,
                ),
              ),

              const SizedBox(height: 10),

              DropdownButtonFormField<String>(
                value: _paymentMethod,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                ),
                items: const [
                  DropdownMenuItem(value: 'Efectivo', child: Text('Efectivo')),
                  DropdownMenuItem(value: 'Yape', child: Text('Yape')),
                  DropdownMenuItem(value: 'Plin', child: Text('Plin')),
                  DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                ],
                onChanged: _submitting
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }

                        setState(() {
                          _paymentMethod = value;
                        });
                      },
              ),

              const SizedBox(height: 22),

              TextField(
                controller: _notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Nota para el conductor',
                  hintText: 'Ej. Estoy frente a la puerta principal.',
                  prefixIcon: Icon(Icons.chat_bubble_outline_rounded),
                ),
              ),

              const SizedBox(height: 28),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: NexoraColors.warmCream,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: NexoraColors.royalBlue,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Los conductores cercanos podrán aceptar tu oferta o proponerte otro precio.',
                        style: TextStyle(
                          height: 1.4,
                          color: NexoraColors.deepBlue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('request-immediate-ride'),
                  onPressed: _submitting ? null : _requestRide,
                  style: FilledButton.styleFrom(
                    backgroundColor: NexoraColors.royalBlue,
                    foregroundColor: NexoraColors.white,
                    minimumSize: const Size.fromHeight(58),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: NexoraColors.white,
                          ),
                        )
                      : const Text(
                          'Solicitar viaje',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RideSummarySheet extends StatelessWidget {
  const _RideSummarySheet({
    required this.origin,
    required this.destination,
    required this.price,
    required this.paymentMethod,
    required this.notes,
  });

  final String origin;
  final String destination;
  final double price;
  final String paymentMethod;
  final String notes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 48,
              height: 5,
              decoration: BoxDecoration(
                color: NexoraColors.mutedText.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 22),
          const Text(
            'Confirma tu solicitud',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: NexoraColors.deepBlue,
            ),
          ),
          const SizedBox(height: 20),

          _SummaryLine(
            icon: Icons.my_location_rounded,
            title: 'Origen',
            value: origin,
          ),

          _SummaryLine(
            icon: Icons.location_on_rounded,
            title: 'Destino',
            value: destination,
          ),

          _SummaryLine(
            icon: Icons.payments_outlined,
            title: 'Tu oferta',
            value: 'S/ ${price.toStringAsFixed(2)}',
          ),

          _SummaryLine(
            icon: Icons.account_balance_wallet_outlined,
            title: 'Pago',
            value: paymentMethod,
          ),

          if (notes.isNotEmpty)
            _SummaryLine(
              icon: Icons.notes_rounded,
              title: 'Nota',
              value: notes,
            ),

          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pop();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Solicitud preparada. En el siguiente paso la enviaremos a conductores conectados.',
                    ),
                  ),
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: NexoraColors.royalBlue,
                minimumSize: const Size.fromHeight(56),
              ),
              child: const Text(
                'Confirmar solicitud',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: NexoraColors.royalBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: NexoraColors.mutedText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: NexoraColors.deepBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
