import re

def process():
    path = 'lib/widgets/searchable_dropdown_field.dart'
    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    # 2. Fix showCustomerSelectDialog
    # Find `return BlocBuilder<CustomersBloc, CustomersState>(` inside `showCustomerSelectDialog`
    target = """          return BlocBuilder<CustomersBloc, CustomersState>(
            builder: (context, state) {
              final customers = state is CustomersLoaded ? state.customers : initialCustomers;
              final query = search.trim().toLowerCase();"""
              
    replacement = """          return BlocBuilder<CustomersBloc, CustomersState>(
            builder: (context, state) {
              final isLoaded = state is CustomersLoaded;
              final customers = isLoaded ? state.customers : initialCustomers;
              
              if (!isLoaded) {
                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  backgroundColor: AppColors.surface,
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text("Chargement des clients...", style: TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                );
              }
              
              final query = search.trim().toLowerCase();"""
    content = content.replace(target, replacement)
    
    # 3. Fix showProjectSelectDialog
    target2 = """          return BlocBuilder<ProjectsBloc, ProjectsState>(
            builder: (context, state) {
              final projects = state is ProjectsLoaded ? state.projects : initialProjects;
              final query = search.trim().toLowerCase();"""
    replacement2 = """          return BlocBuilder<ProjectsBloc, ProjectsState>(
            builder: (context, state) {
              final isLoaded = state is ProjectsLoaded;
              final projects = isLoaded ? state.projects : initialProjects;
              
              if (!isLoaded) {
                return Dialog(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                  backgroundColor: AppColors.surface,
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 16),
                        Text("Chargement des projets...", style: TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                );
              }
              
              final query = search.trim().toLowerCase();"""
    content = content.replace(target2, replacement2)
    
    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("Done Customer & Project")

if __name__ == '__main__':
    process()
