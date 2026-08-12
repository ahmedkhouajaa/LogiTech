import re

def process():
    path = 'lib/widgets/searchable_dropdown_field.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 4. Fix showSupplierSelectDialog
    # Find `return showDialog<String?>` inside showSupplierSelectDialog
    
    # Needs: `import '../blocs/suppliers/suppliers_bloc.dart';`
    if 'import \'../blocs/suppliers/suppliers_bloc.dart\';' not in content:
        content = content.replace("import '../blocs/projects/projects_bloc.dart';", "import '../blocs/projects/projects_bloc.dart';\nimport '../blocs/suppliers/suppliers_bloc.dart';")
        
    target = """Future<String?> showSupplierSelectDialog(
  BuildContext context,
  List<Supplier> suppliers, {
  String? selectedSupplierId,
}) async {
  return showDialog<String?>(
    context: context,
    builder: (context) {
      String search = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final query = search.trim().toLowerCase();
          final filtered = suppliers.where((s) {"""
          
    replacement = """Future<String?> showSupplierSelectDialog(
  BuildContext context,
  List<Supplier> suppliers, {
  String? selectedSupplierId,
}) async {
  try {
    context.read<SuppliersBloc>().add(LoadSuppliers());
  } catch (_) {}

  return showDialog<String?>(
    context: context,
    builder: (context) {
      String search = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return BlocBuilder<SuppliersBloc, SuppliersState>(
            builder: (context, state) {
              final isLoaded = state is SuppliersLoaded;
              final currentSuppliers = isLoaded ? state.suppliers : suppliers;

              if (!isLoaded) {
                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  backgroundColor: AppColors.surface,
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text("Chargement des fournisseurs...", style: TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                );
              }

              final query = search.trim().toLowerCase();
              final filtered = currentSuppliers.where((s) {"""
              
    content = content.replace(target, replacement)
    
    # Add closing `);` for the `BlocBuilder`
    target_end = """                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<String?> showProductSelectDialog("""
    replacement_end = """                  ),
                ],
              ),
            );
            },
          );
        },
      );
    },
  );
}

Future<String?> showProductSelectDialog("""
    content = content.replace(target_end, replacement_end)
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done Supplier")

if __name__ == '__main__':
    process()
