import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        isDark: isDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF9FAFB);
    final borderColor = isDark
        ? const Color(0xFF3A3A3A)
        : const Color(0xFFE5E7EB);

    return InkWell(
      onTap: _showCountryPicker,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 52, // Match TextFormField height with contentPadding
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.selectedCountry.flag,
              style: const TextStyle(fontSize: 20),
            ),
            if (widget.showCountryName) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  widget.selectedCountry.name,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white : const Color(0xFF101828),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            if (widget.showDialCode) ...[
              const SizedBox(width: 6),
              Text(
                widget.selectedCountry.dialCode,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : const Color(0xFF101828),
                ),
              ),
            ],
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              color: isDark ? Colors.white70 : const Color(0xFF667085),
            ),
          ],
        ),
      ),
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final CountryCode selectedCountry;
  final ValueChanged<CountryCode> onCountrySelected;
  final bool isDark;

  const _CountryPickerSheet({
    required this.selectedCountry,
    required this.onCountrySelected,
    required this.isDark,
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
    final bgColor = widget.isDark ? const Color(0xFF1A1A1A) : Colors.white;
    final textColor = widget.isDark ? Colors.white : const Color(0xFF101828);
    final subtextColor = const Color(0xFF98A2B3);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.isDark
                  ? const Color(0xFF3A3A3A)
                  : const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: Row(
              children: [
                Text(
                  'Select Country',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: widget.isDark
                        ? Colors.white70
                        : const Color(0xFF667085),
                  ),
                ),
              ],
            ),
          ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: TextField(
              controller: _searchController,
              onChanged: _filterCountries,
              style: GoogleFonts.inter(fontSize: 15, color: textColor),
              decoration: InputDecoration(
                hintText: 'Search country or code',
                hintStyle: GoogleFonts.inter(fontSize: 15, color: subtextColor),
                prefixIcon: Icon(Icons.search, color: subtextColor),
                filled: true,
                fillColor: widget.isDark
                    ? const Color(0xFF2A2A2A)
                    : const Color(0xFFF9FAFB),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: widget.isDark
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: Color(0xFF007AFF),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Country list
          Expanded(
            child: _filteredCountries.isEmpty
                ? Center(
                    child: Text(
                      'No countries found',
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        color: subtextColor,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = _filteredCountries[index];
                      final isSelected =
                          country.code == widget.selectedCountry.code;

                      return Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => widget.onCountrySelected(country),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(
                                      0xFF007AFF,
                                    ).withValues(alpha: 0.1)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  country.flag,
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        country.name,
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: textColor,
                                        ),
                                      ),
                                      Text(
                                        country.code,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: subtextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  country.dialCode,
                                  style: GoogleFonts.inter(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: isSelected
                                        ? const Color(0xFF007AFF)
                                        : subtextColor,
                                  ),
                                ),
                                if (isSelected) ...[
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF007AFF),
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
