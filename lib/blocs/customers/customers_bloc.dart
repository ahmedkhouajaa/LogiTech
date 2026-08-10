import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';
import '../../services/firestore_repository.dart';
import '../../database/database_helper.dart';
import '../../models/customer.dart';
import '../../services/firestore_pagination_service.dart';
import '../../services/enterprise_service.dart';

// Events
abstract class CustomersEvent extends Equatable {
  const CustomersEvent();
  @override
  List<Object?> get props => [];
}

class LoadCustomers extends CustomersEvent {}

class LoadFirstClients extends CustomersEvent {
  final String? searchQuery;
  const LoadFirstClients({this.searchQuery});
  @override
  List<Object?> get props => [searchQuery];
}

class LoadNextClients extends CustomersEvent {
  final String? searchQuery;
  const LoadNextClients({this.searchQuery});
  @override
  List<Object?> get props => [searchQuery];
}

class ResetClientsPagination extends CustomersEvent {
  final String? searchQuery;
  const ResetClientsPagination({this.searchQuery});
  @override
  List<Object?> get props => [searchQuery];
}

class AddCustomer extends CustomersEvent {
  final Customer customer;
  const AddCustomer(this.customer);
  @override
  List<Object?> get props => [customer];
}

class UpdateCustomer extends CustomersEvent {
  final Customer customer;
  const UpdateCustomer(this.customer);
  @override
  List<Object?> get props => [customer];
}

class DeleteCustomer extends CustomersEvent {
  final String id;
  const DeleteCustomer(this.id);
  @override
  List<Object?> get props => [id];
}

// States
abstract class CustomersState extends Equatable {
  const CustomersState();
  @override
  List<Object?> get props => [];
}

class CustomersInitial extends CustomersState {}
class CustomersLoading extends CustomersState {}
class CustomersLoaded extends CustomersState {
  final List<Customer> customers;
  final int? _totalCount;
  final bool? _hasMore;
  final bool? _isLoadingMore;

  int get totalCount => _totalCount ?? 0;
  bool get hasMore => _hasMore ?? true;
  bool get isLoadingMore => _isLoadingMore ?? false;

  const CustomersLoaded(
    this.customers, {
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  })  : _totalCount = totalCount,
        _hasMore = hasMore,
        _isLoadingMore = isLoadingMore;

  CustomersLoaded copyWith({
    List<Customer>? customers,
    int? totalCount,
    bool? hasMore,
    bool? isLoadingMore,
  }) {
    return CustomersLoaded(
      customers ?? this.customers,
      totalCount: totalCount ?? this.totalCount,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    );
  }

  @override
  List<Object?> get props => [customers, _totalCount, _hasMore, _isLoadingMore];
}

class CustomersError extends CustomersState {
  final String message;
  const CustomersError(this.message);
  @override
  List<Object?> get props => [message];
}

// BLoC
class CustomersBloc extends Bloc<CustomersEvent, CustomersState> {
  CustomersBloc() : super(CustomersInitial()) {
    on<LoadCustomers>(_onLoadCustomers);
    on<LoadFirstClients>(_onLoadFirstClients);
    on<LoadNextClients>(_onLoadNextClients);
    on<ResetClientsPagination>(_onResetClientsPagination);
    on<AddCustomer>(_onAddCustomer);
    on<UpdateCustomer>(_onUpdateCustomer);
    on<DeleteCustomer>(_onDeleteCustomer);
  }

  Future<void> _onLoadCustomers(LoadCustomers event, Emitter<CustomersState> emit) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;

    // Show loading while we fetch from Firestore
    emit(CustomersLoading());

    Query buildQuery() {
      Query query = FirebaseFirestore.instance.collection('clients');
      if (currentEntId != null && currentEntId.isNotEmpty) {
        query = query.where('enterprise_id', isEqualTo: currentEntId);
      } else if (uid != null && uid.isNotEmpty) {
        query = query.where('userId', isEqualTo: uid);
      }
      query = query.where('is_deleted', isEqualTo: 0);
      return query;
    }

    List<Customer> parseSnapshot(QuerySnapshot snapshot) {
      return snapshot.docs.map((doc) {
        final data = Map<String, dynamic>.from(doc.data() as Map<String, dynamic>);
        data['id'] = doc.id;
        data['created_at'] = data['created_at'] ?? DateTime.now().toIso8601String();
        data['updated_at'] = data['updated_at'] ?? DateTime.now().toIso8601String();
        if (!data.containsKey('code') && data.containsKey('clientCode')) {
          data['code'] = data['clientCode'];
        }
        if (!data.containsKey('customer_type') && data.containsKey('type')) {
          data['customer_type'] = data['type'];
        }
        return Customer.fromMap(data);
      }).toList();
    }

    try {
      // Phase 1: Try cache for instant display
      bool shownFromCache = false;
      try {
        final cacheSnapshot = await buildQuery().get(const GetOptions(source: Source.cache));
        if (cacheSnapshot.docs.isNotEmpty && !emit.isDone) {
          final cachedCustomers = parseSnapshot(cacheSnapshot);
          emit(CustomersLoaded(cachedCustomers, totalCount: cachedCustomers.length, hasMore: false));
          shownFromCache = true;
        }
      } catch (_) {
        // Cache unavailable, will fetch from server below
      }

      // Phase 2: Always fetch from server for cross-device sync
      try {
        final serverSnapshot = await buildQuery().get(const GetOptions(source: Source.server));
        List<Customer> customers = parseSnapshot(serverSnapshot);

        // Only create default if server is truly empty for this enterprise
        if (customers.isEmpty && !shownFromCache) {
          final defaultCustomer = Customer(
            id: const Uuid().v4(),
            code: 'CL-001',
            name: 'Client Passager',
            email: 'passager@client.com',
            phone: '',
            address: 'Passager',
            city: '',
            taxId: '',
            rc: '',
            balance: 0.0,
            creditLimit: 0.0,
            isDeleted: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
            enterpriseId: currentEntId,
          );
          customers = [defaultCustomer];

          FirestoreRepository.instance
              .saveDocument('clients', defaultCustomer.id, defaultCustomer.toMap())
              .catchError((e) => print("Firestore default customer auto-create error: $e"));
        }

        if (!emit.isDone) {
          emit(CustomersLoaded(customers, totalCount: customers.length, hasMore: false));
        }
      } catch (e) {
        // Server fetch failed; if we already showed cache data, that's fine
        if (!shownFromCache && !emit.isDone) {
          emit(CustomersLoaded([], totalCount: 0, hasMore: false));
        }
      }
    } catch (e) {
      if (!emit.isDone) {
        emit(CustomersLoaded([], totalCount: 0, hasMore: false));
      }
    }
  }

  Future<void> _onLoadFirstClients(LoadFirstClients event, Emitter<CustomersState> emit) async {
    emit(CustomersLoading());
    try {
      FirestorePaginationService.instance.resetCustomersPagination();
      final clientsFuture = FirestorePaginationService.instance.getFirstCustomers(
        pageSize: 10,
        searchQuery: event.searchQuery,
      );
      final countFuture = FirestorePaginationService.instance.getCustomersCount(
        searchQuery: event.searchQuery,
      );

      final results = await Future.wait([clientsFuture, countFuture]);
      final clients = results[0] as List<Customer>;
      final totalCount = results[1] as int;

      emit(CustomersLoaded(
        clients,
        totalCount: totalCount > clients.length ? totalCount : clients.length,
        hasMore: clients.length >= 10,
      ));
    } catch (e) {
      emit(CustomersError(e.toString()));
    }
  }

  Future<void> _onLoadNextClients(LoadNextClients event, Emitter<CustomersState> emit) async {
    final currentState = state;
    if (currentState is! CustomersLoaded || currentState.isLoadingMore || !currentState.hasMore) return;

    emit(currentState.copyWith(isLoadingMore: true));
    try {
      final nextClients = await FirestorePaginationService.instance.getNextCustomers(
        pageSize: 10,
        currentOffset: currentState.customers.length,
        searchQuery: event.searchQuery,
      );

      if (nextClients.isEmpty) {
        emit(currentState.copyWith(hasMore: false, isLoadingMore: false));
      } else {
        final updatedList = List<Customer>.from(currentState.customers)..addAll(nextClients);
        emit(CustomersLoaded(
          updatedList,
          totalCount: currentState.totalCount > updatedList.length ? currentState.totalCount : updatedList.length,
          hasMore: nextClients.length >= 10,
          isLoadingMore: false,
        ));
      }
    } catch (e) {
      emit(currentState.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onResetClientsPagination(ResetClientsPagination event, Emitter<CustomersState> emit) async {
    FirestorePaginationService.instance.resetCustomersPagination();
    add(LoadFirstClients(searchQuery: event.searchQuery));
  }

  Future<void> _onAddCustomer(AddCustomer event, Emitter<CustomersState> emit) async {
    final currentEntId = EnterpriseService.instance.currentEnterpriseId;

    String finalCode = event.customer.code;
    
    // If the code looks like an auto-generated sequence, fetch the next atomic sequence right before saving
    if (finalCode.toUpperCase().startsWith('CL')) {
      try {
        finalCode = await DatabaseHelper.instance.generateNextCustomerSequenceAtomic(currentEntId);
      } catch (e) {
        // Fallback to the code provided if offline
      }
    }

    // Ensure the customer has the current enterpriseId
    final customer = (event.customer.enterpriseId == null || event.customer.enterpriseId!.isEmpty || finalCode != event.customer.code)
        ? Customer(
            id: event.customer.id,
            code: finalCode,
            name: event.customer.name,
            email: event.customer.email,
            phone: event.customer.phone,
            address: event.customer.address,
            city: event.customer.city,
            taxId: event.customer.taxId,
            rc: event.customer.rc,
            balance: event.customer.balance,
            creditLimit: event.customer.creditLimit,
            notes: event.customer.notes,
            firebaseUid: event.customer.firebaseUid,
            enterpriseId: currentEntId,
            isDeleted: event.customer.isDeleted,
            createdAt: event.customer.createdAt,
            updatedAt: event.customer.updatedAt,
            customerType: event.customer.customerType,
            companyName: event.customer.companyName,
            responsibleName: event.customer.responsibleName,
            cinNumber: event.customer.cinNumber,
            birthDate: event.customer.birthDate,
            referenceCode: event.customer.referenceCode,
            streetAddress: event.customer.streetAddress,
            postalCode: event.customer.postalCode,
            country: event.customer.country,
            deliveryStreet: event.customer.deliveryStreet,
            deliveryCity: event.customer.deliveryCity,
            deliveryPostalCode: event.customer.deliveryPostalCode,
            deliveryCountry: event.customer.deliveryCountry,
            deliverySameAsBilling: event.customer.deliverySameAsBilling,
            bankAccount: event.customer.bankAccount,
            tvaSuspension: event.customer.tvaSuspension,
            tvaAttestation: event.customer.tvaAttestation,
            tvaStartDate: event.customer.tvaStartDate,
            tvaEndDate: event.customer.tvaEndDate,
            priceList: event.customer.priceList,
            privateNote: event.customer.privateNote,
          )
        : event.customer;

    final currentState = state;
    List<Customer> currentList = [];
    if (currentState is CustomersLoaded) {
      currentList = List<Customer>.from(currentState.customers);
    }
    currentList.removeWhere((c) => c.id == customer.id);
    currentList.add(customer);
    
    // Maintain list sorted by code ascending
    currentList.sort((a, b) => a.code.compareTo(b.code));
    
    emit(CustomersLoaded(currentList, totalCount: currentList.length, hasMore: false));

    try {
      await FirestoreRepository.instance.saveCustomer(customer);
    } catch (e) {
      print("Failed to save customer to Firestore: $e");
    }
  }

  Future<void> _onUpdateCustomer(UpdateCustomer event, Emitter<CustomersState> emit) async {
    final currentState = state;
    if (currentState is CustomersLoaded) {
      final currentList = List<Customer>.from(currentState.customers);
      currentList.removeWhere((c) => c.id == event.customer.id);
      currentList.add(event.customer);
      
      // Maintain list sorted by code ascending
      currentList.sort((a, b) => a.code.compareTo(b.code));
      
      emit(CustomersLoaded(currentList, totalCount: currentList.length, hasMore: false));
    }

    try {
      await FirestoreRepository.instance.saveCustomer(event.customer);
    } catch (e) {
      print("Failed to update customer in Firestore: $e");
    }
  }

  Future<void> _onDeleteCustomer(DeleteCustomer event, Emitter<CustomersState> emit) async {
    final currentState = state;
    if (currentState is CustomersLoaded) {
      final currentList = List<Customer>.from(currentState.customers)..removeWhere((c) => c.id == event.id);
      emit(CustomersLoaded(currentList, totalCount: currentList.length, hasMore: false));
    }

    try {
      await FirestoreRepository.instance.softDeleteDocument('clients', event.id);
    } catch (e) {
      print("Failed to delete customer in Firestore: $e");
    }
  }
}
