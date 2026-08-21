import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';

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
import 'blocs/user_management/user_management_bloc.dart';
import 'blocs/theme/theme_cubit.dart';
import 'services/auth_service.dart';
import 'services/enterprise_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'database/database_helper.dart';
import 'utils/constants.dart';

import 'screens/login_screen.dart';
import 'screens/app_shell_screen.dart';
import 'screens/onboarding_enterprise_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/account_deactivated_screen.dart';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_web_plugins/url_strategy.dart';

import 'dart:ui';
import 'utils/platform_utils.dart';
import 'mobile/mobile_login_screen.dart';
import 'mobile/mobile_shell_screen.dart';
import 'services/migration_service.dart';
import 'services/security/security_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  if (kIsWeb) {
    usePathUrlStrategy();
  }
  
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

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e, stack) {
    print('FIREBASE INIT ERROR: $e');
    print(stack);
  }

  // Initialize Security Engine (License verification & DPAPI storage)
  try {
    await SecurityManager.instance.initialize();
  } catch (e, stack) {
    print('SECURITY INIT ERROR: $e');
    print(stack);
  }

  // Initialize enterprise service (loads cached enterprise from SharedPreferences)
  try {
    await EnterpriseService.instance.initialize();
    await MigrationService.instance.runEnterpriseMigration();
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
        BlocProvider(create: (_) => StockEntriesBloc()..add(const LoadFirstStockEntries())),
        BlocProvider(create: (_) => TransactionsBloc()),
        BlocProvider(create: (_) => ProjectsBloc()),
        BlocProvider(create: (_) => PaymentsBloc()),
        BlocProvider(create: (_) => TreasuryAccountsBloc(databaseHelper: DatabaseHelper.instance)..add(LoadTreasuryAccounts())),
        BlocProvider(create: (_) => TreasuryTransactionsBloc(databaseHelper: DatabaseHelper.instance)..add(const LoadTreasuryTransactions())),
        BlocProvider(create: (_) => ChecksTraitesBloc(databaseHelper: DatabaseHelper.instance)..add(LoadChecksTraites())),
        BlocProvider(create: (_) => ReturnNotesBloc()),
        BlocProvider(create: (_) => SupplierReturnsBloc()..add(const LoadFirstSupplierReturns())),
        BlocProvider(create: (_) => SupplierCreditNotesBloc()..add(const LoadFirstSupplierCreditNotes())),
        BlocProvider(create: (_) => CreditNotesBloc()..add(LoadCreditNotes())),
        BlocProvider(create: (_) => ProductSettingsBloc()..add(LoadFamilies())),
        BlocProvider(create: (_) => DocumentTemplatesBloc()..add(LoadDocumentTemplates())),
        BlocProvider(create: (_) => WarehousesBloc()..add(LoadWarehouses())),
        BlocProvider(create: (_) => InventorySheetsBloc(databaseHelper: DatabaseHelper.instance)..add(InventorySheetsLoadRequested())),
        BlocProvider(create: (_) => ReportsBloc()..add(ReportsRefreshRequested(dateRange: 'Cette Année'))),
        BlocProvider(create: (_) => RetenueSourceVenteBloc()),
        BlocProvider(create: (_) => UserManagementBloc()),
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
            onGenerateRoute: (settings) {
              if (settings.name != null) {
                final uri = Uri.tryParse(settings.name!);
                if (uri != null) {
                  final mode = uri.queryParameters['mode'];
                  final oobCode = uri.queryParameters['oobCode'] ?? uri.queryParameters['code'];
                  if (mode == 'resetPassword' && oobCode != null && oobCode.isNotEmpty) {
                    return MaterialPageRoute(
                      builder: (_) => ResetPasswordScreen(actionCode: oobCode),
                    );
                  }
                  if (uri.path.contains('reset-password')) {
                    final code = uri.queryParameters['code'] ?? uri.queryParameters['oobCode'] ?? '';
                    return MaterialPageRoute(
                      builder: (_) => ResetPasswordScreen(actionCode: code),
                    );
                  }
                  if (uri.path.contains('forgot-password')) {
                    return MaterialPageRoute(
                      builder: (_) => const ForgotPasswordScreen(),
                    );
                  }
                }
              }
              return null;
            },
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
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primary.withValues(alpha: 0.12),
        onPrimaryContainer: AppColors.primary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
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
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: AppColors.border),
        ),
        headerBackgroundColor: AppColors.primary,
        headerForegroundColor: Colors.white,
        headerHeadlineStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.2,
        ),
        headerHelpStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.9),
          letterSpacing: 0,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return null;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          if (states.contains(WidgetState.disabled)) {
            return AppColors.textTertiary;
          }
          return AppColors.textPrimary;
        }),
        dayOverlayColor: WidgetStateProperty.all(
          AppColors.primary.withValues(alpha: 0.1),
        ),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.primary.withValues(alpha: 0.12);
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.primary;
        }),
        todayBorder: BorderSide(color: AppColors.primary, width: 1.5),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return null;
        }),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.textPrimary;
        }),
        confirmButtonStyle: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.primary),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        cancelButtonStyle: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.textSecondary),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: AppColors.border),
        ),
        dayPeriodColor: AppColors.primary.withValues(alpha: 0.15),
        dayPeriodTextColor: AppColors.primary,
        dialHandColor: AppColors.primary,
        dialBackgroundColor: AppColors.surfaceAlt,
        dialTextColor: AppColors.textPrimary,
        entryModeIconColor: AppColors.primary,
        hourMinuteColor: AppColors.surfaceAlt,
        hourMinuteTextColor: AppColors.primary,
        confirmButtonStyle: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.primary),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        cancelButtonStyle: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.textSecondary),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
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
        primary: AppColors.primary,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primary.withValues(alpha: 0.2),
        onPrimaryContainer: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
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
      datePickerTheme: DatePickerThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: AppColors.border),
        ),
        headerBackgroundColor: AppColors.primary,
        headerForegroundColor: Colors.white,
        headerHeadlineStyle: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          height: 1.2,
        ),
        headerHelpStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: Colors.white.withValues(alpha: 0.9),
          letterSpacing: 0,
        ),
        dayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return null;
        }),
        dayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          if (states.contains(WidgetState.disabled)) {
            return AppColors.textTertiary;
          }
          return AppColors.textPrimary;
        }),
        dayOverlayColor: WidgetStateProperty.all(
          AppColors.primary.withValues(alpha: 0.15),
        ),
        todayBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return AppColors.primary.withValues(alpha: 0.2);
        }),
        todayForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.primaryLight;
        }),
        todayBorder: BorderSide(color: AppColors.primaryLight, width: 1.5),
        yearBackgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return null;
        }),
        yearForegroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return AppColors.textPrimary;
        }),
        confirmButtonStyle: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.primaryLight),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        cancelButtonStyle: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.textSecondary),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
      ),
      timePickerTheme: TimePickerThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(color: AppColors.border),
        ),
        dayPeriodColor: AppColors.primary.withValues(alpha: 0.2),
        dayPeriodTextColor: AppColors.primaryLight,
        dialHandColor: AppColors.primary,
        dialBackgroundColor: AppColors.surfaceAlt,
        dialTextColor: AppColors.textPrimary,
        entryModeIconColor: AppColors.primaryLight,
        hourMinuteColor: AppColors.surfaceAlt,
        hourMinuteTextColor: AppColors.primaryLight,
        confirmButtonStyle: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.primaryLight),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        cancelButtonStyle: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(AppColors.textSecondary),
          textStyle: const WidgetStatePropertyAll(
            TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ),
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
        if (authState is AuthInitial) {
          return Scaffold(
            backgroundColor: AppColors.sidebarBg,
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  const Text('Chargement...', style: TextStyle(color: Colors.white60, fontSize: 14)),
                ],
              ),
            ),
          );
        }
        if (authState is AuthAccountDeactivated) {
          return AccountDeactivatedScreen(reason: authState.reason);
        }
        if (authState is AuthAuthenticated) {
          return const _EnterpriseGate();
        }
        return const _ResponsiveLoginGate();
      },
    );
  }
}

class _ResponsiveLoginGate extends StatelessWidget {
  const _ResponsiveLoginGate();

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isAndroid) return const MobileLoginScreen();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 850 && !PlatformUtils.isDesktop) {
          return const MobileLoginScreen();
        }
        return const LoginScreen();
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
    // Only trigger LoadEnterprises if not already loaded with a valid enterprise
    final currentBlocState = context.read<EnterpriseBloc>().state;
    if (currentBlocState is! EnterpriseLoaded || currentBlocState.currentEnterpriseId == null) {
      context.read<EnterpriseBloc>().add(LoadEnterprises());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<EnterpriseBloc, EnterpriseState>(
      listener: (context, state) {
        if (state is EnterpriseLoaded && state.currentEnterpriseId != null && state.currentEnterpriseId!.isNotEmpty) {
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
        Widget content;
        if (state is EnterpriseLoading || state is EnterpriseInitial) {
          content = const _EnterpriseSplashLoadingScreen(
            key: ValueKey('enterprise_loading'),
            message: 'Chargement de l\'entreprise...',
          );
        } else if (state is EnterpriseSwitching) {
          content = const _EnterpriseSplashLoadingScreen(
            key: ValueKey('enterprise_switching'),
            message: 'Changement d\'entreprise...',
          );
        } else if (state is EnterpriseError) {
          content = _EnterpriseErrorScreen(
            key: const ValueKey('enterprise_error'),
            message: state.message,
            onRetry: () => context.read<EnterpriseBloc>().add(LoadEnterprises()),
          );
        } else if (state is EnterpriseLoaded) {
          if (state.enterprises.isEmpty || state.currentEnterpriseId == null || state.currentEnterpriseId!.isEmpty) {
            content = const OnboardingEnterpriseScreen(
              key: ValueKey('enterprise_onboarding'),
            );
          } else {
            content = KeyedSubtree(
              key: ValueKey('shell_${state.currentEnterpriseId}'),
              child: const _ResponsiveShellGate(),
            );
          }
        } else {
          content = const _EnterpriseSplashLoadingScreen(
            key: ValueKey('enterprise_loading_fallback'),
            message: 'Chargement de l\'entreprise...',
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: content,
        );
      },
    );
  }
}

class _EnterpriseSplashLoadingScreen extends StatelessWidget {
  final String message;
  const _EnterpriseSplashLoadingScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.sidebarBg,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.primary),
            const SizedBox(height: 16),
            Text(
              message,
              style: const TextStyle(color: Colors.white60, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _EnterpriseErrorScreen extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _EnterpriseErrorScreen({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          constraints: const BoxConstraints(maxWidth: 440),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF334155)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.cloud_off_rounded, color: AppColors.error, size: 32),
              ),
              const SizedBox(height: 20),
              const Text(
                'Impossible de charger l\'entreprise',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: const TextStyle(color: Colors.white60, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => context.read<AuthBloc>().add(AuthLogoutRequested()),
                    icon: const Icon(Icons.logout_rounded, size: 16, color: Colors.white70),
                    label: const Text('Déconnexion', style: TextStyle(color: Colors.white70)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFF475569)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Réessayer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsiveShellGate extends StatelessWidget {
  const _ResponsiveShellGate();

  @override
  Widget build(BuildContext context) {
    if (PlatformUtils.isAndroid) return const MobileShellScreen();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 850 && !PlatformUtils.isDesktop) {
          return const MobileShellScreen();
        }
        return const AppShellScreen();
      },
    );
  }
}
