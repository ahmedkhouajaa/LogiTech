import os
import re

path = r'd:\LogiTech\lib\blocs'
import_statement = "import 'package:business_manager_pro/services/error_handler.dart';\n"

for root, dirs, files in os.walk(path):
    for f in files:
        if f.endswith('_bloc.dart'):
            filepath = os.path.join(root, f)
            with open(filepath, 'r', encoding='utf-8') as file:
                content = file.read()
            
            # Replace emit(SomethingError(e.toString())) -> emit(SomethingError(ErrorHandler.parseError(e)))
            new_content = re.sub(r'emit\(([a-zA-Z0-9_]+Error)\(.*?(?:e\.toString\(\)|e).*?\)\);', r'emit(\1(ErrorHandler.parseError(e)));', content)
            
            if new_content != content:
                # Add import if not present
                if 'package:business_manager_pro/services/error_handler.dart' not in new_content:
                    # Find last import
                    imports = list(re.finditer(r'^import .*?;$', new_content, re.MULTILINE))
                    if imports:
                        last_import = imports[-1]
                        insert_idx = last_import.end() + 1
                        new_content = new_content[:insert_idx] + import_statement + new_content[insert_idx:]
                    else:
                        new_content = import_statement + new_content
                
                with open(filepath, 'w', encoding='utf-8') as file:
                    file.write(new_content)
                print(f"Updated {f}")
