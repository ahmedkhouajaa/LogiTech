const fs = require('fs');
const path = require('path');

const screensDir = 'd:/LogiTech/lib/screens';

// Fix receiving_vouchers_screen.dart AddSupplierReturn
let rvPath = path.join(screensDir, 'receiving_vouchers_screen.dart');
let rvContent = fs.readFileSync(rvPath, 'utf8');
if (!rvContent.includes('supplier_returns_event.dart')) {
    rvContent = rvContent.replace(
        "import '../blocs/supplier_returns/supplier_returns_bloc.dart';",
        "import '../blocs/supplier_returns/supplier_returns_bloc.dart';\nimport '../blocs/supplier_returns/supplier_returns_event.dart';"
    );
    fs.writeFileSync(rvPath, rvContent, 'utf8');
}

// Fix create_supplier_return_screen.dart
let createPath = path.join(screensDir, 'create_supplier_return_screen.dart');
let createContent = fs.readFileSync(createPath, 'utf8');

createContent = createContent.replace(/dateEmission/g, 'date');
createContent = createContent.replace(/SupplierId/g, 'supplierId');
createContent = createContent.replace(/SupplierReturnId/g, 'supplierReturnId');
createContent = createContent.replace(/returnNumber/g, 'number');
createContent = createContent.replace(/notes:/g, 'reason:');
createContent = createContent.replace(/conditions:/g, 'reason:');
createContent = createContent.replace(/\.reason/g, '.reason'); // already reason

fs.writeFileSync(createPath, createContent, 'utf8');

// Fix supplier_returns_screen.dart
let listPath = path.join(screensDir, 'supplier_returns_screen.dart');
let listContent = fs.readFileSync(listPath, 'utf8');

listContent = listContent.replace(/final notes = state\.reason;/g, 'final notes = state.returns;');
listContent = listContent.replace(/\.\.\.suppliers\.map/g, '...Suppliers.map');
listContent = listContent.replace(/_filterSupplierReturns/g, 'FilterSupplierReturns');

fs.writeFileSync(listPath, listContent, 'utf8');

// Add FilterSupplierReturns to supplier_returns_event.dart
let eventPath = 'd:/LogiTech/lib/blocs/supplier_returns/supplier_returns_event.dart';
let eventContent = fs.readFileSync(eventPath, 'utf8');
if (!eventContent.includes('FilterSupplierReturns')) {
    eventContent += `
class FilterSupplierReturns extends SupplierReturnsEvent {
  final String? FournisseurId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? status;

  const FilterSupplierReturns({
    this.FournisseurId,
    this.dateFrom,
    this.dateTo,
    this.status,
  });

  @override
  List<Object?> get props => [FournisseurId, dateFrom, dateTo, status];
}
`;
    fs.writeFileSync(eventPath, eventContent, 'utf8');
}

// Implement FilterSupplierReturns in bloc
let blocPath = 'd:/LogiTech/lib/blocs/supplier_returns/supplier_returns_bloc.dart';
let blocContent = fs.readFileSync(blocPath, 'utf8');
if (!blocContent.includes('_onFilterSupplierReturns')) {
    blocContent = blocContent.replace(
        'on<DeleteSupplierReturn>(_onDeleteSupplierReturn);',
        'on<DeleteSupplierReturn>(_onDeleteSupplierReturn);\n    on<FilterSupplierReturns>(_onFilterSupplierReturns);'
    );
    blocContent = blocContent.replace(
        '}\n}',
        `  Future<void> _onFilterSupplierReturns(FilterSupplierReturns event, Emitter<SupplierReturnsState> emit) async {
    emit(SupplierReturnsLoading());
    try {
      final returns = await dbHelper.getSupplierReturns();
      final filtered = returns.where((r) {
        if (event.FournisseurId != null && event.FournisseurId != 'all' && r.supplierId != event.FournisseurId) return false;
        if (event.status != null && event.status != 'all' && r.status != event.status) return false;
        if (event.dateFrom != null && r.date.isBefore(event.dateFrom!)) return false;
        if (event.dateTo != null && r.date.isAfter(event.dateTo!.add(const Duration(days: 1)))) return false;
        return true;
      }).toList();
      emit(SupplierReturnsLoaded(filtered));
    } catch (e) {
      emit(SupplierReturnsError(e.toString()));
    }
  }\n}\n`
    );
    fs.writeFileSync(blocPath, blocContent, 'utf8');
}
