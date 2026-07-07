import glob

files = glob.glob('lib/mobile/screens/forms/mobile_*_form_screen.dart')

def find_matching_paren(s, start_idx):
    count = 1
    for i in range(start_idx + 1, len(s)):
        if s[i] == '(':
            count += 1
        elif s[i] == ')':
            count -= 1
        if count == 0:
            return i
    return -1

for f in files:
    with open(f, 'r', encoding='utf-8') as file:
        content = file.read()

    if 'OutlinedButton.icon(' not in content:
        continue
        
    if 'Ajouter une ligne' not in content and 'Ajouter un article' not in content:
        continue

    # Find the start of the OutlinedButton.icon
    idx = content.find('OutlinedButton.icon(')
    start_paren = idx + len('OutlinedButton.icon')
    
    end_paren = find_matching_paren(content, start_paren)
    
    if end_paren == -1:
        print(f"Error parsing {f}")
        continue
        
    button_code = content[idx:end_paren+1]
    
    if 'Expanded(' in content[idx-20:idx]:
        # Already wrapped in Row/Expanded by a previous run
        continue

    # Find indentation by looking backwards
    indent_idx = idx - 1
    while indent_idx >= 0 and content[indent_idx] in [' ', '\t']:
        indent_idx -= 1
    indent = content[indent_idx+1:idx]

    replacement = f"""Row(
{indent}  children: [
{indent}    Expanded(
{indent}      child: {button_code.replace(chr(10), chr(10) + '      ')}
{indent}    ),
{indent}    const SizedBox(width: 8),
{indent}    IconButton(
{indent}      icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 28),
{indent}      tooltip: 'Créer un nouvel article',
{indent}      onPressed: () {{
{indent}        Navigator.push(context, MaterialPageRoute(builder: (_) => const MobileProductFormScreen()));
{indent}      }},
{indent}    ),
{indent}  ],
{indent})"""

    new_content = content[:idx] + replacement + content[end_paren+1:]

    # Add import
    if 'mobile_product_form_screen.dart' not in new_content:
        new_content = new_content.replace("import '../../widgets/forms/mobile_totals_card.dart';", "import '../../widgets/forms/mobile_totals_card.dart';\nimport 'mobile_product_form_screen.dart';")
        new_content = new_content.replace("import '../../widgets/forms/mobile_article_form.dart';", "import '../../widgets/forms/mobile_article_form.dart';\nimport 'mobile_product_form_screen.dart';")
        if 'mobile_product_form_screen.dart' not in new_content:
            new_content = "import 'mobile_product_form_screen.dart';\n" + new_content

    with open(f, 'w', encoding='utf-8') as file:
        file.write(new_content)
    print(f"Updated {f}")
