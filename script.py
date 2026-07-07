import glob
import os

files = glob.glob('lib/mobile/screens/forms/mobile_*_form_screen.dart')

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()

    # Only process files that have 'Ajouter une ligne'
    if 'Ajouter une ligne' not in content: continue

    # Check if already has the row
    if 'Row(' in content and 'Icons.add_circle_outline' in content and 'Ajouter une ligne' in content:
        continue

    # 1. Add import if not present
    if 'mobile_product_form_screen.dart' not in content:
        content = content.replace("import '../../widgets/forms/mobile_totals_card.dart';", "import '../../widgets/forms/mobile_totals_card.dart';\nimport 'mobile_product_form_screen.dart';")
        content = content.replace("import '../../widgets/forms/mobile_article_form.dart';", "import '../../widgets/forms/mobile_article_form.dart';\nimport 'mobile_product_form_screen.dart';")

    # 2. Replace the OutlinedButton
    target = """                OutlinedButton.icon(
                  onPressed: () => _showArticleForm(),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Ajouter une ligne'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                  ),
                ),"""
    
    replacement = """                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showArticleForm(),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Ajouter une ligne'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
                      tooltip: 'Créer un nouvel article',
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileProductFormScreen()));
                      },
                    ),
                  ],
                ),"""
    
    if target in content:
        content = content.replace(target, replacement)
        with open(f, 'w', encoding='utf-8') as file:
            file.write(content)
        print(f'Updated {f}')
