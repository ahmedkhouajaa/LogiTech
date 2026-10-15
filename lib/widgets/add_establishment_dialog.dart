import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/hr_establishment.dart';
import '../services/connectivity_service.dart';
import '../services/hr_establishment_service.dart';
import '../utils/constants.dart';
import '../utils/offline_action_helper.dart';

class AddEstablishmentDialog extends StatefulWidget {
  final String enterpriseId;
  final HrEstablishment? establishmentToEdit;
  final ValueChanged<HrEstablishment>? onEstablishmentCreated;

  const AddEstablishmentDialog({
    super.key,
    required this.enterpriseId,
    this.establishmentToEdit,
    this.onEstablishmentCreated,
  });

  static Future<HrEstablishment?> show(
    BuildContext context, {
    required String enterpriseId,
    HrEstablishment? establishmentToEdit,
    ValueChanged<HrEstablishment>? onEstablishmentCreated,
  }) {
    return showDialog<HrEstablishment>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddEstablishmentDialog(
        enterpriseId: enterpriseId,
        establishmentToEdit: establishmentToEdit,
        onEstablishmentCreated: onEstablishmentCreated,
      ),
    );
  }

  @override
  State<AddEstablishmentDialog> createState() => _AddEstablishmentDialogState();
}

class _AddEstablishmentDialogState extends State<AddEstablishmentDialog> {
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _regNumberCtrl;
  late final TextEditingController _searchAddressCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _addressSuiteCtrl;
  late final TextEditingController _postalCodeCtrl;
  late final TextEditingController _cityCtrl;

  bool _isSaving = false;
  bool _isSearching = false;
  List<Map<String, dynamic>> _searchResults = [];

  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    final edit = widget.establishmentToEdit;
    _nameCtrl = TextEditingController(text: edit?.name ?? '');
    _regNumberCtrl = TextEditingController(text: edit?.registrationNumber ?? '');
    _searchAddressCtrl = TextEditingController();
    _addressCtrl = TextEditingController(text: edit?.address ?? '');
    _addressSuiteCtrl = TextEditingController(text: edit?.addressSuite ?? '');
    _postalCodeCtrl = TextEditingController(text: edit?.postalCode ?? '');
    _cityCtrl = TextEditingController(
      text: edit != null && edit.city.isNotEmpty ? edit.city : 'Tunis',
    );

    if (edit?.latitude != null && edit?.longitude != null) {
      _lat = edit!.latitude;
      _lng = edit.longitude;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _regNumberCtrl.dispose();
    _searchAddressCtrl.dispose();
    _addressCtrl.dispose();
    _addressSuiteCtrl.dispose();
    _postalCodeCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchAddress(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=json&addressdetails=1&q=${Uri.encodeComponent(q)}&limit=5',
      );
      final resp = await http.get(url, headers: {'User-Agent': 'LogiTechPro/1.0'}).timeout(
        const Duration(seconds: 4),
      );

      if (resp.statusCode == 200) {
        final List data = jsonDecode(resp.body);
        if (mounted) {
          setState(() {
            _searchResults = data.map((item) {
              final addr = item['address'] as Map<String, dynamic>? ?? {};
              return {
                'display_name': item['display_name'] ?? '',
                'lat': double.tryParse(item['lat']?.toString() ?? ''),
                'lon': double.tryParse(item['lon']?.toString() ?? ''),
                'road': addr['road'] ?? addr['suburb'] ?? '',
                'city': addr['city'] ?? addr['town'] ?? addr['village'] ?? addr['state'] ?? '',
                'postcode': addr['postcode'] ?? '',
              };
            }).toList();
          });
        }
      }
    } catch (_) {
      _provideOfflineSuggestions(q);
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _provideOfflineSuggestions(String query) {
    final lower = query.toLowerCase();
    final defaults = [
      {'display_name': 'Tunis, Gouvernorat de Tunis, Tunisie', 'lat': 36.8065, 'lon': 10.1815, 'road': 'Avenue Habib Bourguiba', 'city': 'Tunis', 'postcode': '1000'},
      {'display_name': 'Centre Urbain Nord, Tunis, Tunisie', 'lat': 36.8450, 'lon': 10.1980, 'road': 'Centre Urbain Nord', 'city': 'Tunis', 'postcode': '1082'},
      {'display_name': 'Les Berges du Lac, Tunis, Tunisie', 'lat': 36.8340, 'lon': 10.2330, 'road': 'Rue du Lac Léman', 'city': 'Tunis', 'postcode': '1053'},
      {'display_name': 'Sousse Ville, Sousse, Tunisie', 'lat': 35.8256, 'lon': 10.63699, 'road': 'Boulevard 14 Janvier', 'city': 'Sousse', 'postcode': '4000'},
      {'display_name': 'Sfax Médina, Sfax, Tunisie', 'lat': 34.7406, 'lon': 10.7603, 'road': 'Avenue Habib Bourguiba', 'city': 'Sfax', 'postcode': '3000'},
      {'display_name': 'Ariana Centre, Ariana, Tunisie', 'lat': 36.8665, 'lon': 10.1956, 'road': 'Avenue Habib Bourguiba', 'city': 'Ariana', 'postcode': '2080'},
      {'display_name': 'La Marsa, Tunis, Tunisie', 'lat': 36.8782, 'lon': 10.3247, 'road': 'Avenue Habib Bourguiba', 'city': 'La Marsa', 'postcode': '2070'},
    ];

    final filtered = defaults.where((item) => (item['display_name'] as String).toLowerCase().contains(lower)).toList();
    setState(() {
      _searchResults = filtered.isNotEmpty ? filtered : defaults.take(3).toList();
    });
  }

  void _applySelectedAddress(Map<String, dynamic> item) {
    setState(() {
      _lat = item['lat'] as double?;
      _lng = item['lon'] as double?;
      if ((item['road'] as String).isNotEmpty) {
        _addressCtrl.text = item['road'] as String;
      } else {
        _addressCtrl.text = (item['display_name'] as String).split(',').first;
      }
      if ((item['city'] as String).isNotEmpty) {
        _cityCtrl.text = item['city'] as String;
      }
      if ((item['postcode'] as String).isNotEmpty) {
        _postalCodeCtrl.text = item['postcode'] as String;
      }
      _searchAddressCtrl.text = item['display_name'] as String;
      _searchResults.clear();
    });
  }

  Future<void> _onSave() async {
    if (!_formKey.currentState!.validate()) return;

    final isEdit = widget.establishmentToEdit != null;
    if (isEdit) {
      final allowed = await OfflineActionHelper.checkOnlineOrShowError(context);
      if (!allowed) return;
    }

    setState(() => _isSaving = true);
    try {
      final establishment = HrEstablishment(
        id: isEdit ? widget.establishmentToEdit!.id : '',
        enterpriseId: widget.enterpriseId,
        name: _nameCtrl.text.trim(),
        registrationNumber: _regNumberCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        addressSuite: _addressSuiteCtrl.text.trim(),
        postalCode: _postalCodeCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        latitude: _lat,
        longitude: _lng,
        geofenceRadius: widget.establishmentToEdit?.geofenceRadius ?? 0.0,
        isActive: widget.establishmentToEdit?.isActive ?? true,
        createdAt: widget.establishmentToEdit?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (isEdit) {
        await HrEstablishmentService.instance.updateEstablishment(establishment);
      } else {
        await HrEstablishmentService.instance.createEstablishment(establishment);
      }

      if (mounted) {
        final isOnline = ConnectivityService.instance.isOnline;
        if (!isEdit && !isOnline) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.cloud_off_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Établissement enregistré hors ligne - en attente de synchronisation'),
                  ),
                ],
              ),
              backgroundColor: AppColors.warning,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        widget.onEstablishmentCreated?.call(establishment);
        Navigator.of(context).pop(establishment);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 650;
    final isEdit = widget.establishmentToEdit != null;

    return Dialog(
      backgroundColor: Colors.white,
      insetPadding: isMobile
          ? const EdgeInsets.all(12)
          : const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: isMobile ? MediaQuery.of(context).size.height * 0.95 : 680,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Header: Back arrow & Title (Image 2) ────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 12, right: 20, top: 14, bottom: 12),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, size: 22, color: Color(0xFF0F172A)),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Retour',
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isEdit ? 'Modifier l\'établissement' : 'Nouvel établissement',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            // ─── Scrollable Form Body ─────────────────────────────────────────
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Section 1: INFORMATIONS ─────────────────────────────
                      _buildSectionHeader('INFORMATIONS'),
                      const SizedBox(height: 14),

                      _buildFieldLabel('Nom de l\'établissement', isRequired: true),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _nameCtrl,
                        hint: 'Ex. Agence Sousse',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Veuillez saisir le nom de l\'établissement'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      _buildFieldLabel('N° d\'immatriculation'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _regNumberCtrl,
                        hint: 'Ex. 1234567/M/A/M/001',
                      ),
                      const SizedBox(height: 24),

                      // ── Section 2: ADRESSE ──────────────────────────────────
                      _buildSectionHeader('ADRESSE'),
                      const SizedBox(height: 14),

                      _buildFieldLabel('Rechercher l\'adresse'),
                      const SizedBox(height: 6),
                      _buildSearchField(),
                      const SizedBox(height: 6),

                      // Caption note with icon
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline_rounded, size: 15, color: Colors.grey.shade500),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Sélectionnez une adresse pour remplir automatiquement les champs.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      _buildFieldLabel('Adresse', isRequired: true),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _addressCtrl,
                        hint: 'N° et nom de rue',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Veuillez saisir l\'adresse'
                            : null,
                      ),
                      const SizedBox(height: 16),

                      _buildFieldLabel('Adresse (suite)'),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _addressSuiteCtrl,
                        hint: 'Bâtiment, étage, BP...',
                      ),
                      const SizedBox(height: 16),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Code postal'),
                                const SizedBox(height: 6),
                                _buildTextField(
                                  controller: _postalCodeCtrl,
                                  hint: '1004',
                                  keyboardType: TextInputType.number,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildFieldLabel('Ville', isRequired: true),
                                const SizedBox(height: 6),
                                _buildTextField(
                                  controller: _cityCtrl,
                                  hint: 'Tunis',
                                  validator: (v) => (v == null || v.trim().isEmpty)
                                      ? 'Veuillez saisir la ville'
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),

            const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),

            // ─── Footer Action Bar ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0F172A),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    child: const Text(
                      'Annuler',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : Text(
                            isEdit ? 'Enregistrer' : 'Créer l\'établissement',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Section Header ────────────────────────────────────────────────────────
  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: Color(0xFF64748B),
        letterSpacing: 0.6,
      ),
    );
  }

  // ─── Field Label ───────────────────────────────────────────────────────────
  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B),
        ),
        children: [
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
        ],
      ),
    );
  }

  // ─── Form TextField ────────────────────────────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        filled: true,
        fillColor: Colors.white,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }

  // ─── Search Address Input ──────────────────────────────────────────────────
  Widget _buildSearchField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _searchAddressCtrl,
          onChanged: (val) {
            if (val.length > 2) {
              _searchAddress(val);
            } else {
              setState(() => _searchResults = []);
            }
          },
          style: const TextStyle(fontSize: 13.5, color: Color(0xFF0F172A)),
          decoration: InputDecoration(
            hintText: 'Tapez une adresse, une ville...',
            hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13.5),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            suffixIcon: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF94A3B8)),
                    onPressed: () => _searchAddress(_searchAddressCtrl.text),
                  ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
        if (_searchResults.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            constraints: const BoxConstraints(maxHeight: 180),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _searchResults.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, i) {
                final item = _searchResults[i];
                return ListTile(
                  dense: true,
                  leading: Icon(Icons.location_on_rounded, size: 18, color: AppColors.primary),
                  title: Text(
                    item['display_name'] ?? '',
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF0F172A)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _applySelectedAddress(item),
                );
              },
            ),
          ),
      ],
    );
  }
}
