import 'package:flutter/material.dart';

import 'countries.dart';
import 'ui/vibe_design.dart';

/// Ölkə seçimi ekranı.
///
/// Yuxarıda populyar ölkələr, altında bütün siyahı; axtarış həm ada,
/// həm koda görə işləyir.
Future<Country?> pickCountry(BuildContext context, {String? selectedCode}) {
  return showModalBottomSheet<Country>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheet) => _CountryPicker(selectedCode: selectedCode),
  );
}

class _CountryPicker extends StatefulWidget {
  const _CountryPicker({this.selectedCode});

  final String? selectedCode;

  @override
  State<_CountryPicker> createState() => _CountryPickerState();
}

class _CountryPickerState extends State<_CountryPicker> {
  final search = TextEditingController();
  String query = '';

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = searchCountries(query);
    final showPopular = query.trim().isEmpty;

    return Container(
      height: MediaQuery.sizeOf(context).height * .82,
      decoration: const BoxDecoration(
        color: vPanel,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        border: Border(top: BorderSide(color: vLine)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: vLine,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Ölkəni seç',
            style: TextStyle(
              color: vInk,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
            child: TextField(
              controller: search,
              onChanged: (value) => setState(() => query = value),
              style: const TextStyle(color: vInk),
              decoration: InputDecoration(
                hintText: 'Axtar…',
                hintStyle: const TextStyle(color: vMuted),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: vMuted, size: 20),
                filled: true,
                fillColor: vBg,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: vLine),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: vLine),
                ),
              ),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Text('Tapılmadı',
                        style: TextStyle(color: vMuted, fontSize: 13)),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
                    children: [
                      if (showPopular) ...[
                        _sectionTitle('POPULYAR'),
                        for (final country in popularCountries)
                          _row(country),
                        const SizedBox(height: 14),
                        _sectionTitle('BÜTÜN ÖLKƏLƏR'),
                      ],
                      for (final country in results) _row(country),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
        child: Text(
          text,
          style: const TextStyle(
            color: vMuted,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
          ),
        ),
      );

  Widget _row(Country country) {
    final selected = country.code == widget.selectedCode;

    return ListTile(
      onTap: () => Navigator.pop(context, country),
      dense: true,
      leading: Container(
        width: 40,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: vBg,
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: vLine),
        ),
        child: Text(
          country.flag,
          style: const TextStyle(fontSize: 17),
        ),
      ),
      title: Text(
        country.name,
        style: TextStyle(
          color: selected ? vPink : vInk,
          fontSize: 14.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_rounded, color: vPink, size: 18)
          : Text(
              country.code,
              style: const TextStyle(color: vMuted, fontSize: 12),
            ),
    );
  }
}
