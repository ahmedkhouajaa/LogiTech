import re

filepath = r'd:\LogiTech\lib\services\firestore_pagination_service.dart'

with open(filepath, 'r', encoding='utf-8') as f:
    content = f.read()

# Pattern matching Query query = _firestore.collection(...)
# Replace with Query query = _applyEnterpriseFilter(_firestore.collection(...))

new_content = re.sub(
    r"Query query = _firestore\.collection\(([^)]+)\)",
    r"Query query = _applyEnterpriseFilter(_firestore.collection(\1))",
    content
)

with open(filepath, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Updated FirestorePaginationService queries!")
