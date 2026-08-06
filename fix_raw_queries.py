import re

filepath = r'd:\LogiTech\lib\database\database_helper.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Lines where raw queries have WHERE alias.is_deleted = 0 at end without $filter
# We need to add _entFilter('alias') usage
# But first we need to ensure there's a local `final filter = _entFilter('alias');` variable

lines = content.split('\n')
changes = 0

# Target lines that end with WHERE xx.is_deleted = 0 (trailing whitespace ok)
# and DON'T have $filter
# We need to be careful: some are getById methods (WHERE xx.id = ? AND xx.is_deleted = 0)
# which should NOT be enterprise-filtered (they fetch a specific record by ID)

# Only fix the list-query pattern: WHERE xx.is_deleted = 0 (without xx.id = ?)
target_lines = []
for i, line in enumerate(lines):
    stripped = line.rstrip()
    # Match WHERE alias.is_deleted = 0 at end of line (no $filter, no id = ?)
    m = re.search(r"WHERE\s+(\w+)\.is_deleted\s*=\s*0\s*$", stripped)
    if m and '$filter' not in stripped and 'id = ?' not in stripped:
        target_lines.append((i, m.group(1)))

for i, alias in target_lines:
    old_line = lines[i]
    # Replace WHERE alias.is_deleted = 0 with WHERE alias.is_deleted = 0 $filter
    # But we also need to add `final filter = _entFilter('alias');` before the query
    
    # Find the rawQuery start (look backwards for the line with 'rawQuery' or 'query =')
    # And insert filter declaration there
    
    # For now, just add $filter inline
    # We need to find where the local `filter` variable should be declared
    # Look backwards for 'final db = await database;'
    db_line = None
    for j in range(i-1, max(i-15, 0), -1):
        if 'final db = await database;' in lines[j]:
            db_line = j
            break
    
    if db_line is not None:
        # Check if filter is already declared
        has_filter = False
        for j in range(db_line, i):
            if f"_entFilter('{alias}')" in lines[j] or 'final filter' in lines[j]:
                has_filter = True
                break
        
        if not has_filter:
            # Add filter declaration after db line
            indent = '    '  # Match indentation
            filter_line = f"{indent}final filter = _entFilter('{alias}');\n"
            lines[db_line] = lines[db_line] + '\n' + filter_line.rstrip()
            # Now the indices shifted by 1, but since we process in order and 
            # only add after db_line, this is fine for later entries
            # Actually this shifts everything - let's just modify the WHERE line directly
            # Reset and use a simpler approach
    
    # Simple approach: just append $filter to the WHERE line
    lines[i] = old_line.rstrip().replace(
        f'WHERE {alias}.is_deleted = 0',
        f'WHERE {alias}.is_deleted = 0 ${{_entFilter(\'{alias}\')}}'
    ) + '\n'
    changes += 1
    print(f"Line {i+1}: Added _entFilter('{alias}') to WHERE clause")

# Hmm, this ${} syntax won't work in Dart raw strings.
# Let me use a different approach - inject the filter as string interpolation

# Actually, let me redo this properly. In Dart, these are in triple-quoted strings.
# The pattern is:
#   final maps = await db.rawQuery('''
#     SELECT ...
#     WHERE xx.is_deleted = 0
#   ''');
# We need to change it to use _entFilter. But the filter variable needs to be
# declared before the rawQuery call.
# 
# Better approach: Find each method, add `final filter = _entFilter('xx');` after
# `final db = await database;`, then append `$filter` to the WHERE clause.

# Let me revert and redo properly
with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

changes = 0
i = 0
while i < len(lines):
    stripped = lines[i].rstrip()
    
    # Match WHERE alias.is_deleted = 0 at end of line (no $filter, no id = ?)
    m = re.search(r"WHERE\s+(\w+)\.is_deleted\s*=\s*0\s*$", stripped)
    if m and '$filter' not in stripped and 'id = ?' not in stripped and '$_entFilter' not in stripped:
        alias = m.group(1)
        
        # Look backwards for 'final db = await database;'
        db_line_idx = None
        for j in range(i-1, max(i-20, 0), -1):
            if 'final db = await database;' in lines[j]:
                db_line_idx = j
                break
        
        if db_line_idx is not None:
            # Check if filter variable already exists between db line and current line
            has_filter_var = False
            for j in range(db_line_idx, i):
                if f"_entFilter('{alias}')" in lines[j]:
                    has_filter_var = True
                    break
            
            if not has_filter_var:
                # Get indentation from db line
                indent = re.match(r'^(\s*)', lines[db_line_idx]).group(1)
                filter_decl = f"{indent}final filter = _entFilter('{alias}');\r\n"
                
                # Insert filter declaration after db line
                lines.insert(db_line_idx + 1, filter_decl)
                i += 1  # Adjust for inserted line
                
                # Now fix the WHERE line (which shifted by 1)
                lines[i] = lines[i].rstrip().replace(
                    f'WHERE {alias}.is_deleted = 0',
                    f'WHERE {alias}.is_deleted = 0 $filter'
                ) + '\r\n'
                
                changes += 1
                print(f"Added _entFilter('{alias}') for method near line {db_line_idx+1}")
    
    i += 1

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"\nTotal raw query changes: {changes}")
