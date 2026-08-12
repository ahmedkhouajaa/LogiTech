import re
import sys

def process():
    path = 'lib/widgets/searchable_dropdown_field.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Fix showProductSelectDialog
    # We want to wrap the returned Dialog inside a BlocBuilder<ProductsBloc, ProductsState>.
    # And if state is! ProductsLoaded, we return a loading indicator.
    # Otherwise we return the Dialog as before.
    
    # Let's find the start of the Dialog return inside showProductSelectDialog
    dialog_start_idx = content.find('          return Dialog(\n            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),', content.find('Future<String?> showProductSelectDialog'))
    if dialog_start_idx != -1:
        # Replace the return Dialog( with BlocBuilder
        replacement = """          return BlocBuilder<ProductsBloc, ProductsState>(
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
              final filtered = currentProducts.where((p) {
                if (query.isEmpty) return true;
                final nameMatch = p.name.toLowerCase().contains(query);
                final codeMatch = p.code.toLowerCase().contains(query);
                final refMatch = p.reference?.toLowerCase().contains(query) ?? false;
                final barcodeMatch = p.barcode?.toLowerCase().contains(query) ?? false;
                return nameMatch || codeMatch || refMatch || barcodeMatch;
              }).toList();

              return Dialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),"""
        
        # We need to replace the `final query = ... return nameMatch || codeMatch || refMatch || barcodeMatch; }).toList(); return Dialog( shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),` block.
        # Find the start of `final query = search.trim().toLowerCase();` inside showProductSelectDialog
        query_start_idx = content.find('          final query = search.trim().toLowerCase();', content.find('builder: (context, setDialogState) {', content.find('Future<String?> showProductSelectDialog')))
        dialog_shape_idx = content.find('backgroundColor: AppColors.surface,', dialog_start_idx)
        
        if query_start_idx != -1 and dialog_shape_idx != -1:
            content = content[:query_start_idx] + replacement + '\n            ' + content[dialog_shape_idx:]
            
            # Now we need to add the closing `);` for the `BlocBuilder`!
            # The dialog builder for StatefulBuilder ends with:
            #             ),
            #           );
            #         },
            #       );
            
            # So let's find the end of showProductSelectDialog
            # We search for:
            end_dialog_str = """                  ),
                ],
              ),
            ),
          );"""
            end_dialog_idx = content.find(end_dialog_str, query_start_idx)
            if end_dialog_idx != -1:
                replacement_end = """                  ),
                ],
              ),
            );
            },
          );"""
                content = content[:end_dialog_idx] + replacement_end + content[end_dialog_idx + len(end_dialog_str):]
                print("Successfully patched showProductSelectDialog!")
                
                # Also, we need to trigger LoadProducts() if it's not loaded
                try_load_str = """  try {
    context.read<ProductsBloc>().add(LoadProducts());
  } catch (_) {}

  return showDialog<String?>("""
                return_show_idx = content.find('  return showDialog<String?>(', content.find('Future<String?> showProductSelectDialog'))
                if return_show_idx != -1:
                    content = content[:return_show_idx] + try_load_str + content[return_show_idx + len('  return showDialog<String?>('):]
                    print("Successfully added LoadProducts trigger!")
            
            
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)

if __name__ == '__main__':
    process()
