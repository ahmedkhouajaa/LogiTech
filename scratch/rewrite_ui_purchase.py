import re

file_path = r"d:\LogiTech\lib\screens\create_purchase_invoice_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

# Remove the bad imports
content = content.replace("import '../widgets/smart_dropdown.dart';", "")
content = content.replace("import '../widgets/supplier_dialog.dart';", "")
if "import 'suppliers_screen.dart';" not in content:
    content = content.replace("import '../widgets/dashboard_card.dart';", "import '../widgets/dashboard_card.dart';\nimport 'suppliers_screen.dart';")


# 1. Fix the Client & Project row
client_project_row_old = """          // Fournisseur & Project row
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: BlocBuilder<SuppliersBloc, SuppliersState>(
                  builder: (context, state) {
                    final suppliers = state is SuppliersLoaded ? state.suppliers : <Supplier>[];
                    return SmartDropdown<String>(
                      label: 'Fournisseur',
                      value: _selectedSupplier?.id,
                      items: suppliers.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name, style: const TextStyle(fontSize: 13)))).toList(),
                      onChanged: (v) {
                        if (!widget.isReadOnly && v != null) {
                          final supplier = suppliers.firstWhere((s) => s.id == v);
                          setState(() => _selectedSupplier = supplier);
                        }
                      },
                      hint: 'Rechercher des fournisseurs...',
                    );
                  },
                ),
              ),
              if (!widget.isReadOnly) ...[
                const SizedBox(width: 8),
                Container(
                  height: 56,
                  margin: const EdgeInsets.only(bottom: 2),
                  child: ElevatedButton(
                    onPressed: _showAddSupplierDialog,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                      foregroundColor: AppColors.primary,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                      side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded),
                  ),
                ),
              ],
              const SizedBox(width: 16),
              Expanded(
                child: BlocBuilder<ProjectsBloc, ProjectsState>(
                  builder: (context, state) {
                    final projects = state is ProjectsLoaded ? state.projects : <Project>[];
                    return SmartDropdown<String>(
                      label: 'Projet',
                      value: _selectedProjectId,
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('Projet par défaut', style: TextStyle(fontSize: 13))),
                        ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (v) {
                        if (!widget.isReadOnly) setState(() => _selectedProjectId = v);
                      },
                      hint: 'Sélectionner un projet',
                    );
                  },
                ),
              ),
            ],
          ),"""

client_project_row_new = """          // Fournisseur & Project row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Fournisseur', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: BlocBuilder<SuppliersBloc, SuppliersState>(
                            builder: (context, state) {
                              final suppliers = state is SuppliersLoaded ? state.suppliers : <Supplier>[];
                              return DropdownButtonFormField<String>(
                                value: _selectedSupplier?.id,
                                isExpanded: true,
                                hint: const Text('Rechercher des fournisseurs...', style: TextStyle(fontSize: 13, color: Colors.black87)),
                                items: suppliers.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, style: const TextStyle(fontSize: 13)))).toList(),
                                onChanged: (v) {
                                  if (!widget.isReadOnly && v != null) {
                                    final supplier = suppliers.firstWhere((c) => c.id == v);
                                    setState(() => _selectedSupplier = supplier);
                                  }
                                },
                                decoration: _formInputDecoration(),
                              );
                            },
                          ),
                        ),
                        if (!widget.isReadOnly) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 48,
                            child: Tooltip(
                              message: 'Créer un nouveau fournisseur',
                              child: ElevatedButton(
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => BlocProvider.value(
                                      value: context.read<SuppliersBloc>(),
                                      child: const SupplierDialog(existing: null),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.1),
                                  foregroundColor: AppColors.primary,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                                  side: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
                                ),
                                child: const Icon(Icons.person_add_alt_1_rounded, size: 20),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Projet', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                    const SizedBox(height: 6),
                    BlocBuilder<ProjectsBloc, ProjectsState>(
                      builder: (context, state) {
                        final projects = state is ProjectsLoaded ? state.projects : <Project>[];
                        return DropdownButtonFormField<String>(
                          value: _selectedProjectId,
                          isExpanded: true,
                          hint: const Text('Projet par defaut', style: TextStyle(fontSize: 13, color: Colors.black87)),
                          items: [
                            const DropdownMenuItem<String>(value: null, child: Text('Projet par defaut', style: TextStyle(fontSize: 13))),
                            ...projects.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 13)))),
                          ],
                          onChanged: (v) {
                            if (!widget.isReadOnly) setState(() => _selectedProjectId = v);
                          },
                          decoration: _formInputDecoration(),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),"""

content = content.replace(client_project_row_old, client_project_row_new)


# 2. Fix the Article dropdown
article_row_old = """      return Row(
        children: [
          // Select article dropdown
          Expanded(
            child: BlocBuilder<ProductsBloc, ProductsState>(
              builder: (context, state) {
                final products = state is ProductsLoaded ? state.products : <Product>[];
                return SmartDropdown<String>(
                  label: '',
                  value: null,
                  items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 13)))).toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    final product = products.firstWhere((p) => p.id == v);
                    _addProductItem(product);
                  },
                  hint: 'Sélectionner un article...',
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          // Add empty line button
          SizedBox(
            height: 48,
            child: OutlinedButton(
              onPressed: _addEmptyItem,"""

article_row_new = """      return Row(
        children: [
          // Select article dropdown
          Expanded(
            child: BlocBuilder<ProductsBloc, ProductsState>(
              builder: (context, state) {
                final products = state is ProductsLoaded ? state.products : <Product>[];
                return Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: Colors.grey.shade400, width: 1.0),
                  ),
                  child: DropdownButtonFormField<String>(
                    hint: const Text('Selectionner un article...', style: TextStyle(fontSize: 13, color: Colors.black87)),
                    isExpanded: true,
                    items: products.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      final product = products.firstWhere((p) => p.id == v);
                      _addProductItem(product);
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide.none),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          // Add empty line button
          SizedBox(
            height: 44,
            child: OutlinedButton(
              onPressed: _addEmptyItem,"""

content = content.replace(article_row_old, article_row_new)


with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
