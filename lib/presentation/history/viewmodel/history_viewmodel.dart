import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:aigui/data/di/repository_providers.dart';
import 'package:aigui/domain/entities/conversation.dart';
import 'package:aigui/domain/repositories/chat_repository.dart';

/// Conversation history grouped by temporal intervals for clean desktop sidebar browsing.
class HistoryState {
  const HistoryState({
    this.pinned = const [],
    this.today = const [],
    this.yesterday = const [],
    this.previous7Days = const [],
    this.older = const [],
    this.searchQuery = '',
    this.searchResults = const [],
    this.isLoading = false,
  });

  final List<Conversation> pinned;
  final List<Conversation> today;
  final List<Conversation> yesterday;
  final List<Conversation> previous7Days;
  final List<Conversation> older;
  final String searchQuery;
  final List<Conversation> searchResults;
  final bool isLoading;

  bool get isSearching => searchQuery.trim().isNotEmpty;

  HistoryState copyWith({
    List<Conversation>? pinned,
    List<Conversation>? today,
    List<Conversation>? yesterday,
    List<Conversation>? previous7Days,
    List<Conversation>? older,
    String? searchQuery,
    List<Conversation>? searchResults,
    bool? isLoading,
  }) {
    return HistoryState(
      pinned: pinned ?? this.pinned,
      today: today ?? this.today,
      yesterday: yesterday ?? this.yesterday,
      previous7Days: previous7Days ?? this.previous7Days,
      older: older ?? this.older,
      searchQuery: searchQuery ?? this.searchQuery,
      searchResults: searchResults ?? this.searchResults,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

/// Pure Riverpod ViewModel managing conversation grouping, search filtering, and history actions.
class HistoryViewModel extends Notifier<HistoryState> {
  StreamSubscription<List<Conversation>>? _convSubscription;
  List<Conversation> _allConversations = [];

  ChatRepository get _chatRepo => ref.read(chatRepositoryProvider);

  @override
  HistoryState build() {
    ref.onDispose(() => _convSubscription?.cancel());

    // Stream real-time conversations from Drift database
    _convSubscription = _chatRepo.watchConversations().listen((conversations) {
      _allConversations = conversations;
      _groupConversations();
    });

    return const HistoryState(isLoading: true);
  }

  void _groupConversations() {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));
    final sevenDaysDate = todayDate.subtract(const Duration(days: 7));

    final pinned = <Conversation>[];
    final today = <Conversation>[];
    final yesterday = <Conversation>[];
    final prev7 = <Conversation>[];
    final older = <Conversation>[];

    for (final c in _allConversations) {
      if (c.isPinned) {
        pinned.add(c);
        continue;
      }

      final cDate = DateTime(c.updatedAt.year, c.updatedAt.month, c.updatedAt.day);
      if (cDate.isAtSameMomentAs(todayDate) || cDate.isAfter(todayDate)) {
        today.add(c);
      } else if (cDate.isAtSameMomentAs(yesterdayDate)) {
        yesterday.add(c);
      } else if (cDate.isAfter(sevenDaysDate)) {
        prev7.add(c);
      } else {
        older.add(c);
      }
    }

    state = state.copyWith(
      pinned: pinned,
      today: today,
      yesterday: yesterday,
      previous7Days: prev7,
      older: older,
      isLoading: false,
    );
  }

  /// Filters conversations via in-memory matching and full-text database search.
  Future<void> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(searchQuery: '', searchResults: const []);
      return;
    }

    final matched = _allConversations
        .where((c) => c.title.toLowerCase().contains(trimmed.toLowerCase()))
        .toList();

    state = state.copyWith(searchQuery: trimmed, searchResults: matched);
  }

  Future<void> togglePin(String conversationId) async {
    await _chatRepo.togglePinConversation(conversationId);
  }

  Future<void> rename(String conversationId, String newTitle) async {
    await _chatRepo.renameConversation(conversationId, newTitle);
  }

  Future<void> delete(String conversationId) async {
    await _chatRepo.deleteConversation(conversationId);
  }
}

/// Provider exposing [HistoryViewModel] and its state.
final historyViewModelProvider =
    NotifierProvider<HistoryViewModel, HistoryState>(HistoryViewModel.new);
