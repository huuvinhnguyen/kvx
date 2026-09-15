import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum DurationUnit { seconds, minutes }

class RelayLonglastForm extends StatefulWidget {
  final void Function(Duration duration) onActivate;
  final bool enabled;

  const RelayLonglastForm({
    super.key,
    required this.onActivate,
    this.enabled = true,
  });

  @override
  State<RelayLonglastForm> createState() => _RelayLonglastFormState();
}

class _RelayLonglastFormState extends State<RelayLonglastForm> {
  final _controller = TextEditingController();
  DurationUnit _selectedUnit = DurationUnit.seconds;
  String? _errorText;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleActivate() {
    setState(() => _errorText = null);

    final text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _errorText = 'Vui lòng nhập thời gian!');
      return;
    }

    final value = int.tryParse(text);
    if (value == null || value <= 0) {
      setState(() => _errorText = 'Thời gian phải là số nguyên dương!');
      return;
    }

    final duration = _selectedUnit == DurationUnit.minutes
        ? Duration(minutes: value)
        : Duration(seconds: value);

    widget.onActivate(duration);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).dividerColor,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(12),
        color: Theme.of(context).colorScheme.surface,
      ),
      padding: const EdgeInsets.all(30),
      margin: const EdgeInsets.only(top: 30),
      child: Column(
        children: [
          TextField(
            controller: _controller,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(fontSize: 24),
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              hintText: 'Nhập thời gian...',
              errorText: _errorText,
              border: const OutlineInputBorder(),
              contentPadding: const EdgeInsets.all(15),
            ),
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<DurationUnit>(
            initialValue: _selectedUnit,
            isExpanded: true,
            style: const TextStyle(fontSize: 24),
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.all(15),
            ),
            items: const [
              DropdownMenuItem(
                value: DurationUnit.seconds,
                child: Center(child: Text('Giây')),
              ),
              DropdownMenuItem(
                value: DurationUnit.minutes,
                child: Center(child: Text('Phút')),
              ),
            ],
            onChanged: widget.enabled
                ? (value) => setState(() => _selectedUnit = value!)
                : null,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: widget.enabled ? _handleActivate : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 30),
                textStyle: const TextStyle(fontSize: 28),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('KÍCH HOẠT'),
            ),
          ),
        ],
      ),
    );
  }
}
