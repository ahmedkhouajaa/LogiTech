import os

replacements = {
    'ÃƒÂ©': 'é',
    'ÃƒÂ¨': 'è',
    'ÃƒÂª': 'ê',
    'ÃƒÂ ': 'à',
    'ÃƒÂ§': 'ç',
    'ÃƒÂ´': 'ô',
    'ÃƒÂ®': 'î',
    'ÃƒÂ¯': 'ï',
    'Ã©': 'é',
    'Ã¨': 'è',
    'Ãª': 'ê',
    'Ã ': 'à',
    'Ã§': 'ç',
    'Ã´': 'ô',
    'Ã®': 'î',
    'Ã¯': 'ï',
    'â‚¬': '€',
    'Ã¢â€šÂ¬': '€',
    'Ã¢â‚¬â„¢': '’',
    'Ã¢â‚¬â€œ': '–',
    'Ã¢â‚¬Â ': '”',
    'Ã¢â‚¬Å“': '“',
    'â€ ': '”',
    'â€œ': '“',
    'â€™': '’',
    'â€œ': '“',
    'Â°': '°',
    'Ã‚Â°': '°',
    'â€¹': '‹',
    'â€º': '›',
    'ÃƒÂ»': 'û',
    'Ã»': 'û',
    'Ã¢â€\x80\x94': '—',
    'Ã¢â€\x80\x93': '–',
    'Ã¢â€\x80\x98': '‘',
    'Ã¢â€\x80\x99': '’',
    'Ã¢â€\x80\x9A': '‚',
    'Ã¢â€\x80\x9B': '‛',
    'Ã¢â€\x80\x9C': '“',
    'Ã¢â€\x80\x9D': '”',
    'Ã¢â€\x80\x9E': '„',
    'Ã¢â€\x80\xA6': '…'
}

files_to_check = [
    'lib/screens/return_notes_screen.dart',
    'lib/screens/create_return_note_screen.dart',
    'lib/screens/delivery_notes_screen.dart',
]

for file_path in files_to_check:
    if os.path.exists(file_path):
        with open(file_path, 'r', encoding='utf-8') as f:
            text = f.read()
        
        for k, v in replacements.items():
            text = text.replace(k, v)
            
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(text)
print('Done!')
