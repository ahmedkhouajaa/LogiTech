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
import 'blocs/checks_traites/checks_traites_bloc.dart';
import 'blocs/return_notes/return_notes_bloc.dart';
import 'blocs/supplier_returns/supplier_returns_bloc.dart';
import 'blocs/supplier_returns/supplier_returns_event.dart';
import 'blocs/supplier_credit_notes/supplier_credit_notes_bloc.dart';
import 'blocs/supplier_credit_notes/supplier_credit_notes_event.dart';
import 'blocs/product_settings/product_settings_bloc.dart';
import 'blocs/product_settings/product_settings_event.dart';
import 'blocs/document_templates/document_templates_bloc.dart';
import 'services/auth_service.dart';
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
      ],
      child: MaterialApp(
        title: 'LogiTech Pro',
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(),
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
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }
}

class _AppGate extends StatelessWidget {
  const _AppGate();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is AuthLoading || state is AuthInitial) {
          return const Scaffold(
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
        if (state is AuthAuthenticated) {
          return PlatformUtils.isAndroid ? const MobileShellScreen() : const AppShellScreen();
        }
        return PlatformUtils.isAndroid ? const MobileLoginScreen() : const LoginScreen();
      },
    );
  }
}
