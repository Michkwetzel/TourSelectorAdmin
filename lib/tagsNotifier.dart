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

class CategoryConfig {
  final String title;
  final int weight;
  final bool isVisible;

  CategoryConfig({
    required this.title,
    required this.weight,
    required this.isVisible,
  });

  factory CategoryConfig.fromFirestore(Map<String, dynamic>? data) {
    if (data == null) {
      return CategoryConfig(
        title: 'Category',
        weight: 1,
        isVisible: true,
      );
    }
    return CategoryConfig(
      title: data['title'] as String? ?? 'Category',
      weight: data['weight'] as int? ?? 1,
      isVisible: data['isVisible'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'weight': weight,
      'isVisible': isVisible,
    };
  }
}

class TagsNotifierState {
  final Map<String, Map<String, dynamic>> rawTagData;
  final Map<int, CategoryConfig> categoryConfigs;
  final bool isLoading;
  final String? error;

  TagsNotifierState({
    required this.rawTagData,
    required this.categoryConfigs,
    this.isLoading = false,
    this.error,
  });

  TagsNotifierState copyWith({
    Map<String, Map<String, dynamic>>? rawTagData,
    Map<int, CategoryConfig>? categoryConfigs,
    bool? isLoading,
    String? error,
  }) {
    return TagsNotifierState(
      rawTagData: rawTagData ?? this.rawTagData,
      categoryConfigs: categoryConfigs ?? this.categoryConfigs,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  factory TagsNotifierState.initial() {
    final defaultCategories = {
      1: CategoryConfig(title: 'Category 1', weight: 2, isVisible: true),
      2: CategoryConfig(title: 'Category 2', weight: 2, isVisible: true),
      3: CategoryConfig(title: 'Category 3', weight: 2, isVisible: true),
      4: CategoryConfig(title: 'Category 4', weight: 2, isVisible: true),
      5: CategoryConfig(title: 'Category 5', weight: 1, isVisible: true),
      6: CategoryConfig(title: 'Category 6', weight: 1, isVisible: true),
    };

    return TagsNotifierState(
      rawTagData: {
        'tags1': {},
        'tags2': {},
        'tags3': {},
        'tags4': {},
        'tags5': {},
        'tags6': {},
      },
      categoryConfigs: defaultCategories,
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

  // Get category configuration for a specific index
  CategoryConfig getCategoryConfig(int index) {
    return categoryConfigs[index] ?? CategoryConfig(title: 'Category $index', weight: 1, isVisible: true);
  }

  // Check if category weights sum to 10
  bool areCategoryWeightsValid() {
    // Only include visible categories that have tags
    final visibleCategoriesWithTags = categoryConfigs.entries
        .where((entry) {
          int index = entry.key;
          bool hasAnyTags = getTagsForIndex(index).isNotEmpty;
          return entry.value.isVisible && hasAnyTags;
        })
        .map((entry) => entry.value.weight)
        .fold(0, (sum, weight) => sum + weight);

    return visibleCategoriesWithTags == 10;
  }

  // Check if a category should be visible in the user frontend
  bool shouldShowCategory(int index) {
    final config = getCategoryConfig(index);
    final hasTags = getTagsForIndex(index).isNotEmpty;
    return config.isVisible && hasTags;
  }
}

class TagsNotifier extends StateNotifier<TagsNotifierState> {
  TagsNotifier() : super(TagsNotifierState.initial()) {
    // Initialize by listening to category config
    _listenToCategoryConfig();

    // Initialize by starting streams for all tag documents
    for (int i = 1; i <= 6; i++) {
      _listenToTagDocument(i);
    }
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _listenToCategoryConfig() {
    _firestore.collection('config').doc('categories').snapshots().listen(
      (DocumentSnapshot snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final updatedConfigs = Map<int, CategoryConfig>.from(state.categoryConfigs);

          // Update each category config from Firestore
          for (int i = 1; i <= 6; i++) {
            final categoryData = data['category$i'] as Map<String, dynamic>?;
            if (categoryData != null) {
              updatedConfigs[i] = CategoryConfig.fromFirestore(categoryData);
            }
          }

          state = state.copyWith(
            categoryConfigs: updatedConfigs,
            isLoading: false,
          );
        } else {
          // If document doesn't exist, create it with default values
          _initializeCategoryConfig();
        }
      },
      onError: (error) {
        state = state.copyWith(
          error: 'Error fetching category config: $error',
          isLoading: false,
        );
      },
    );
  }

  void _initializeCategoryConfig() {
    final Map<String, dynamic> categoryData = {};

    // Create default category configs
    for (int i = 1; i <= 6; i++) {
      final defaultWeight = (i <= 4) ? 2 : 1; // 2+2+2+2+1+1 = 10
      categoryData['category$i'] = {
        'title': 'Category $i',
        'weight': defaultWeight,
      };
    }

    _firestore.collection('config').doc('categories').set(categoryData).catchError((error) {
      state = state.copyWith(
        error: 'Error initializing category config: $error',
      );
    });
  }

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
    final nextOrder = currentTags.isEmpty ? 0 : currentTags.map((t) => t.order).reduce((a, b) => a > b ? a : b) + 1;

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

  // Update category title
  void updateCategoryTitle(int index, String title) {
    final currentConfig = state.getCategoryConfig(index);
    final updatedConfig = CategoryConfig(
      title: title,
      weight: currentConfig.weight,
      isVisible: currentConfig.isVisible,
    );

    _updateCategoryConfig(index, updatedConfig);
  }

  // Update category weight
  void updateCategoryWeight(int index, int weight) {
    final currentConfig = state.getCategoryConfig(index);
    final updatedConfig = CategoryConfig(
      title: currentConfig.title,
      weight: weight,
      isVisible: currentConfig.isVisible,
    );

    _updateCategoryConfig(index, updatedConfig);
  }

  // Update category visibility
  void updateCategoryVisibility(int index, bool isVisible) {
    final currentConfig = state.getCategoryConfig(index);
    final updatedConfig = CategoryConfig(
      title: currentConfig.title,
      weight: currentConfig.weight,
      isVisible: isVisible,
    );

    _updateCategoryConfig(index, updatedConfig);
  }

  // Update multiple category properties
  void updateCategory({
    required int index,
    String? title,
    int? weight,
    bool? isVisible,
  }) {
    final currentConfig = state.getCategoryConfig(index);
    final updatedConfig = CategoryConfig(
      title: title ?? currentConfig.title,
      weight: weight ?? currentConfig.weight,
      isVisible: isVisible ?? currentConfig.isVisible,
    );

    _updateCategoryConfig(index, updatedConfig);
  }

  // Helper method for updating category config in Firestore
  void _updateCategoryConfig(int index, CategoryConfig config) {
    _firestore.collection('config').doc('categories').update({
      'category$index': config.toFirestore(),
    }).catchError((error) {
      state = state.copyWith(
        error: 'Error updating category config: $error',
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
