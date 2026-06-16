import re

with open('lib/screens/create_return_note_screen.dart', 'r', encoding='utf-8') as f:
    text = f.read()

# Imports
text = text.replace(
    "import '../blocs/return_notes/return_notes_bloc.dart';",
    "import '../blocs/return_notes/return_notes_bloc.dart';\nimport '../blocs/return_notes/return_notes_event.dart';"
)

# ReturnNoteItem property mapping
text = text.replace('item.tvaAmount', '(item.totalHT * item.tvaRate / 100)')
text = text.replace('i.tvaAmount', '(i.totalHT * i.tvaRate / 100)')
text = text.replace('item.ReturnNoteId', 'item.returnNoteId')
text = text.replace('i.ReturnNoteId', 'i.returnNoteId')
text = text.replace('ReturnNoteId: ', 'returnNoteId: ')
text = text.replace('description:', 'designation:')
text = text.replace('item.description', 'item.designation')
text = text.replace('i.description', 'i.designation')

# ReturnNote property mapping
text = text.replace('note.number', 'note.returnNumber')
text = text.replace('n.number', 'n.returnNumber')
text = text.replace('widget.existing?.number', 'widget.existing?.returnNumber')
text = text.replace('note.date', 'note.dateEmission')
text = text.replace('n.date', 'n.dateEmission')
text = text.replace('n.conditionsGenerales', 'n.conditions')
text = text.replace('number: number,', 'returnNumber: number,')
text = text.replace('date: _date,', 'dateEmission: _date,')
text = text.replace('conditionsGenerales:', 'conditions:')

# Remove removed fields in ReturnNoteItem instantiations
text = re.sub(r'\s*discountPercent:\s*[^,]+,', '', text)
text = re.sub(r'\s*showDescription:\s*[^,]+,', '', text)
text = re.sub(r'\s*showDiscount:\s*[^,]+,', '', text)

# Remove removed fields in ReturnNote instantiations
text = re.sub(r'\s*projectId:\s*[^,]+,', '', text)
text = re.sub(r'\s*pricingMode:\s*[^,]+,', '', text)
text = re.sub(r'\s*globalDiscountPercent:\s*[^,]+,', '', text)
text = re.sub(r'\s*timbreFiscal:\s*[^,]+,', '', text)
text = re.sub(r'\s*vehicleRegistration:\s*[^,]+,', '', text)
text = re.sub(r'\s*driverName:\s*[^,]+,', '', text)
text = re.sub(r'\s*orderId:\s*[^,]+,', '', text)

# Remove unused variables from _CreateReturnNoteScreenState reading n
text = re.sub(r'\s*_selectedProjectId\s*=\s*n\.projectId;', '', text)
text = re.sub(r'\s*_pricingModeHT\s*=\s*n\.pricingMode[^;]+;', '', text)
text = re.sub(r'\s*_withGlobalDiscount\s*=\s*n\.globalDiscountPercent[^;]+;', '', text)
text = re.sub(r'\s*_globalDiscountPercent\s*=\s*n\.globalDiscountPercent;', '', text)
text = re.sub(r'\s*_withTimbreFiscal\s*=\s*n\.timbreFiscal[^;]+;', '', text)
text = re.sub(r'\s*_vehicleCtrl\.text\s*=\s*n\.vehicleRegistration[^;]+;', '', text)
text = re.sub(r'\s*_driverCtrl\.text\s*=\s*n\.driverName[^;]+;', '', text)

# Remove from items loop mapping
text = re.sub(r'\s*item\.copyWith\(description: v\)', 'item.copyWith(designation: v)', text)

with open('lib/screens/create_return_note_screen.dart', 'w', encoding='utf-8') as f:
    f.write(text)
