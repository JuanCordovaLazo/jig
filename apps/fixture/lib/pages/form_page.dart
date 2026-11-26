import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../controllers.dart';
import '../insets.dart';

class FormPage extends StatefulWidget {
  const FormPage({super.key});

  @override
  State<FormPage> createState() => _FormPageState();
}

class _FormPageState extends State<FormPage> {
  final TextEditingController _name = TextEditingController();
  final RxBool _accepted = false.obs;
  final RxString _submitted = ''.obs;

  final FormController _form = Get.find<FormController>();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Form')),
      body: ListView(
        padding: pagePadding(context),
        children: <Widget>[
          TextField(
            key: const ValueKey<String>('name_field'),
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nombre',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => CheckboxListTile(
              key: const ValueKey<String>('terms_checkbox'),
              value: _accepted.value,
              title: const Text('Acepto los terminos'),
              onChanged: (value) => _accepted.value = value ?? false,
            ),
          ),
          Obx(
            () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('Calificacion ${_form.rating.value.round()}'),
                Slider(
                  key: const ValueKey<String>('rating_slider'),
                  value: _form.rating.value,
                  max: 5,
                  divisions: 5,
                  label: '${_form.rating.value.round()}',
                  onChanged: (value) => _form.rating.value = value,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const ValueKey<String>('submit'),
            onPressed: () {
              _submitted.value = '${_name.text}|'
                  '${_accepted.value}|${_form.rating.value.round()}';
            },
            child: const Text('Enviar'),
          ),
          const SizedBox(height: 16),
          Obx(
            () => Text(
              _submitted.value.isEmpty
                  ? 'Sin enviar'
                  : 'Enviado: ${_submitted.value}',
            ),
          ),
        ],
      ),
    );
  }
}
