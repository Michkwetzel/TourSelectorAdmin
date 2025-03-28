import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TagEntry {
  final String devName;
  final String displayName;
  final int order;

  TagEntry({
    required this.devName,
    required this.displayName,
    required this.order,
  });

  factory TagEntry.fromFirestore(String key, String value, int? order) {
    return TagEntry(
      devName: key,
      displayName: value,
      order: order ?? 9999, // Default high value for unsorted tags
    );
  }
}

class TagsNotifierState {
  final Map<String, Map<String, dynamic>> rawTagData;
  final bool isLoading;
  final String? error;

  TagsNotifierState({
    required this.rawTagData,
    this.isLoading = false,
    this.error,
  });

  TagsNotifierState copyWith({
    Map<String, Map<String, dynamic>>? rawTagData,
    bool? isLoading,
    String? error,
  }) {
    return TagsNotifierState(
      rawTagData: rawTagData ?? this.rawTagData,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  factory TagsNotifierState.initial() {
    return TagsNotifierState(
      rawTagData: {
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

  // Helper methods to get sorted tag lists for specific indices
  List<TagEntry> getTagsForIndex(int index) {
    final docName = 'tags$index';
    final data = rawTagData[docName] ?? {};
    
    final List<TagEntry> entries = [];
    
    // The raw data structure is now:
    // {
    //   "devName1": { "display": "displayName1", "order": 1 },
    //   "devName2": { "display": "displayName2", "order": 0 },
    // }
    
    data.forEach((key, value) {
      if (value is Map) {
        final displayName = value['display'] as String?;
        final order = value['order'] as int?;
        
        if (displayName != null) {
          entries.add(TagEntry.fromFirestore(key, displayName, order));
        }
      }
    });
    
    // Sort entries by order
    entries.sort((a, b) => a.order.compareTo(b.order));
    
    return entries;
  }
  
  // Get tag entries as map entries (for backward compatibility)
  List<MapEntry<String, String>> getTagEntriesForIndex(int index) {
    final tags = getTagsForIndex(index);
    return tags.map((tag) => MapEntry(tag.devName, tag.displayName)).toList();
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
          
          // Update state with new data
          final updatedTagMaps = Map<String, Map<String, dynamic>>.from(state.rawTagData);
          updatedTagMaps[docName] = data;

          state = state.copyWith(
            rawTagData: updatedTagMaps,
            isLoading: false,
          );
        } else {
          // Document doesn't exist, set empty map
          final updatedTagMaps = Map<String, Map<String, dynamic>>.from(state.rawTagData);
          updatedTagMaps[docName] = {};

          state = state.copyWith(
            rawTagData: updatedTagMaps,
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
    
    // Get current tags to determine the next order value
    final currentTags = state.getTagsForIndex(index);
    final nextOrder = currentTags.isEmpty 
        ? 0 
        : currentTags.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1;
    
    _firestore.collection('tags').doc(docName).update({
      tagDevName: {
        'display': tagDisplayName,
        'order': nextOrder,
      }
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
  
  // Update the order of tags
  void updateTagsOrder(int index, List<TagEntry> reorderedTags) {
    final docName = 'tags$index';
    final batch = _firestore.batch();
    final docRef = _firestore.collection('tags').doc(docName);
    
    // Update each tag's order
    for (int i = 0; i < reorderedTags.length; i++) {
      final tag = reorderedTags[i];
      batch.update(docRef, {
        '${tag.devName}.order': i,
      });
    }
    
    batch.commit().catchError((error) {
      state = state.copyWith(
        error: 'Error updating tag order: $error',
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