import re

filepath = r'd:\LogiTech\lib\database\database_helper.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    lines = f.readlines()

changes = 0

for i, line in enumerate(lines):
    stripped = line.strip()
    
    # Pattern 1: List<String> whereClauses = ['XX.is_deleted = 0']; without _entWhereClause
    if "whereClauses = ['" in stripped and '_entWhereClause' not in stripped:
        # Extract alias from the pattern like 'xx.is_deleted = 0'
        m = re.search(r"'(\w+)\.is_deleted = 0'", stripped)
        if m:
            alias = m.group(1)
            old = f"'{alias}.is_deleted = 0'"
            new = f"'{alias}.is_deleted = 0', _entWhereClause('{alias}')"
            lines[i] = line.replace(old, new)
            changes += 1
            print(f"Line {i+1}: Added _entWhereClause('{alias}')")
        else:
            # Pattern: 'is_deleted = 0' (no alias)
            m2 = re.search(r"'is_deleted = 0'", stripped)
            if m2:
                old = "'is_deleted = 0'"
                new = "'is_deleted = 0', _entWhereClause()"
                lines[i] = line.replace(old, new)
                changes += 1
                print(f"Line {i+1}: Added _entWhereClause() (no alias)")
            else:
                # Pattern: '1=1' without _entWhereClause
                m3 = re.search(r"'1=1'", stripped)
                if m3 and '_entWhereClause' not in stripped:
                    # Need to find the alias from nearby query lines
                    # Look ahead for FROM table alias pattern
                    alias = ''
                    for j in range(i+1, min(i+20, len(lines))):
                        am = re.search(r'FROM\s+\w+\s+(\w+)', lines[j])
                        if am:
                            alias = am.group(1)
                            break
                    if alias:
                        old = "'1=1'"
                        new = f"'1=1', _entWhereClause('{alias}')"
                        lines[i] = line.replace(old, new)
                        changes += 1
                        print(f"Line {i+1}: Added _entWhereClause('{alias}') for 1=1 pattern")

# Now fix raw queries that have WHERE xxx.is_deleted = 0 without $filter
# Pattern: WHERE xxx.is_deleted = 0\n without $filter on same line
for i, line in enumerate(lines):
    stripped = line.strip()
    
    # Find lines with WHERE alias.is_deleted = 0 at end (no $filter)
    m = re.search(r"WHERE\s+(\w+)\.is_deleted\s*=\s*0\s*$", stripped)
    if m and '$filter' not in stripped and '_entFilter' not in stripped and '_entWhereClause' not in stripped:
        alias = m.group(1)
        # Check if next few lines already have $filter
        has_filter = False
        for j in range(i+1, min(i+3, len(lines))):
            if '$filter' in lines[j]:
                has_filter = True
                break
        if not has_filter:
            old_pattern = f"WHERE {alias}.is_deleted = 0"
            # Check if there's trailing whitespace or newline
            new_pattern = f"WHERE {alias}.is_deleted = 0 ${{filter_{alias}}}"
            # Actually, let's just not do this - it's too risky with raw queries
            # The whereClauses approach above covers all paginated methods
            pass

with open(filepath, 'w', encoding='utf-8') as f:
    f.writelines(lines)

print(f"\nTotal changes: {changes}")
