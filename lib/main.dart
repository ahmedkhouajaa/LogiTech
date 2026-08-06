import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'blocs/auth/auth_bloc.dart';
import 'blocs/customers/customers_bloc.dart';
import 'blocs/suppliers/suppliers_bloc.dart';
import 'blocs/products/products_bloc.dart';
import 'blocs/invoices/invoices_bloc.dart';
import 'blocs/customer_orders/customer_orders_bloc.dart';
import 'blocs/delivery_notes/delivery_notes_bloc.dart';
import 'blocs/supplier_orders/supplier_orders_bloc.dart';
import 'blocs/purchase_invoices/purchase_invoices_bloc.dart';
import 'blocs/receiving_vouchers/receiving_vouchers_bloc.dart';
import 'blocs/stock_withdrawals/stock_withdrawals_bloc.dart';
import 'blocs/exit_vouchers/exit_vouchers_bloc.dart';
import 'blocs/stock_transfers/stock_transfers_bloc.dart';
import 'blocs/stock_entries/stock_entries_bloc.dart';
import 'blocs/credit_notes/credit_notes_bloc.dart';
import 'blocs/quotes/quotes_bloc.dart';
import 'blocs/stock/stock_bloc.dart';
import 'blocs/dashboard/dashboard_bloc.dart';
import 'blocs/transactions/transactions_bloc.dart';
import 'blocs/projects/projects_bloc.dart';
import 'blocs/payments/payments_bloc.dart';
import 'blocs/treasury_accounts/treasury_accounts_bloc.dart';
import 'blocs/treasury_transactions/treasury_transactions_bloc.dart';
import 'blocs/reports/reports_bloc.dart';
import 'blocs/retenue_source_vente/retenue_source_vente_bloc.dart';
import 'blocs/checks_traites/checks_traites_bloc.dart';
import 'blocs/return_notes/return_notes_bloc.dart';
import 'blocs/return_notes/return_notes_event.dart';
import 'blocs/stock_entries/stock_entries_event.dart';
import 'blocs/supplier_returns/supplier_returns_bloc.dart';
import 'blocs/supplier_returns/supplier_returns_event.dart';
import 'blocs/supplier_credit_notes/supplier_credit_notes_bloc.dart';
import 'blocs/supplier_credit_notes/supplier_credit_notes_event.dart';
import 'blocs/product_settings/product_settings_bloc.dart';
import 'blocs/product_settings/product_settings_event.dart';
import 'blocs/document_templates/document_templates_bloc.dart';
import 'blocs/warehouses/warehouses_bloc.dart';
import 'blocs/warehouses/warehouses_event.dart';
import 'blocs/inventory_sheets/inventory_sheets_bloc.dart';
import 'blocs/inventory_sheets/inventory_sheets_event.dart';
import 'blocs/enterprise/enterprise_bloc.dart';
import 'blocs/theme/theme_cubit.dart';
import 'services/auth_service.dart';
import 'services/enterprise_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'database/database_helper.dart';
import 'utils/constants.dart';

import 'screens/login_screen.dart';
import 'screens/app_shell_screen.dart';

import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'dart:ui';
import 'utils/platform_utils.dart';
import 'mobile/mobile_login_screen.dart';
import 'mobile/mobile_shell_screen.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  FlutterError.onError = (FlutterErrorDetails details) {
    print('FLUTTER ERROR: ${details.exception}');
    print(details.stack);
  };
  
  PlatformDispatcher.instance.onError = (error, stack) {
    print('PLATFORM ERROR: $error');
    print(stack);
    return true;
  };

  await initializeDateFormatting('fr_FR', null);
  
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, stack) {
    print('FIREBASE INIT ERROR: $e');
    print(stack);
  }

  // Initialize enterprise service (loads cached enterprise from SharedPreferences)
  try {
    await EnterpriseService.instance.initialize();
  } catch (e, stack) {
    print('ENTERPRISE SERVICE INIT ERROR: $e');
    print(stack);
  }

  // Initialize services
  try {
    await ConnectivityService.instance.initialize();
  } catch (e, stack) {
    print('CONNECTIVITY INIT ERROR: $e');
    print(stack);
  }
  
  try {
    SyncService.instance.startPeriodicSync();
  } catch (e, stack) {
    print('SYNC INIT ERROR: $e');
    print(stack);
  }

  // Warm up the database
  try {
    await DatabaseHelper.instance.database;
    print('Database initialized successfully.');
  } catch (e, stack) {
    print('DATABASE INIT ERROR: $e');
    print(stack);
  }

  runApp(const BusinessManagerApp());
}

class BusinessManagerApp extends StatelessWidget {
  const BusinessManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => AuthBloc(authService: AuthService.instance)..add(AuthCheckRequested())),
        BlocProvider(create: (_) => EnterpriseBloc()),
        BlocProvider(create: (_) => DashboardBloc()),
        BlocProvider(create: (_) => CustomersBloc()),
        BlocProvider(create: (_) => SuppliersBloc()),
        BlocProvider(create: (_) => ProductsBloc()),
        BlocProvider(create: (_) => InvoicesBloc()),
        BlocProvider(create: (_) => CustomerOrdersBloc()),
        BlocProvider(create: (_) => DeliveryNotesBloc()),
        BlocProvider(create: (_) => SupplierOrdersBloc()),
        BlocProvider(create: (_) => ReceivingVouchersBloc()),
        BlocProvider(create: (_) => StockWithdrawalsBloc()),
        BlocProvider(create: (_) => PurchaseInvoicesBloc()),
        BlocProvider(create: (_) => QuotesBloc()),
        BlocProvider(create: (_) => StockBloc()),
        BlocProvider(create: (_) => StockWithdrawalsBloc()),
        BlocProvider(create: (_) => ExitVouchersBloc()),
        BlocProvider(create: (_) => StockTransfersBloc()),
        BlocProvider(create: (_) => StockEntriesBloc()),
        BlocProvider(create: (_) => TransactionsBloc()),
        BlocProvider(create: (_) => ProjectsBloc()),
        BlocProvider(create: (_) => PaymentsBloc()),
        BlocProvider(create: (_) => TreasuryAccountsBloc(databaseHelper: DatabaseHelper.instance)..add(LoadTreasuryAccounts())),
        BlocProvider(create: (_) => TreasuryTransactionsBloc(databaseHelper: DatabaseHelper.instance)..add(const LoadTreasuryTransactions())),
        BlocProvider(create: (_) => ChecksTraitesBloc(databaseHelper: DatabaseHelper.instance)..add(LoadChecksTraites())),
        BlocProvider(create: (_) => ReturnNotesBloc()),
        BlocProvider(create: (_) => SupplierReturnsBloc(DatabaseHelper.instance)..add(LoadSupplierReturns())),
        BlocProvider(create: (_) => SupplierCreditNotesBloc(DatabaseHelper.instance)..add(LoadSupplierCreditNotes())),
        BlocProvider(create: (_) => CreditNotesBloc()..add(LoadCreditNotes())),
        BlocProvider(create: (_) => ProductSettingsBloc()..add(LoadFamilies())),
        BlocProvider(create: (_) => DocumentTemplatesBloc()..add(LoadDocumentTemplates())),
        BlocProvider(create: (_) => WarehousesBloc()..add(LoadWarehouses())),
        BlocProvider(create: (_) => InventorySheetsBloc(databaseHelper: DatabaseHelper.instance)..add(InventorySheetsLoadRequested())),
        BlocProvider(create: (_) => ReportsBloc()..add(ReportsRefreshRequested(dateRange: 'Cette Année'))),
        BlocProvider(create: (_) => RetenueSourceVenteBloc()),
        BlocProvider(create: (_) => ThemeCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          AppColors.isDarkMode = themeMode == ThemeMode.dark;
          return MaterialApp(
            key: ValueKey(themeMode),
            title: 'LogiTech Pro',
            debugShowCheckedModeBanner: false,
            theme: _buildTheme(),
            darkTheme: _buildDarkTheme(),
            themeMode: themeMode,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('fr', 'FR'),
              Locale('en', 'US'),
            ],
            home: const _AppGate(),
          );
        },
      ),
    );
  }

  ThemeData _buildTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        surface: AppColors.surface,
        surfaceContainerHighest: AppColors.surfaceAlt,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: AppColors.background,
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 2)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        brightness: Brightness.dark,
        seedColor: AppColors.primary,
        surface: AppColors.surface,
        surfaceContainerHighest: AppColors.surfaceAlt,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData(brightness: Brightness.dark).textTheme).copyWith(
        bodyLarge: TextStyle(color: AppColors.textPrimary),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
      ),
      scaffoldBackgroundColor: AppColors.background,
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(color: AppColors.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
        elevation: 8,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceAlt,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppRadius.md), borderSide: BorderSide(color: AppColors.primary, width: 2)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        if (authState is AuthLoading || authState is AuthInitial) {
          return Scaffold(
            backgroundColor: AppColors.sidebarBg,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Chargement...', style: TextStyle(color: Colors.white60, fontSize: 14)),
                ],
              ),
            ),
          );
        }
        if (authState is AuthAuthenticated) {
          return const _EnterpriseGate();
        }
        return PlatformUtils.isAndroid ? const MobileLoginScreen() : const LoginScreen();
      },
    );
  }
}

/// Gate that loads enterprises after authentication, then shows the app shell.
/// Uses a [KeyedSubtree] keyed on the enterprise ID so switching enterprises
/// rebuilds the entire widget tree (recreating all blocs with fresh data).
class _EnterpriseGate extends StatefulWidget {
  const _EnterpriseGate();

  @override
  State<_EnterpriseGate> createState() => _EnterpriseGateState();
}

class _EnterpriseGateState extends State<_EnterpriseGate> {
  @override
  void initState() {
    super.initState();
    // Trigger enterprise load when this widget first appears
    context.read<EnterpriseBloc>().add(LoadEnterprises());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EnterpriseBloc, EnterpriseState>(
      listener: (context, state) {
        if (state is EnterpriseLoaded && state.currentEnterpriseId != null) {
          // Re-fetch enterprise-scoped data across ALL BLoCs
          context.read<DashboardBloc>().add(DashboardRefreshRequested());
          context.read<InvoicesBloc>().add(LoadInvoices());
          context.read<CustomersBloc>().add(LoadCustomers());
          context.read<SuppliersBloc>().add(LoadSuppliers());
          context.read<ProductsBloc>().add(LoadProducts());
          context.read<QuotesBloc>().add(LoadQuotes());
          context.read<CustomerOrdersBloc>().add(LoadCustomerOrders());
          context.read<DeliveryNotesBloc>().add(LoadDeliveryNotes());
          context.read<SupplierOrdersBloc>().add(LoadSupplierOrders());
          context.read<PurchaseInvoicesBloc>().add(LoadPurchaseInvoices());
          context.read<ReceivingVouchersBloc>().add(LoadReceivingVouchers());
          context.read<StockWithdrawalsBloc>().add(LoadStockWithdrawals());
          context.read<ExitVouchersBloc>().add(LoadExitVouchers());
          context.read<CreditNotesBloc>().add(LoadCreditNotes());
          context.read<ReturnNotesBloc>().add(LoadReturnNotes());
          context.read<SupplierReturnsBloc>().add(LoadSupplierReturns());
          context.read<SupplierCreditNotesBloc>().add(LoadSupplierCreditNotes());
          context.read<PaymentsBloc>().add(LoadPayments());
          context.read<TransactionsBloc>().add(LoadTransactions());
          context.read<ProjectsBloc>().add(LoadProjects());
          context.read<StockBloc>().add(LoadStock());
          context.read<StockTransfersBloc>().add(LoadStockTransfers());
          context.read<StockEntriesBloc>().add(LoadStockEntries());
          context.read<ChecksTraitesBloc>().add(LoadChecksTraites());
          context.read<TreasuryAccountsBloc>().add(LoadTreasuryAccounts());
          context.read<TreasuryTransactionsBloc>().add(const LoadTreasuryTransactions());
          context.read<WarehousesBloc>().add(LoadWarehouses());
          context.read<InventorySheetsBloc>().add(InventorySheetsLoadRequested());
          context.read<ProductSettingsBloc>().add(LoadFamilies());
          context.read<ReportsBloc>().add(ReportsRefreshRequested(dateRange: 'Cette Année'));
        }
      },
      builder: (context, state) {
        if (state is EnterpriseLoading || state is EnterpriseInitial) {
          return Scaffold(
            backgroundColor: AppColors.sidebarBg,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Chargement de l\'entreprise...', style: TextStyle(color: Colors.white60, fontSize: 14)),
                ],
              ),
            ),
          );
        }
        if (state is EnterpriseSwitching) {
          return Scaffold(
            backgroundColor: AppColors.sidebarBg,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  SizedBox(height: 16),
                  Text('Changement d\'entreprise...', style: TextStyle(color: Colors.white60, fontSize: 14)),
                ],
              ),
            ),
          );
        }
        if (state is EnterpriseLoaded && state.currentEnterpriseId != null) {
          // KeyedSubtree: changing the key forces a full rebuild of the UI shell
          return KeyedSubtree(
            key: ValueKey(state.currentEnterpriseId),
            child: PlatformUtils.isAndroid ? const MobileShellScreen() : const AppShellScreen(),
          );
        }
        // Error or no enterprise — show error with retry
        return Scaffold(
          backgroundColor: AppColors.sidebarBg,
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business_rounded, color: Colors.white38, size: 48),
                SizedBox(height: 16),
                Text(
                  state is EnterpriseError ? state.message : 'Aucune entreprise trouvée',
                  style: TextStyle(color: Colors.white60, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.read<EnterpriseBloc>().add(LoadEnterprises()),
                  child: Text('Réessayer'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
