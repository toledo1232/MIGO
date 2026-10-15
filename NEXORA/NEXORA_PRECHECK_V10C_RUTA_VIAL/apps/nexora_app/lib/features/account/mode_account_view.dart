import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:nexora_ui/nexora_ui.dart';

import '../../app/app_session.dart';

class ModeAccountView extends StatelessWidget {
  const ModeAccountView({
    required this.session,
    required this.onSwitchMode,
    super.key,
  });

  final AppSession session;
  final ValueChanged<AppMode> onSwitchMode;

  Future<void> _pickPhoto(BuildContext context, {required bool driver}) async {
    final picker = ImagePicker();

    final image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
      maxWidth: 640,
      maxHeight: 640,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();

    if (bytes.isEmpty) {
      return;
    }

    final encoded = base64Encode(bytes);

    try {
      if (driver) {
        await session.setDriverPhoto(encoded);
      } else {
        await session.setPassengerPhoto(encoded);
      }
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la foto de forma permanente.'),
        ),
      );
      return;
    }

    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          driver
              ? 'Foto del conductor guardada permanentemente.'
              : 'Foto del pasajero guardada permanentemente.',
        ),
      ),
    );
  }

  Widget _avatar({required String? base64Photo, required String name}) {
    if (base64Photo != null && base64Photo.isNotEmpty) {
      try {
        final bytes = base64Decode(base64Photo);

        return CircleAvatar(
          radius: 34,
          backgroundColor: NexoraColors.breezeBlue,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {
        // Si la imagen local está dañada, mostramos iniciales.
      }
    }

    final trimmed = name.trim();
    final initial = trimmed.isEmpty
        ? '?'
        : trimmed.substring(0, 1).toUpperCase();

    return CircleAvatar(
      radius: 34,
      backgroundColor: NexoraColors.deepBlue,
      child: Text(
        initial,
        style: const TextStyle(
          color: NexoraColors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final passengerMode = session.mode == AppMode.passenger;

    final profileName = passengerMode
        ? session.passengerName
        : session.driverName;

    final profilePhoto = passengerMode
        ? session.passengerPhotoBase64
        : session.driverPhotoBase64;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mi cuenta',
            style: TextStyle(
              color: NexoraColors.deepBlue,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: NexoraColors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: NexoraColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    _avatar(base64Photo: profilePhoto, name: profileName),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profileName,
                            style: const TextStyle(
                              color: NexoraColors.deepBlue,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            passengerMode
                                ? 'Foto opcional para pasajeros'
                                : session.hasDriverPhoto
                                ? 'Foto de conductor configurada'
                                : 'Foto obligatoria para recibir viajes',
                            style: TextStyle(
                              color: passengerMode || session.hasDriverPhoto
                                  ? NexoraColors.turquoise
                                  : Colors.redAccent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () => _pickPhoto(context, driver: !passengerMode),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: Text(
                    profilePhoto == null ? 'Agregar foto' : 'Cambiar foto',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: NexoraColors.deepBlue,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  passengerMode
                      ? Icons.local_taxi_rounded
                      : Icons.person_pin_circle_rounded,
                  color: NexoraColors.turquoise,
                  size: 36,
                ),
                const SizedBox(height: 14),
                Text(
                  passengerMode ? 'Modo conductor' : 'Modo pasajero',
                  style: const TextStyle(
                    color: NexoraColors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  passengerMode
                      ? 'Recibe solicitudes y genera ingresos '
                            'con tu misma cuenta MIGO.'
                      : 'Solicita viajes nuevamente con '
                            'tu misma cuenta.',
                  style: const TextStyle(color: Color(0xFFCBD5E1), height: 1.4),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () {
                    onSwitchMode(
                      passengerMode ? AppMode.driver : AppMode.passenger,
                    );
                  },
                  icon: const Icon(Icons.swap_horiz_rounded),
                  label: Text(
                    passengerMode
                        ? 'Cambiar a modo conductor'
                        : 'Cambiar a modo pasajero',
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
