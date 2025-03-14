import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TagsNotifierState {
  final Map<String, Map<String, String>> tagMaps;
  final bool isLoading;
  final String? error;

  TagsNotifierState({
    required this.tagMaps,
    this.isLoading = false,
    this.error,
  });

  TagsNotifierState copyWith({
    Map<String, Map<String, String>>? tagMaps,
    bool? isLoading,
    String? error,
  }) {
    return TagsNotifierState(
      tagMaps: tagMaps ?? this.tagMaps,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  factory TagsNotifierState.initial() {
    return TagsNotifierState(
      tagMaps: {
        'tags1': {},
        'tags2': {},
        'tags3': {},
        'tags4': {},
        'tags5': {},
        'tags6': {},
      },
      isLoading: true,
    );
  }

  // Helper methods to get tag lists for specific indices
  List<MapEntry<String, String>> getTagsForIndex(int index) {
    final docName = 'tags$index';
    return tagMaps[docName]?.entries.toList() ?? [];
  }
}

class TagsNotifier extends StateNotifier<TagsNotifierState> {
  TagsNotifier() : super(TagsNotifierState.initial()) {
    // Initialize by starting streams for all tag documents
    for (int i = 1; i <= 6; i++) {
      _listenToTagDocument(i);
    }
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _listenToTagDocument(int index) {
    final docName = 'tags$index';

    _firestore.collection('tags').doc(docName).snapshots().listen(
      (DocumentSnapshot snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final Map<String, String> tagMap = {};

          // Convert dynamic values to String
          data.forEach((key, value) {
            if (value is String) {
              tagMap[key] = value;
            }
          });

          // Update state with new data
          final updatedTagMaps = Map<String, Map<String, String>>.from(state.tagMaps);
          updatedTagMaps[docName] = tagMap;

          state = state.copyWith(
            tagMaps: updatedTagMaps,
            isLoading: false,
          );
        } else {
          // Document doesn't exist, set empty map
          final updatedTagMaps = Map<String, Map<String, String>>.from(state.tagMaps);
          updatedTagMaps[docName] = {};

          state = state.copyWith(
            tagMaps: updatedTagMaps,
            isLoading: false,
          );
        }
      },
      onError: (error) {
        state = state.copyWith(
          error: 'Error fetching $docName: $error',
          isLoading: false,
        );
      },
    );
  }

  // Upload a tag to a specific index document
  void uploadTag(int index, String tagDisplayName, String tagDevName) {
    final docName = 'tags$index';
    _firestore.collection('tags').doc(docName).update({
      tagDevName: tagDisplayName,
    }).catchError((error) {
      state = state.copyWith(
        error: 'Error uploading tag: $error',
      );
    });
  }

  // Remove a tag from a specific index document
  void removeTag(int index, String tagDevName) {
    final docName = 'tags$index';
    _firestore.collection('tags').doc(docName).update({
      tagDevName: FieldValue.delete(),
    }).catchError((error) {
      state = state.copyWith(
        error: 'Error removing tag: $error',
      );
    });
  }

  // Method to reset error state
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// Provider for the Tags state
final tagsProvider = StateNotifierProvider<TagsNotifier, TagsNotifierState>((ref) {
  return TagsNotifier();
});
