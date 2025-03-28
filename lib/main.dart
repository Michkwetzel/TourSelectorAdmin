import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tour_selector_admin/firebase_options.dart';
import 'package:tour_selector_admin/tagsNotifier.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tour Selector Admin',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TagsDisplayScreen(),
    );
  }
}

class TagsDisplayScreen extends ConsumerWidget {
  const TagsDisplayScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsState = ref.watch(tagsProvider);

    // Calculate total weight for visible categories with tags
    final totalWeight = tagsState.categoryConfigs.entries
        .where((entry) {
          int index = entry.key;
          bool hasAnyTags = tagsState.getTagsForIndex(index).isNotEmpty;
          return entry.value.isVisible && hasAnyTags;
        })
        .map((entry) => entry.value.weight)
        .fold(0, (sum, weight) => sum + weight);

    // Check if weights are valid
    final bool weightsValid = totalWeight == 10;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags Admin'),
        actions: [
          // Weight indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: weightsValid ? Colors.green : Colors.red,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Weights: $totalWeight / 10',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: tagsState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : tagsState.error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Error: ${tagsState.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.read(tagsProvider.notifier).clearError(),
                        child: const Text('Clear Error'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    final tagIndex = index + 1; // Convert to 1-based index
                    final tagEntries = tagsState.getTagsForIndex(tagIndex);
                    final categoryConfig = tagsState.getCategoryConfig(tagIndex);

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Category title editor
                                  Expanded(
                                    flex: 7,
                                    child: IntrinsicHeight(
                                      child: TextField(
                                        controller: TextEditingController(text: categoryConfig.title),
                                        decoration: InputDecoration(
                                          labelText: 'Category $tagIndex Title',
                                          border: const OutlineInputBorder(),
                                        ),
                                        onSubmitted: (value) {
                                          ref.read(tagsProvider.notifier).updateCategoryTitle(tagIndex, value);
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  // Weight input field
                                  Expanded(
                                    flex: 1,
                                    child: IntrinsicHeight(
                                      child: TextField(
                                        controller: TextEditingController(text: categoryConfig.weight.toString()),
                                        decoration: const InputDecoration(
                                          labelText: 'Weight',
                                          border: OutlineInputBorder(),
                                          helperText: 'Total: 10',
                                        ),
                                        keyboardType: TextInputType.number,
                                        inputFormatters: [
                                          FilteringTextInputFormatter.digitsOnly,
                                        ],
                                        onSubmitted: (value) {
                                          final weight = int.tryParse(value) ?? 0;
                                          ref.read(tagsProvider.notifier).updateCategoryWeight(
                                                tagIndex,
                                                weight.clamp(0, 10), // Ensure weight is between 0 and 10
                                              );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              // Visibility checkbox
                              Row(
                                children: [
                                  Checkbox(
                                    value: categoryConfig.isVisible,
                                    onChanged: (value) {
                                      if (value != null) {
                                        ref.read(tagsProvider.notifier).updateCategoryVisibility(tagIndex, value);
                                      }
                                    },
                                  ),
                                  const Text('Show in User Frontend'),
                                  // Tag count information
                                  const Spacer(),
                                  Text(
                                    '${tagEntries.length} tag${tagEntries.length == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      color: tagEntries.isEmpty ? Colors.red : Colors.green,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (tagEntries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('No tags available'),
                          )
                        else
                          TagsReorderableList(
                            tagIndex: tagIndex,
                            tagEntries: tagEntries,
                          ),
                        const Divider(),
                      ],
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddTagDialog(context, ref),
        child: const Icon(Icons.add),
      ),
      bottomNavigationBar: !weightsValid
          ? Container(
              color: Colors.red.shade100,
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Warning: The weights of visible categories with tags must sum to exactly 10',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            )
          : null,
    );
  }

  void _showAddTagDialog(BuildContext context, WidgetRef ref) {
    int selectedIndex = 1;
    final devNameController = TextEditingController();
    final displayNameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Tag'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Consumer(
              builder: (context, ref, _) {
                final tagsState = ref.watch(tagsProvider);
                return DropdownButtonFormField<int>(
                  value: selectedIndex,
                  decoration: const InputDecoration(labelText: 'Tag Category'),
                  items: List.generate(
                    6,
                    (index) {
                      final categoryIndex = index + 1;
                      final config = tagsState.getCategoryConfig(categoryIndex);
                      return DropdownMenuItem(
                        value: categoryIndex,
                        child: Text('${config.title} (${config.weight})'),
                      );
                    },
                  ),
                  onChanged: (value) {
                    selectedIndex = value!;
                  },
                );
              },
            ),
            TextField(
              controller: devNameController,
              decoration: const InputDecoration(labelText: 'Developer Name (Key)'),
            ),
            TextField(
              controller: displayNameController,
              decoration: const InputDecoration(labelText: 'Display Name (Value)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (devNameController.text.isNotEmpty && displayNameController.text.isNotEmpty) {
                ref.read(tagsProvider.notifier).uploadTag(
                      selectedIndex,
                      displayNameController.text,
                      devNameController.text,
                    );
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }
}

class TagsReorderableList extends ConsumerStatefulWidget {
  final int tagIndex;
  final List<TagEntry> tagEntries;

  const TagsReorderableList({
    Key? key,
    required this.tagIndex,
    required this.tagEntries,
  }) : super(key: key);

  @override
  ConsumerState<TagsReorderableList> createState() => _TagsReorderableListState();
}

class _TagsReorderableListState extends ConsumerState<TagsReorderableList> {
  late List<TagEntry> _tags;

  @override
  void initState() {
    super.initState();
    _tags = List.from(widget.tagEntries);
  }

  @override
  void didUpdateWidget(TagsReorderableList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.tagEntries != oldWidget.tagEntries) {
      _tags = List.from(widget.tagEntries);
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    setState(() {
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = _tags.removeAt(oldIndex);
      _tags.insert(newIndex, item);
    });

    // Update the order in Firestore
    ref.read(tagsProvider.notifier).updateTagsOrder(widget.tagIndex, _tags);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: SingleChildScrollView(
        child: Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: [
            for (int i = 0; i < _tags.length; i++)
              DraggableTagChip(
                key: ValueKey(_tags[i].devName),
                tag: _tags[i],
                index: i,
                onReorder: _onReorder,
                onDelete: () => ref.read(tagsProvider.notifier).removeTag(widget.tagIndex, _tags[i].devName),
              ),
          ],
        ),
      ),
    );
  }
}

class DraggableTagChip extends StatelessWidget {
  final TagEntry tag;
  final int index;
  final Function(int oldIndex, int newIndex) onReorder;
  final VoidCallback onDelete;

  const DraggableTagChip({
    Key? key,
    required this.tag,
    required this.index,
    required this.onReorder,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LongPressDraggable<int>(
      data: index,
      feedback: Material(
        elevation: 4.0,
        color: Colors.transparent,
        child: TagChip(
          devName: tag.devName,
          displayName: tag.displayName,
          onDelete: () {}, // Disable delete in the dragged preview
          isDragging: true,
        ),
      ),
      childWhenDragging: Opacity(
        opacity: 0.3,
        child: TagChip(
          devName: tag.devName,
          displayName: tag.displayName,
          onDelete: onDelete,
        ),
      ),
      child: DragTarget<int>(
        builder: (context, candidateData, rejectedData) {
          return TagChip(
            devName: tag.devName,
            displayName: tag.displayName,
            onDelete: onDelete,
            isTargeted: candidateData.isNotEmpty,
          );
        },
        onAccept: (draggedIndex) {
          onReorder(draggedIndex, index);
        },
      ),
    );
  }
}

class TagChip extends StatelessWidget {
  final String devName;
  final String displayName;
  final VoidCallback onDelete;
  final bool isTargeted;
  final bool isDragging;

  const TagChip({
    Key? key,
    required this.devName,
    required this.displayName,
    required this.onDelete,
    this.isTargeted = false,
    this.isDragging = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: isTargeted ? Border.all(color: Colors.blue, width: 2) : null,
      ),
      child: Chip(
        backgroundColor: isTargeted ? Colors.blue.withOpacity(0.1) : null,
        label: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(displayName),
            Text(
              devName,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        deleteIcon: const Icon(Icons.clear, size: 16),
        onDeleted: onDelete,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        avatar: const Icon(Icons.drag_handle, size: 16),
        elevation: isDragging ? 4 : 0,
      ),
    );
  }
}
