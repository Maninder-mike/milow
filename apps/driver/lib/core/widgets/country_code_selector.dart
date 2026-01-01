import 'package:flutter/material.dart';

import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/models/country_code.dart';

class CountryCodeSelector extends StatefulWidget {
  final CountryCode selectedCountry;
  final ValueChanged<CountryCode> onCountryChanged;
  final bool showCountryName;
  final bool showDialCode;

  const CountryCodeSelector({
    required this.selectedCountry,
    required this.onCountryChanged,
    this.showCountryName = false,
    this.showDialCode = true,
    super.key,
  });

  @override
  State<CountryCodeSelector> createState() => _CountryCodeSelectorState();
}

class _CountryCodeSelectorState extends State<CountryCodeSelector> {
  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CountryPickerSheet(
        selectedCountry: widget.selectedCountry,
        onCountrySelected: (country) {
          widget.onCountryChanged(country);
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return InkWell(
      onTap: _showCountryPicker,
      borderRadius: BorderRadius.circular(tokens.radiusS + 2),
      child: Container(
        height: 52, // Match TextFormField height with contentPadding
        padding: EdgeInsets.symmetric(
          horizontal: tokens.spacingM,
          vertical: tokens.spacingM - 2,
        ),
        decoration: BoxDecoration(
          color: tokens.inputBackground,
          borderRadius: BorderRadius.circular(tokens.radiusS + 2),
          border: Border.all(color: tokens.inputBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.selectedCountry.flag,
              style: const TextStyle(fontSize: 20),
            ),
            if (widget.showCountryName) ...[
              SizedBox(width: tokens.spacingS),
              Flexible(
                child: Text(
                  widget.selectedCountry.name,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: tokens.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (widget.showDialCode) ...[
              SizedBox(width: tokens.spacingXS + 2),
              Text(
                widget.selectedCountry.dialCode,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w500,
                  color: tokens.textPrimary,
                ),
              ),
            ],
            SizedBox(width: tokens.spacingXS),
            Icon(Icons.arrow_drop_down, color: tokens.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final CountryCode selectedCountry;
  final ValueChanged<CountryCode> onCountrySelected;

  const _CountryPickerSheet({
    required this.selectedCountry,
    required this.onCountrySelected,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<CountryCode> _filteredCountries = countryCodes;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterCountries(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = countryCodes;
      } else {
        final lowerQuery = query.toLowerCase();
        _filteredCountries = countryCodes.where((country) {
          return country.name.toLowerCase().contains(lowerQuery) ||
              country.dialCode.contains(lowerQuery) ||
              country.code.toLowerCase().contains(lowerQuery);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: tokens.surfaceContainer,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radiusL),
        ),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(
              top: tokens.radiusM,
              bottom: tokens.spacingS,
            ),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: tokens.subtleBorderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(
              tokens.spacingL,
              tokens.spacingM,
              tokens.spacingL,
              tokens.spacingM,
            ),
            child: Row(
              children: [
                Text(
                  'Select Country',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close_rounded, color: tokens.textSecondary),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: tokens.spacingL),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCountries,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: tokens.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search country or code',
                hintStyle: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: tokens.textTertiary),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: tokens.textTertiary,
                ),
                filled: true,
                fillColor: tokens.inputBackground,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: tokens.spacingM,
                  vertical: tokens.spacingM - 2,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusM),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusM),
                  borderSide: BorderSide(color: tokens.inputBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(tokens.radiusM),
                  borderSide: BorderSide(
                    color: tokens.inputFocusedBorder,
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: tokens.radiusM),

          // Country list
          Expanded(
            child: _filteredCountries.isEmpty
                ? Center(
                    child: Text(
                      'No countries found',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: tokens.textTertiary,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: tokens.spacingM),
                    itemCount: _filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = _filteredCountries[index];
                      final isSelected =
                          country.code == widget.selectedCountry.code;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onCountrySelected(country),
                          borderRadius: BorderRadius.circular(tokens.radiusM),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: tokens.spacingM,
                              vertical: tokens.radiusM,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primary.withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(
                                tokens.radiusM,
                              ),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  country.flag,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                SizedBox(width: tokens.radiusM),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        country.name,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              fontWeight: isSelected
                                                  ? FontWeight.w600
                                                  : FontWeight.w500,
                                              color: tokens.textPrimary,
                                            ),
                                      ),
                                      Text(
                                        country.code,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: tokens.textTertiary,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  country.dialCode,
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                            : tokens.textTertiary,
                                      ),
                                ),
                                if (isSelected) ...[
                                  SizedBox(width: tokens.spacingS),
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                    size: 20,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
