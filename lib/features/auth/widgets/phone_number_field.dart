import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/webs_colors.dart';

/// A phone-number input with a country flag and country code.
///
/// The user taps the flag/code on the left to open a country
/// picker. The final E.164 number is built by the parent using
/// [PhoneNumberField.composeE164].
class PhoneNumberField extends StatefulWidget {
  /// Holds the *national* portion of the number (no country code).
  final TextEditingController controller;

  /// The initial country. Defaults to Tanzania when null.
  ///
  /// NOTE: this is nullable because [Country] has no const
  /// constructor, and default parameter values must be compile-
  /// time constants.
  final Country? initialCountry;

  /// Called whenever the selected country changes.
  final ValueChanged<Country>? onCountryChanged;

  /// Called whenever the phone-number text changes.
  final ValueChanged<String>? onChanged;

  /// Optional validator for the national portion.
  final String? Function(String?)? validator;

  final TextInputAction textInputAction;
  final bool enabled;

  const PhoneNumberField({
    super.key,
    required this.controller,
    this.initialCountry,
    this.onCountryChanged,
    this.onChanged,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.enabled = true,
  });

  /// Combines a country's phone code with the local number into
  /// a single E.164 string.
  ///
  /// Example: code "255" + local "712345678" → "+255712345678"
  static String composeE164({
    required String phoneCode,
    required String localNumber,
  }) {
    final digits = localNumber.replaceAll(RegExp(r'\D'), '');
    return '+$phoneCode$digits';
  }

  /// The default country — Tanzania.
  ///
  /// Constructed at runtime because [Country] is not a const
  /// class.
  static Country defaultCountry() => Country(
        phoneCode: '255',
        countryCode: 'TZ',
        e164Sc: 0,
        geographic: true,
        level: 1,
        name: 'Tanzania',
        example: '712345678',
        displayName: 'Tanzania',
        displayNameNoCountryCode: 'Tanzania',
        e164Key: '255-TZ-0',
      );

  @override
  State<PhoneNumberField> createState() => _PhoneNumberFieldState();
}

class _PhoneNumberFieldState extends State<PhoneNumberField> {
  late Country _country;

  @override
  void initState() {
    super.initState();
    _country = widget.initialCountry ?? PhoneNumberField.defaultCountry();
  }

  @override
  void didUpdateWidget(covariant PhoneNumberField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incoming = widget.initialCountry;
    if (incoming != null && incoming.phoneCode != _country.phoneCode) {
      _country = incoming;
    }
  }

  void _openCountryPicker() {
    showCountryPicker(
      context: context,
      showPhoneCode: true,
      countryListTheme: CountryListThemeData(
        flagSize: 24,
        backgroundColor: WebsColors.surface(context),
        textStyle: TextStyle(
          color: WebsColors.textDark(context),
        ),
        bottomSheetHeight: MediaQuery.of(context).size.height * 0.75,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        inputDecoration: InputDecoration(
          labelText: 'Search',
          labelStyle: TextStyle(
            color: WebsColors.textLight(context),
          ),
          hintText: 'Search country or code',
          hintStyle: TextStyle(
            color: WebsColors.textLight(context),
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: WebsColors.primaryGreen,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: WebsColors.softGreen(context),
        ),
      ),
      onSelect: (country) {
        setState(() => _country = country);
        widget.onCountryChanged?.call(country);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final flag = _country.flagEmoji;
    final code = '+${_country.phoneCode}';

    return TextFormField(
      controller: widget.controller,
      enabled: widget.enabled,
      keyboardType: TextInputType.phone,
      textInputAction: widget.textInputAction,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(15),
      ],
      style: TextStyle(color: WebsColors.textDark(context)),
      onChanged: widget.onChanged,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: 'Phone number',
        labelStyle: TextStyle(color: WebsColors.textLight(context)),
        hintText: _country.example,
        hintStyle: TextStyle(color: WebsColors.textLight(context)),

        // Tappable flag + code prefix.
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 4, right: 4),
          child: InkWell(
            onTap: widget.enabled ? _openCountryPicker : null,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    flag,
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    code,
                    style: TextStyle(
                      color: WebsColors.textDark(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 20,
                    color: WebsColors.textLight(context),
                  ),
                ],
              ),
            ),
          ),
        ),

        filled: true,
        fillColor: WebsColors.softGreen(context),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: WebsColors.primaryGreen,
            width: 2,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 2,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 2,
          ),
        ),
      ),
    );
  }
}