import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tour_selector_admin/firebase_options.dart';
import 'package:tour_selector_admin/tagsNotifier.dart';

void main() async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(ProviderScope(child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: TagsDisplayScreen());
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text('Tour Selector Admin'),
        Row(
          children: [TextField(), TextButton(onPressed: () {}, child: Text('Add Tag'))],
        )
      ],
    );
  }
}

// Import your provider
// import 'path_to_your_tags_notifier.dart';

class TagsDisplayScreen extends ConsumerWidget {
  const TagsDisplayScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tagsState = ref.watch(tagsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags Display'),
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

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'Tags ${tagIndex}',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        if (tagEntries.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text('No tags available'),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Wrap(
                              spacing: 8.0,
                              runSpacing: 8.0,
                              children: tagEntries.map((entry) {
                                return TagChip(
                                  devName: entry.key,
                                  displayName: entry.value,
                                  onDelete: () => ref.read(tagsProvider.notifier).removeTag(tagIndex, entry.key),
                                );
                              }).toList(),
                            ),
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
            DropdownButtonFormField<int>(
              value: selectedIndex,
              decoration: const InputDecoration(labelText: 'Tag Category'),
              items: List.generate(
                6,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('Category ${index + 1}'),
                ),
              ),
              onChanged: (value) {
                selectedIndex = value!;
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

class TagChip extends StatelessWidget {
  final String devName;
  final String displayName;
  final VoidCallback onDelete;

  const TagChip({
    Key? key,
    required this.devName,
    required this.displayName,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Chip(
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
    );
  }
}
