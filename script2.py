import glob
import re

files = glob.glob('lib/mobile/screens/forms/mobile_*_form_screen.dart')

target_pattern = re.compile(r"(\s+)(OutlinedButton\.icon\(\s*onPressed:.*?\s*icon:.*?,\s*label:\s*const\s*Text\('(?:Ajouter une ligne|Ajouter un article)'\).*?\),?)(?!\s*\)\s*,?\s*const\s*SizedBox)", re.DOTALL)

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()

    # Skip if already wrapped in Row with add_circle_outline
    if 'add_circle_outline' in content and 'Ajouter une ligne' in content and 'Row(' in content:
        # Actually some files might have it already from my previous script.
        pass

    def replacement(match):
        indent = match.group(1)
        button_code = match.group(2)
        
        # If it's already in an expanded, skip
        if 'Expanded(' in button_code:
            return match.group(0)
            
        res = f"{indent}Row({indent}  children: [{indent}    Expanded({indent}      child: {button_code}{indent}    ),{indent}    const SizedBox(width: 8),{indent}    IconButton({indent}      icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),{indent}      tooltip: 'Créer un nouvel article',{indent}      onPressed: () {{{indent}        Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileProductFormScreen()));{indent}      }},{indent}    ),{indent}  ],{indent}),"
        return res

    new_content, count = target_pattern.subn(replacement, content)
    
    if count > 0:
        # Add import
        if 'mobile_product_form_screen.dart' not in new_content:
            new_content = new_content.replace("import '../../widgets/forms/mobile_totals_card.dart';", "import '../../widgets/forms/mobile_totals_card.dart';\nimport 'mobile_product_form_screen.dart';")
            new_content = new_content.replace("import '../../widgets/forms/mobile_article_form.dart';", "import '../../widgets/forms/mobile_article_form.dart';\nimport 'mobile_product_form_screen.dart';")
            if 'mobile_product_form_screen.dart' not in new_content:
                 new_content = "import 'mobile_product_form_screen.dart';\n" + new_content
        with open(f, 'w', encoding='utf-8') as file:
            file.write(new_content)
        print(f"Updated {f}")
