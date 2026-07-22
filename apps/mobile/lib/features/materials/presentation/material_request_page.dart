import 'package:arte_in_ferro_rapportini/features/auth/domain/entities/app_user.dart';
import 'package:arte_in_ferro_rapportini/features/materials/data/material_service.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MaterialRequestPage extends StatefulWidget {
  const MaterialRequestPage({
    required this.user,
    this.reportId,
    super.key,
  });

  final AppUser user;
  final String? reportId;

  @override
  State<MaterialRequestPage> createState() => _MaterialRequestPageState();
}

class _MaterialRequestPageState extends State<MaterialRequestPage> {
  final _items = <MaterialDraftItem>[];
  final _notes = TextEditingController();
  String _category = 'materia_prima';
  bool _saving = false;

  MaterialService get _service => MaterialService(Supabase.instance.client);

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _addItem() async {
    final description = TextEditingController();
    final quantity = TextEditingController(text: '1');
    final unit = TextEditingController(text: _category == 'materia_prima' ? 'barre' : 'pz');
    final notes = TextEditingController();
    final key = GlobalKey<FormState>();
    final item = await showDialog<MaterialDraftItem>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(_category == 'materia_prima' ? 'Aggiungi materia prima' : 'Aggiungi materiale di consumo'),
        content: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: description,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Materiale *', hintText: 'Es. profilato 20x20, elettrodi, dischetti'),
                  validator: (value) => (value?.trim().length ?? 0) < 2 ? 'Inserisci il materiale' : null,
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: TextFormField(
                    controller: quantity,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Quantità *'),
                    validator: (value) {
                      final parsed = double.tryParse((value ?? '').replaceAll(',', '.'));
                      return parsed == null || parsed <= 0 ? 'Quantità non valida' : null;
                    },
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: TextFormField(controller: unit, decoration: const InputDecoration(labelText: 'Unità *'))),
                ]),
                const SizedBox(height: 10),
                TextFormField(controller: notes, decoration: const InputDecoration(labelText: 'Specifiche / note')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ANNULLA')),
          FilledButton(
            onPressed: () {
              if (!(key.currentState?.validate() ?? false)) return;
              Navigator.pop(dialogContext, MaterialDraftItem(
                description: description.text.trim(),
                quantity: double.parse(quantity.text.replaceAll(',', '.')),
                unit: unit.text.trim().isEmpty ? 'pz' : unit.text.trim(),
                notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
              ));
            },
            child: const Text('AGGIUNGI'),
          ),
        ],
      ),
    );
    description.dispose(); quantity.dispose(); unit.dispose(); notes.dispose();
    if (item != null && mounted) setState(() => _items.add(item));
  }

  Future<void> _send() async {
    if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Aggiungi almeno un materiale.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.createRequest(
        employeeId: widget.user.id,
        category: _category,
        items: _items,
        reportId: widget.reportId,
        notes: _notes.text,
      );
      if (!mounted) return;
      setState(() { _items.clear(); _notes.clear(); });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Richiesta materiali inviata all’ufficio.')));
    } on Object catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Invio non riuscito: $error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Richiesta materiali')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'materia_prima', label: Text('Materia prima'), icon: Icon(Icons.view_in_ar_outlined)),
                ButtonSegment(value: 'consumo', label: Text('Consumo'), icon: Icon(Icons.build_circle_outlined)),
              ],
              selected: {_category},
              onSelectionChanged: _saving ? null : (value) => setState(() { _category = value.first; _items.clear(); }),
            ),
            const SizedBox(height: 16),
            Text(
              _category == 'materia_prima'
                  ? 'Profilati, lamiere, barre e componenti di produzione'
                  : 'Elettrodi, dischetti, punte e altro materiale di consumo',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 14),
            if (_items.isEmpty)
              const Card(child: Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Nessun materiale inserito'))))
            else
              ..._items.indexed.map((entry) => Card(child: ListTile(
                    leading: CircleAvatar(child: Text(entry.$2.quantity.toStringAsFixed(entry.$2.quantity % 1 == 0 ? 0 : 1))),
                    title: Text(entry.$2.description),
                    subtitle: Text('${entry.$2.quantity.toStringAsFixed(entry.$2.quantity % 1 == 0 ? 0 : 2)} ${entry.$2.unit}${entry.$2.notes == null ? '' : ' · ${entry.$2.notes}'}'),
                    trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: _saving ? null : () => setState(() => _items.removeAt(entry.$1))),
                  ))),
            OutlinedButton.icon(onPressed: _saving ? null : _addItem, icon: const Icon(Icons.add), label: const Text('AGGIUNGI MATERIALE')),
            const SizedBox(height: 14),
            TextField(controller: _notes, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Note generali', alignLabelWithHint: true)),
            const SizedBox(height: 20),
            FilledButton.icon(onPressed: _saving ? null : _send, icon: const Icon(Icons.send_outlined), label: Text(_saving ? 'INVIO…' : 'INVIA ALL’UFFICIO')),
          ],
        ),
      ),
    );
  }
}
