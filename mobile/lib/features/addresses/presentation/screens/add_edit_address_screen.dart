import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/models/address_model.dart';
import '../providers/address_provider.dart';
import '../../../../core/services/nominatim_service.dart';

class AddEditAddressScreen extends StatefulWidget {
  final AddressModel? addressToEdit; // If null, adding a new address

  const AddEditAddressScreen({super.key, this.addressToEdit});

  @override
  State<AddEditAddressScreen> createState() => _AddEditAddressScreenState();
}

class _AddEditAddressScreenState extends State<AddEditAddressScreen> {
  final _formKey = GlobalKey<FormState>();
  final NominatimService _nominatimService = NominatimService();

  late TextEditingController _labelController;
  late TextEditingController _phoneController;
  late TextEditingController _addressLineController;
  late TextEditingController _areaController;
  late TextEditingController _cityController;
  bool _isDefault = false;

  // Search state
  Timer? _debounce;
  bool _isSearching = false;
  List<Map<String, dynamic>> _locationOptions = [];

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(
      text: widget.addressToEdit?.label ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.addressToEdit?.phoneNumber ?? '',
    );
    _addressLineController = TextEditingController(
      text: widget.addressToEdit?.addressLine ?? '',
    );
    _areaController = TextEditingController(
      text: widget.addressToEdit?.area ?? '',
    );
    _cityController = TextEditingController(
      text: widget.addressToEdit?.city ?? '',
    );
    _isDefault = widget.addressToEdit?.isDefault ?? false;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _phoneController.dispose();
    _addressLineController.dispose();
    _areaController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    final newAddress = AddressModel(
      id: widget.addressToEdit?.id ?? 0,
      label: _labelController.text,
      phoneNumber: _phoneController.text,
      addressLine: _addressLineController.text,
      area: _areaController.text,
      city: _cityController.text,
      isDefault: _isDefault,
    );

    final provider = context.read<AddressProvider>();
    bool success;

    if (widget.addressToEdit == null) {
      success = await provider.addAddress(newAddress);
    } else {
      success = await provider.updateAddress(newAddress);
    }

    if (!mounted) return;

    if (success) {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to save address'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.addressToEdit != null;
    final isLoading = context.watch<AddressProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit Address' : 'Add New Address'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Label ---
                    TextFormField(
                      controller: _labelController,
                      decoration: const InputDecoration(
                        labelText: 'Label (e.g., Home, Office)',
                        prefixIcon: Icon(Icons.label_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // --- Phone ---
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // --- City ---
                    TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        prefixIcon: Icon(Icons.location_city),
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // --- Area (Autocomplete Search) ---
                    Autocomplete<Map<String, dynamic>>(
                      optionsBuilder:
                          (TextEditingValue textEditingValue) async {
                            if (textEditingValue.text.isEmpty) {
                              return const Iterable<
                                Map<String, dynamic>
                              >.empty();
                            }

                            // Handle debouncing
                            if (_debounce?.isActive ?? false)
                              _debounce!.cancel();

                            final completer =
                                Completer<Iterable<Map<String, dynamic>>>();

                            _debounce = Timer(
                              const Duration(milliseconds: 500),
                              () async {
                                setState(() => _isSearching = true);
                                try {
                                  _locationOptions = await _nominatimService
                                      .searchPlaces(textEditingValue.text);
                                  completer.complete(_locationOptions);
                                } catch (e) {
                                  completer.complete([]);
                                } finally {
                                  if (mounted)
                                    setState(() => _isSearching = false);
                                }
                              },
                            );

                            return completer.future;
                          },
                      displayStringForOption: (option) =>
                          option['display_name'] ?? '',
                      onSelected: (Map<String, dynamic> selection) {
                        final extractedCity = _nominatimService.extractCity(
                          selection,
                        );
                        final extractedArea = _nominatimService.extractArea(
                          selection,
                        );

                        // Attempt to populate the fields based on what Nominatim found
                        if (extractedCity.isNotEmpty) {
                          _cityController.text = extractedCity;
                        }
                        // If it doesn't have an area but the user searched for something, use the first part
                        if (extractedArea.isNotEmpty) {
                          _areaController.text = extractedArea;
                        } else {
                          // Fallback to the primary name returned
                          _areaController.text = (selection['name'] ?? '')
                              .toString();
                        }
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            // Keep our _areaController synced with typing so validation passes
                            // and they can save even if they don't explicitly pick an autocomplete result
                            controller.addListener(() {
                              if (controller.text != _areaController.text) {
                                _areaController.text = controller.text;
                              }
                            });

                            // Setup init value
                            if (controller.text.isEmpty &&
                                _areaController.text.isNotEmpty) {
                              controller.text = _areaController.text;
                            }

                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'Search Landmark / Area',
                                prefixIcon: const Icon(Icons.map_outlined),
                                suffixIcon: _isSearching
                                    ? const Padding(
                                        padding: EdgeInsets.all(12.0),
                                        child: SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      )
                                    : null,
                                border: const OutlineInputBorder(),
                                helperText:
                                    'Search anywhere (e.g., Jamuna Future Park)',
                              ),
                              validator: (value) =>
                                  value == null || value.isEmpty
                                  ? 'Required'
                                  : null,
                            );
                          },
                    ),
                    const SizedBox(height: 16),

                    // --- Full Address ---
                    TextFormField(
                      controller: _addressLineController,
                      decoration: const InputDecoration(
                        labelText:
                            'Detailed Address (House, Road, Block, etc.)',
                        prefixIcon: Icon(Icons.home_outlined),
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),

                    // --- Is Default ---
                    SwitchListTile(
                      title: const Text('Set as Default Address'),
                      value: _isDefault,
                      onChanged: (val) {
                        setState(() {
                          _isDefault = val;
                        });
                      },
                      contentPadding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 32),

                    // --- Save Button ---
                    ElevatedButton(
                      onPressed: _saveAddress,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: Text(
                        isEditing ? 'Save Changes' : 'Add Address',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
