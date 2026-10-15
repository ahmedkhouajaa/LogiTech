import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';

import '../blocs/employees/employees_bloc.dart';
import '../blocs/employees/employees_state.dart';
import '../blocs/enterprise/enterprise_bloc.dart';
import '../models/employee.dart';
import '../models/hr_document.dart';
import '../services/hr_document_service.dart';
import '../utils/constants.dart';
import '../utils/platform_utils.dart';
import '../services/connectivity_service.dart';
import '../utils/offline_action_helper.dart';

class AddHrDocumentDialog extends StatefulWidget {
  final VoidCallback? onDocumentAdded;

  const AddHrDocumentDialog({
    super.key,
    this.onDocumentAdded,
  });

  static Future<void> show(BuildContext context, {VoidCallback? onDocumentAdded}) {
    final isMobile = !PlatformUtils.isDesktop && !PlatformUtils.isWeb;
    if (isMobile) {
      return showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => AddHrDocumentDialog(onDocumentAdded: onDocumentAdded),
      );
    }
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: AddHrDocumentDialog(onDocumentAdded: onDocumentAdded),
      ),
    );
  }

  @override
  State<AddHrDocumentDialog> createState() => _AddHrDocumentDialogState();
}

class _AddHrDocumentDialogState extends State<AddHrDocumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleCtrl = TextEditingController();

  String? _selectedType;
  bool _typeHasError = false;

  // File
  String? _pickedFileName;
  int _pickedFileSize = 0;
  String? _pickedFileExtension;
  String? _pickedBase64;
  bool _fileHasError = false;

  // Shared With
  String _shareTargetType = 'Privé'; // 'Privé', 'Tout le personnel', 'Employé'
  String? _selectedEmployeeId;
  String? _selectedEmployeeName;

  bool _isSaving = false;

  final List<String> _documentTypes = [
    'Attestation',
    'Autre',
    'Déclaration',
    'Document RH',
    'Pièce d\'identité',
    'Contrat de travail',
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'webp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final size = file.size;

        // 10 MB limit
        if (size > 10 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Le fichier dépasse la taille maximale autorisée de 10 Mo.'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final bytes = file.bytes;
        String? base64Str;
        if (bytes != null) {
          base64Str = base64Encode(bytes);
        }

        setState(() {
          _pickedFileName = file.name;
          _pickedFileSize = size;
          _pickedFileExtension = file.extension ?? '';
          _pickedBase64 = base64Str;
          _fileHasError = false;
          if (_titleCtrl.text.trim().isEmpty) {
            // Suggest title from file name without extension
            final dotIdx = file.name.lastIndexOf('.');
            _titleCtrl.text = dotIdx > 0 ? file.name.substring(0, dotIdx) : file.name;
          }
        });
      }
    } catch (e) {
      debugPrint('[AddHrDocumentDialog] file pick error: $e');
    }
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _fileHasError = _pickedFileName == null;
      _typeHasError = _selectedType == null || _selectedType!.isEmpty;
    });

    final isTitleValid = _formKey.currentState?.validate() ?? false;

    if (!isTitleValid || _fileHasError || _typeHasError) {
      return;
    }

    final entState = context.read<EnterpriseBloc>().state;
    final enterpriseId = entState is EnterpriseLoaded ? (entState.currentEnterpriseId ?? '') : '';

    if (enterpriseId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Entreprise introuvable.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      String finalSharedWith = 'Privé';
      if (_shareTargetType == 'Tout le personnel') {
        finalSharedWith = 'Tout le personnel';
      } else if (_shareTargetType == 'Employé' && _selectedEmployeeName != null) {
        finalSharedWith = _selectedEmployeeName!;
      }

      final doc = HrDocument(
        id: const Uuid().v4(),
        enterpriseId: enterpriseId,
        title: _titleCtrl.text.trim(),
        type: _selectedType!,
        fileName: _pickedFileName!,
        fileSize: _pickedFileSize,
        fileExtension: _pickedFileExtension ?? '',
        fileBase64: _pickedBase64,
        createdAt: DateTime.now(),
        sharedWith: finalSharedWith,
        employeeId: _shareTargetType == 'Employé' ? _selectedEmployeeId : null,
      );

      await HrDocumentService.instance.addDocument(doc);

      if (mounted) {
        Navigator.of(context).pop();
        widget.onDocumentAdded?.call();
        final isOnline = ConnectivityService.instance.isOnline;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  isOnline ? Icons.check_circle_outline_rounded : Icons.cloud_off_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isOnline
                      ? 'Document ajouté avec succès !'
                      : 'Document ajouté hors ligne (en attente de synchronisation)',
                ),
              ],
            ),
            backgroundColor: isOnline ? const Color(0xFF10B981) : AppColors.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement : $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = !PlatformUtils.isDesktop && !PlatformUtils.isWeb;

    final content = Container(
      constraints: const BoxConstraints(maxWidth: 580),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: isMobile
            ? const BorderRadius.vertical(top: Radius.circular(24))
            : BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with back arrow & title
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Color(0xFF111827), size: 22),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 14),
                  const Text(
                    'Ajouter un document',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Field 1: Fichier *
              _buildFieldLabel('Fichier', isRequired: true),
              const SizedBox(height: 8),
              _buildUploadZone(),
              if (_fileHasError)
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Veuillez sélectionner un fichier',
                    style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                  ),
                ),

              const SizedBox(height: 20),

              // Field 2: Titre *
              _buildFieldLabel('Titre', isRequired: true),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  hintText: 'Ex: Attestation d\'hébergement',
                  hintStyle: const TextStyle(fontSize: 13.5, color: Color(0xFF9CA3AF)),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF1A56DB), width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFDC2626)),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Champ obligatoire';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // Field 3: Type de document *
              _buildFieldLabel('Type de document', isRequired: true),
              const SizedBox(height: 8),
              _buildTypeDropdown(),
              if (_typeHasError)
                const Padding(
                  padding: EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    'Champ obligatoire',
                    style: TextStyle(color: Color(0xFFDC2626), fontSize: 12),
                  ),
                ),

              const SizedBox(height: 20),

              // Field 4: Partagé avec
              _buildFieldLabel('Partagé avec', isRequired: false),
              const SizedBox(height: 8),
              _buildShareWithSelector(),

              const SizedBox(height: 28),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 16),

              // Bottom Actions: Annuler & Envoyer
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF111827),
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
                      textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    child: const Text('Annuler'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _isSaving ? null : _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 12),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text('Envoyer'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return content;
  }

  Widget _buildFieldLabel(String label, {required bool isRequired}) {
    return RichText(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13.5,
          color: Color(0xFF111827),
        ),
        children: [
          if (isRequired)
            const TextSpan(
              text: ' *',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUploadZone() {
    final hasFile = _pickedFileName != null;

    return InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(12),
      child: CustomPaint(
        painter: _DashedRectPainter(
          color: _fileHasError
              ? const Color(0xFFDC2626)
              : (hasFile ? const Color(0xFF1A56DB) : const Color(0xFFCBD5E1)),
          strokeWidth: 1.5,
          gap: 5.0,
          radius: 12,
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: hasFile
              ? Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _pickedFileExtension?.toLowerCase() == 'pdf'
                            ? Icons.picture_as_pdf_rounded
                            : Icons.image_rounded,
                        color: const Color(0xFF1A56DB),
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _pickedFileName!,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                              color: Color(0xFF1E293B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _formatSize(_pickedFileSize),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: Color(0xFF1A56DB)),
                      tooltip: 'Changer le fichier',
                      onPressed: _pickFile,
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFFEF4444)),
                      tooltip: 'Supprimer',
                      onPressed: () {
                        setState(() {
                          _pickedFileName = null;
                          _pickedFileSize = 0;
                          _pickedFileExtension = null;
                          _pickedBase64 = null;
                        });
                      },
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 40,
                      color: Color(0xFF94A3B8),
                    ),
                    SizedBox(height: 10),
                    Text(
                      'Choisir un fichier ou glissez-déposez vos fichiers',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Formats acceptés : PDF, PNG, JPEG, WEBP',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Taille max : 10 Mo',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTypeDropdown() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _typeHasError ? const Color(0xFFDC2626) : const Color(0xFFE2E8F0),
          width: _typeHasError ? 1.5 : 1.0,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedType,
          isExpanded: true,
          hint: const Text(
            'Sélectionner un type',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF9CA3AF)),
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF64748B)),
          items: _documentTypes.map((t) {
            return DropdownMenuItem<String>(
              value: t,
              child: Text(
                t,
                style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
              ),
            );
          }).toList(),
          onChanged: (val) {
            setState(() {
              _selectedType = val;
              _typeHasError = false;
            });
          },
        ),
      ),
    );
  }

  Widget _buildShareWithSelector() {
    return BlocBuilder<EmployeesBloc, EmployeesState>(
      builder: (context, empState) {
        final employees = empState is EmployeesLoaded ? empState.employees : <Employee>[];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildShareRadio('Privé'),
                const SizedBox(width: 8),
                _buildShareRadio('Tout le personnel'),
                const SizedBox(width: 8),
                _buildShareRadio('Employé'),
              ],
            ),
            if (_shareTargetType == 'Employé') ...[
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedEmployeeId,
                    isExpanded: true,
                    hint: const Text(
                      'Sélectionner le collaborateur',
                      style: TextStyle(fontSize: 13.5, color: Color(0xFF9CA3AF)),
                    ),
                    items: employees.map((e) {
                      return DropdownMenuItem<String>(
                        value: e.id,
                        child: Text(
                          e.fullName,
                          style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E293B)),
                        ),
                      );
                    }).toList(),
                    onChanged: (empId) {
                      if (empId != null) {
                        final emp = employees.firstWhere((e) => e.id == empId);
                        setState(() {
                          _selectedEmployeeId = empId;
                          _selectedEmployeeName = emp.fullName;
                        });
                      }
                    },
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildShareRadio(String type) {
    final isSelected = _shareTargetType == type;
    return InkWell(
      onTap: () {
        setState(() {
          _shareTargetType = type;
        });
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF1A56DB) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 16,
              color: isSelected ? const Color(0xFF1A56DB) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 6),
            Text(
              type,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? const Color(0xFF1A56DB) : const Color(0xFF475569),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }
}

/// Custom painter for dashed rectangle borders
class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;

  _DashedRectPainter({
    required this.color,
    this.strokeWidth = 1.5,
    this.gap = 5.0,
    this.radius = 12.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint dashedPaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final RRect rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Radius.circular(radius),
    );

    final Path path = Path()..addRRect(rrect);
    final Path dashedPath = _buildDashedPath(path, dashWidth: gap, dashSpace: gap);
    canvas.drawPath(dashedPath, dashedPaint);
  }

  Path _buildDashedPath(Path source, {required double dashWidth, required double dashSpace}) {
    final Path dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0.0;
      bool draw = true;
      while (distance < metric.length) {
        final double len = draw ? dashWidth : dashSpace;
        if (distance + len > metric.length) {
          if (draw) {
            dest.addPath(metric.extractPath(distance, metric.length), Offset.zero);
          }
          break;
        }
        if (draw) {
          dest.addPath(metric.extractPath(distance, distance + len), Offset.zero);
        }
        distance += len;
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.gap != gap ||
        oldDelegate.radius != radius;
  }
}
