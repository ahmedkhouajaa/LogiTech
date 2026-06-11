import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../../database/database_helper.dart';
import '../../models/quote.dart';

abstract class QuotesEvent extends Equatable { const QuotesEvent(); @override List<Object?> get props => []; }
class LoadQuotes extends QuotesEvent {}
class AddQuote extends QuotesEvent { final Quote quote; const AddQuote(this.quote); @override List<Object?> get props => [quote]; }
class UpdateQuote extends QuotesEvent { final Quote quote; const UpdateQuote(this.quote); @override List<Object?> get props => [quote]; }
class DeleteQuote extends QuotesEvent { final String id; const DeleteQuote(this.id); @override List<Object?> get props => [id]; }

abstract class QuotesState extends Equatable { const QuotesState(); @override List<Object?> get props => []; }
class QuotesInitial extends QuotesState {}
class QuotesLoading extends QuotesState {}
class QuotesLoaded extends QuotesState { final List<Quote> quotes; const QuotesLoaded(this.quotes); @override List<Object?> get props => [quotes]; }
class QuotesError extends QuotesState { final String message; const QuotesError(this.message); @override List<Object?> get props => [message]; }

class QuotesBloc extends Bloc<QuotesEvent, QuotesState> {
  QuotesBloc() : super(QuotesInitial()) {
    on<LoadQuotes>(_onLoad);
    on<AddQuote>(_onAdd);
    on<UpdateQuote>(_onUpdate);
    on<DeleteQuote>(_onDelete);
  }

  Future<void> _onLoad(LoadQuotes event, Emitter<QuotesState> emit) async {
    emit(QuotesLoading());
    try { emit(QuotesLoaded(await DatabaseHelper.instance.getQuotes())); } catch (e) { emit(QuotesError(e.toString())); }
  }
  Future<void> _onAdd(AddQuote event, Emitter<QuotesState> emit) async {
    try { await DatabaseHelper.instance.insertQuote(event.quote); add(LoadQuotes()); } catch (e) { emit(QuotesError(e.toString())); }
  }
  Future<void> _onUpdate(UpdateQuote event, Emitter<QuotesState> emit) async {
    try { await DatabaseHelper.instance.update('quotes', event.quote.toMap(), event.quote.id); add(LoadQuotes()); } catch (e) { emit(QuotesError(e.toString())); }
  }
  Future<void> _onDelete(DeleteQuote event, Emitter<QuotesState> emit) async {
    try { await DatabaseHelper.instance.softDelete('quotes', event.id); add(LoadQuotes()); } catch (e) { emit(QuotesError(e.toString())); }
  }
}
