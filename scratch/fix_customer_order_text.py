file_path = r"d:\LogiTech\lib\screens\create_customer_order_screen.dart"

with open(file_path, "r", encoding="utf-8") as f:
    content = f.read()

content = content.replace('style: const TextStyle(fontSize: 13, color: AppColors.textTertiary)', 'style: const TextStyle(fontSize: 13, color: Colors.black87)')
content = content.replace('style: const TextStyle(color: AppColors.textTertiary, fontSize: 13)', 'style: const TextStyle(fontSize: 13, color: Colors.black87)')
content = content.replace('style: TextStyle(fontSize: 13, color: AppColors.textTertiary)', 'style: const TextStyle(fontSize: 13, color: Colors.black87)')
content = content.replace('style: TextStyle(color: AppColors.textTertiary, fontSize: 13)', 'style: const TextStyle(fontSize: 13, color: Colors.black87)')

content = content.replace('hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 13)', 'hintStyle: const TextStyle(color: Colors.black87, fontSize: 13)')
content = content.replace('hintStyle: const TextStyle(fontSize: 13, color: AppColors.textTertiary)', 'hintStyle: const TextStyle(fontSize: 13, color: Colors.black87)')
content = content.replace('hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 13)', 'hintStyle: const TextStyle(fontSize: 13, color: Colors.black87)')
content = content.replace('hintStyle: TextStyle(fontSize: 13, color: AppColors.textTertiary)', 'hintStyle: const TextStyle(fontSize: 13, color: Colors.black87)')

content = content.replace('style: const TextStyle(color: AppColors.textTertiary, fontSize: 12)', 'style: const TextStyle(color: Colors.black87, fontSize: 12)')
content = content.replace('style: TextStyle(color: AppColors.textTertiary, fontSize: 12)', 'style: const TextStyle(color: Colors.black87, fontSize: 12)')
content = content.replace('hintStyle: const TextStyle(color: AppColors.textTertiary, fontSize: 12)', 'hintStyle: const TextStyle(color: Colors.black87, fontSize: 12)')
content = content.replace('hintStyle: TextStyle(color: AppColors.textTertiary, fontSize: 12)', 'hintStyle: const TextStyle(color: Colors.black87, fontSize: 12)')

content = content.replace('color: AppColors.textTertiary, fontSize: 13', 'color: Colors.black87, fontSize: 13')
content = content.replace('fontSize: 13, color: AppColors.textTertiary', 'fontSize: 13, color: Colors.black87')
content = content.replace('color: AppColors.textTertiary, fontSize: 12', 'color: Colors.black87, fontSize: 12')
content = content.replace('fontSize: 12, color: AppColors.textTertiary', 'fontSize: 12, color: Colors.black87')

with open(file_path, "w", encoding="utf-8") as f:
    f.write(content)
