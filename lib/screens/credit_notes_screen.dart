import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../blocs/credit_notes/credit_notes_bloc.dart';
import '../models/credit_note.dart';
import '../utils/constants.dart';
import '../widgets/data_table_widget.dart';

class CreditNotesScreen extends StatefulWidget {
  const CreditNotesScreen({super.key});

  @override
  State<CreditNotesScreen> createState() => _CreditNotesScreenState();
}

class _CreditNotesScreenState extends State<CreditNotesScreen> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<CreditNotesBloc>().add(LoadCreditNotes());
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Avoirs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nouvel Avoir'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BlocBuilder<CreditNotesBloc, CreditNotesState>(
              builder: (context, state) {
                if (state is CreditNotesLoading) {
                  return const Center(child: CircularProgressIndicator());
                } else if (state is CreditNotesLoaded) {
                  return _buildTable(state.creditNotes);
                } else if (state is CreditNotesError) {
                  return Center(child: Text(state.message, style: const TextStyle(color: AppColors.error)));
                }
                return const SizedBox();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(List<CreditNote> notes) {
    if (notes.isEmpty) {
      return const Center(child: Text('Aucun avoir trouvé', style: TextStyle(color: AppColors.textSecondary)));
    }

    return DataTableWidget<CreditNote>(
      columns: const ['Référence', 'Client', 'Date', 'Statut', 'Montant TTC'],
      rows: notes,
      cellBuilder: (note) => _buildRowCells(note),
      onDelete: (note) {
        context.read<CreditNotesBloc>().add(DeleteCreditNote(note.id));
      },
    );
  }

  List<DataCell> _buildRowCells(CreditNote note) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    
    Color statusColor;
    switch (note.status) {
      case CreditNoteStatus.unused:
        statusColor = AppColors.primary;
        break;
      case CreditNoteStatus.partiallyUsed:
        statusColor = AppColors.warning;
        break;
      case CreditNoteStatus.used:
        statusColor = AppColors.success;
        break;
      case CreditNoteStatus.cancelled:
        statusColor = AppColors.error;
        break;
    }

    return [
      DataCell(Text(note.number, style: const TextStyle(fontWeight: FontWeight.w600))),
      DataCell(Text(note.customerName ?? note.customerId)),
      DataCell(Text(dateFormat.format(note.date))),
      DataCell(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(note.status.label, style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w500)),
        ),
      ),
      DataCell(Text('${note.totalTTC.toStringAsFixed(3)} TND', style: const TextStyle(fontWeight: FontWeight.bold))),
    ];
  }
}
