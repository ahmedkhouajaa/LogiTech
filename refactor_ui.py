import os
import re

path = r'd:\LogiTech\lib'
import_statement = "import 'package:business_manager_pro/widgets/app_error_widget.dart';\n"

# Pattern for error blocks with retry button
pattern_with_retry = r'if\s*\(\s*state\s+is\s+([A-Za-z]+Error)\s*\)\s*\{\s*return\s+Center\(\s*child:\s*Column\([\s\S]*?onPressed:\s*\(\)\s*=>\s*(context\.read<[A-Za-z]+Bloc>\(\)\.add\([A-Za-z0-9_]+\(\)\))[\s\S]*?\)\s*;\s*\}'

# Pattern for error blocks with just text
pattern_simple = r'if\s*\(\s*state\s+is\s+([A-Za-z]+Error)\s*\)\s*\{\s*return\s+Center\(.*?Text\(.*?state\.message.*?\).*?\)\s*;\s*\}'

for root, dirs, files in os.walk(path):
    for f in files:
        if f.endswith('.dart') and 'bloc.dart' not in f and 'error_widget' not in f and 'error_handler' not in f:
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()
                
            original_content = content
            
            # Replace complex blocks with retry
            content = re.sub(
                pattern_with_retry,
                r'if (state is \1) {\n            return AppErrorWidget(\n              message: state.message,\n              onRetry: () => \2,\n            );\n          }',
                content
            )
            
            # Replace simple blocks
            content = re.sub(
                pattern_simple,
                r'if (state is \1) {\n            return AppErrorWidget(message: state.message);\n          }',
                content
            )
            
            # Also catch any other return Center(child: Text('Erreur...')) just in case
            content = re.sub(
                r'return\s+Center\(\s*child:\s*Text\(\s*\'Erreur:\s*\$\{(?:state\.)?message\}\'.*?\)\s*\);',
                r'return AppErrorWidget(message: state.message);',
                content
            )
            
            if content != original_content:
                # Add import if not present
                if 'package:business_manager_pro/widgets/app_error_widget.dart' not in content:
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
