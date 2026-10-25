import 'package:flutter/material.dart';

/// Una sección del día con título, chips y un botón para agregar.
class ChipSection extends StatelessWidget {
  const ChipSection({
    super.key,
    required this.icon,
    required this.title,
    required this.chips,
    required this.addLabel,
    required this.onAdd,
    this.inlineInput,
  });

  final IconData icon;
  final String title;
  final List<Widget> chips;
  final String addLabel;
  final VoidCallback onAdd;

  /// En pantallas anchas se agrega con un campo en línea en vez del botón.
  final Widget? inlineInput;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(icon: icon, title: title),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            ...chips,
            inlineInput ??
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text(addLabel),
                  onPressed: onAdd,
                ),
          ],
        ),
      ],
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.icon, required this.title, this.trailing});

  final IconData icon;
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall!.copyWith(color: scheme.onSurface),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// Campo para agregar ítems en línea con autocompletado (pantallas anchas).
/// Enter agrega lo escrito; elegir una sugerencia la agrega tal cual.
class InlineAddField extends StatefulWidget {
  const InlineAddField({
    super.key,
    required this.hint,
    required this.optionsFor,
    required this.onAdd,
    this.width = 240,
  });

  final String hint;
  final List<String> Function(String query) optionsFor;
  final ValueChanged<String> onAdd;
  final double width;

  @override
  State<InlineAddField> createState() => _InlineAddFieldState();
}

class _InlineAddFieldState extends State<InlineAddField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _add(String text) {
    if (text.trim().isEmpty) return;
    widget.onAdd(text.trim());
    _controller.clear();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: RawAutocomplete<String>(
        textEditingController: _controller,
        focusNode: _focus,
        optionsBuilder: (value) => widget.optionsFor(value.text),
        onSelected: _add,
        fieldViewBuilder: (context, controller, focusNode, _) => TextField(
          controller: controller,
          focusNode: focusNode,
          onSubmitted: _add,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            isDense: true,
            hintText: widget.hint,
            prefixIcon: const Icon(Icons.add, size: 18),
            prefixIconConstraints: const BoxConstraints(minWidth: 36),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        optionsViewBuilder: (context, onSelected, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 3,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 240, maxWidth: widget.width),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final (i, option) in options.indexed)
                    Builder(builder: (context) {
                      final highlighted = AutocompleteHighlightedOption.of(context) == i;
                      return ListTile(
                        dense: true,
                        selected: highlighted,
                        title: Text(option),
                        onTap: () => onSelected(option),
                      );
                    }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
