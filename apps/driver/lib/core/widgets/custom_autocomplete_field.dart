import 'package:milow/core/constants/design_tokens.dart';

import 'package:flutter/material.dart';

class CustomAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hint;
  final IconData prefixIcon;
  final Future<Iterable<String>> Function(TextEditingValue)? optionsBuilder;
  final List<String>? options; // Simple list option
  final String? label;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final TextCapitalization textCapitalization;
  final void Function(String)? onSelected;
  final InputDecoration? decoration;
  final FormFieldValidator<String>? validator;

  const CustomAutocompleteField({
    required this.controller,
    required this.focusNode,
    required this.hint,
    required this.prefixIcon,
    this.optionsBuilder,
    this.options,
    this.label,
    this.suffixIcon,
    this.onSuffixTap,
    this.textCapitalization = TextCapitalization.sentences,
    this.onSelected,
    this.decoration,
    this.validator,
    super.key,
  }) : assert(
         optionsBuilder != null || options != null,
         'Either optionsBuilder or options must be provided',
       );

  @override
  State<CustomAutocompleteField> createState() =>
      _CustomAutocompleteFieldState();
}

class _CustomAutocompleteFieldState extends State<CustomAutocompleteField> {
  final LayerLink _layerLink = LayerLink();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return RawAutocomplete<String>(
          textEditingController: widget.controller,
          focusNode: widget.focusNode,
          onSelected: widget.onSelected,
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (widget.options != null) {
              if (textEditingValue.text.isEmpty) {
                return const Iterable<String>.empty();
              }
              return widget.options!.where((String option) {
                return option.toLowerCase().contains(
                  textEditingValue.text.toLowerCase(),
                );
              });
            }
            return widget.optionsBuilder!(textEditingValue);
          },
          fieldViewBuilder:
              (
                BuildContext context,
                TextEditingController fieldTextEditingController,
                FocusNode fieldFocusNode,
                VoidCallback onFieldSubmitted,
              ) {
                return CompositedTransformTarget(
                  link: _layerLink,
                  child: TextFormField(
                    controller: fieldTextEditingController,
                    focusNode: fieldFocusNode,
                    textCapitalization: widget.textCapitalization,
                    validator: widget.validator,
                    decoration:
                        widget.decoration ??
                        InputDecoration(
                          labelText: widget.label,
                          hintText: widget.hint,
                          prefixIcon: Icon(
                            widget.prefixIcon,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                          suffixIcon: widget.suffixIcon != null
                              ? IconButton(
                                  icon: Icon(
                                    widget.suffixIcon,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 20,
                                  ),
                                  onPressed: widget.onSuffixTap,
                                )
                              : null,
                        ),
                    onFieldSubmitted: (String value) {
                      onFieldSubmitted();
                    },
                  ),
                );
              },
          optionsViewBuilder:
              (
                BuildContext context,
                AutocompleteOnSelected<String> onSelected,
                Iterable<String> options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: CompositedTransformFollower(
                    link: _layerLink,
                    showWhenUnlinked: false,
                    offset: const Offset(
                      0.0,
                      56.0,
                    ), // Approximate height of TextField
                    child: Material(
                      elevation: 8.0,
                      color: context.tokens.surfaceContainer,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(12),
                      ),
                      child: Container(
                        width: constraints.maxWidth,
                        constraints: const BoxConstraints(maxHeight: 200),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final String option = options.elementAt(index);
                            return InkWell(
                              onTap: () {
                                onSelected(option);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16.0,
                                  vertical: 12.0,
                                ),
                                child: Text(
                                  option,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: context.tokens.textPrimary,
                                      ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                );
              },
        );
      },
    );
  }
}
