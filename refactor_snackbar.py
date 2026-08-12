import os
import re

path = r'd:\LogiTech\lib'
import_statement = "import 'package:business_manager_pro/services/error_handler.dart';\n"

for root, dirs, files in os.walk(path):
    for f in files:
        if f.endswith('.dart') and 'error_handler.dart' not in f and 'error_widget' not in f:
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()
                
            original_content = content
            
            # Safer regex without [\s\S]*? which can span large blocks of code
            # Match only characters that are not semicolons or closing brackets to stay within the statement
            # Example: ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur: ${e.toString()}'), backgroundColor: AppColors.error));
            
            # Using non-greedy up to 200 chars to avoid eating catch blocks
            pattern1 = r'ScaffoldMessenger\.of\(context\)\.showSnackBar\(\s*SnackBar\([^;]{1,150}?e\.toString\([^;]{1,100}?\)\s*\)\s*;'
            content = re.sub(pattern1, r'ErrorHandler.showErrorSnackBar(context, e);', content)
            
            pattern2 = r'messenger\.showSnackBar\(\s*SnackBar\([^;]{1,150}?e\.toString\([^;]{1,100}?\)\s*\)\s*;'
            content = re.sub(pattern2, r'ErrorHandler.showErrorSnackBar(context, e);', content)
            
            pattern3 = r'ScaffoldMessenger\.of\(context\)\.showSnackBar\([^;]{1,80}?e\.toString\([^;]{1,80}?\)\s*;'
            content = re.sub(pattern3, r'ErrorHandler.showErrorSnackBar(context, e);', content)

            if content != original_content:
                # Add import if not present
                if 'package:business_manager_pro/services/error_handler.dart' not in content:
                    imports = list(re.finditer(r'^import .*?;$', content, re.MULTILINE))
                    if imports:
                        last_import = imports[-1]
                        insert_idx = last_import.end() + 1
                        content = content[:insert_idx] + import_statement + content[insert_idx:]
                    else:
                        content = import_statement + content
                        
                with open(filepath, 'w', encoding='utf-8') as file:
                    file.write(content)
                print(f"Updated {f}")
