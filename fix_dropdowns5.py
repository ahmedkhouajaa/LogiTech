import re

def process():
    path = 'lib/widgets/searchable_dropdown_field.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Make sure we have the required imports
    if "import '../blocs/suppliers/suppliers_bloc.dart';" not in content:
        content = content.replace("import '../blocs/projects/projects_bloc.dart';", "import '../blocs/projects/projects_bloc.dart';\nimport '../blocs/suppliers/suppliers_bloc.dart';")
    if "import '../blocs/products/products_bloc.dart';" not in content:
        content = content.replace("import '../blocs/projects/projects_bloc.dart';", "import '../blocs/projects/projects_bloc.dart';\nimport '../blocs/products/products_bloc.dart';")

    # 1. showCustomerSelectDialog
    rep_cust = """final isLoaded = state is CustomersLoaded;
              final customers = isLoaded ? state.customers : initialCustomers;
              
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
                        Text("Chargement des clients...", style: TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                );
              }

              final query = search.trim().toLowerCase();"""
    content = content.replace("""final customers = state is CustomersLoaded ? state.customers : initialCustomers;
              final query = search.trim().toLowerCase();""", rep_cust)

    # 2. showProjectSelectDialog
    rep_proj = """final isLoaded = state is ProjectsLoaded;
              final projects = isLoaded ? state.projects : initialProjects;
              
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
                        Text("Chargement des projets...", style: TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                );
              }

              final query = search.trim().toLowerCase();"""
    content = content.replace("""final projects = state is ProjectsLoaded ? state.projects : initialProjects;
              final query = search.trim().toLowerCase();""", rep_proj)


    # 3. showSupplierSelectDialog
    rep_supp_start = """  try {
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
              
    content = content.replace("""  return showDialog<String?>(
    context: context,
    builder: (context) {
      String search = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final query = search.trim().toLowerCase();
          final filtered = suppliers.where((s) {""", rep_supp_start)

    end_supp_target = """                  ),
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
    end_supp_replacement = """                  ),
                ],
              ),
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
    content = content.replace(end_supp_target, end_supp_replacement)


    # 4. showProductSelectDialog
    rep_prod_start = """  try {
    context.read<ProductsBloc>().add(LoadProducts());
  } catch (_) {}

  return showDialog<String?>(
    context: context,
    builder: (context) {
      String search = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              final isLoaded = state is ProductsLoaded;
              final currentProducts = isLoaded ? state.products : products;

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
                        Text("Chargement des articles...", style: TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                );
              }

              final query = search.trim().toLowerCase();
              final filtered = currentProducts.where((p) {"""
              
    content = content.replace("""  return showDialog<String?>(
    context: context,
    builder: (context) {
      String search = '';
      return StatefulBuilder(
        builder: (context, setDialogState) {
          final query = search.trim().toLowerCase();
          final filtered = products.where((p) {""", rep_prod_start)

    end_prod_target = """                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}"""
    end_prod_replacement = """                  ),
                ],
              ),
            ),
          );
            },
          );
        },
      );
    },
  );
}"""
    
    prod_idx = content.find('Future<String?> showProductSelectDialog(')
    target_idx = content.find(end_prod_target, prod_idx)
    if target_idx != -1:
        content = content[:target_idx] + end_prod_replacement + content[target_idx + len(end_prod_target):]

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done All Dropdowns Fixed!")

if __name__ == '__main__':
    process()
