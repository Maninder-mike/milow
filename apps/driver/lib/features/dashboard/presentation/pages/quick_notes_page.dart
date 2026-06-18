import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:milow/core/constants/design_tokens.dart';
import 'package:milow/core/services/quick_note_repository.dart';
import 'package:milow_core/milow_core.dart';
import 'package:uuid/uuid.dart';

class QuickNotesPage extends StatefulWidget {
  const QuickNotesPage({super.key});

  @override
  State<QuickNotesPage> createState() => _QuickNotesPageState();
}

class _QuickNotesPageState extends State<QuickNotesPage> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch quick notes initially (triggers server refresh in background)
    QuickNoteRepository.getQuickNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showNoteDialog({QuickNote? note}) {
    final titleController = TextEditingController(text: note?.title);
    final contentController = TextEditingController(text: note?.content);
    final isEditing = note != null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(context.tokens.shapeL),
        ),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            context.tokens.spacingM,
            context.tokens.spacingM,
            context.tokens.spacingM,
            MediaQuery.of(context).viewInsets.bottom + context.tokens.spacingM,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                isEditing ? 'Edit Note' : 'Add Note',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              SizedBox(height: context.tokens.spacingM),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Gate code or load details',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              SizedBox(height: context.tokens.spacingM),
              TextField(
                controller: contentController,
                decoration: const InputDecoration(
                  labelText: 'Content',
                  hintText: 'Enter your note here...',
                  border: OutlineInputBorder(),
                ),
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
              ),
              SizedBox(height: context.tokens.spacingL),
              FilledButton(
                onPressed: () async {
                  final title = titleController.text.trim();
                  final content = contentController.text.trim();

                  if (title.isEmpty && content.isEmpty) {
                    Navigator.pop(context);
                    return;
                  }

                  if (isEditing) {
                    final updated = note.copyWith(
                      title: title,
                      content: content,
                    );
                    await QuickNoteRepository.updateQuickNote(updated);
                  } else {
                    final newNote = QuickNote(
                      id: const Uuid().v4(),
                      title: title,
                      content: content,
                      createdAt: DateTime.now(),
                      updatedAt: DateTime.now(),
                    );
                    await QuickNoteRepository.createQuickNote(newNote);
                  }

                  if (context.mounted) Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.tokens.shapeFull),
                  ),
                ),
                child: Text(isEditing ? 'Save' : 'Add'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = Theme.of(context).colorScheme.onSurface;
    final tokens = context.tokens;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: textColor,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Quick Notes',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNoteDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Note'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: EdgeInsets.all(tokens.spacingM),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search notes...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(tokens.shapeM),
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    vertical: tokens.spacingS,
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _searchQuery = val.trim().toLowerCase();
                  });
                },
              ),
            ),
            // Notes List
            Expanded(
              child: StreamBuilder<List<QuickNote>>(
                stream: QuickNoteRepository.watchQuickNotes(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final allNotes = snapshot.data ?? [];
                  final notes = allNotes.where((note) {
                    if (_searchQuery.isEmpty) return true;
                    final title = note.title?.toLowerCase() ?? '';
                    final content = note.content?.toLowerCase() ?? '';
                    return title.contains(_searchQuery) || content.contains(_searchQuery);
                  }).toList();

                  if (notes.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.note_alt_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          SizedBox(height: tokens.spacingM),
                          Text(
                            _searchQuery.isNotEmpty ? 'No search results' : 'No notes yet',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                          ),
                          SizedBox(height: tokens.spacingXS),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try searching for something else'
                                : 'Tap "+" to save important details on the go',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: EdgeInsets.fromLTRB(
                      tokens.spacingM,
                      0,
                      tokens.spacingM,
                      tokens.spacingXL + 48,
                    ),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(note.createdAt);

                      return Card(
                        key: ValueKey(note.id),
                        elevation: 0,
                        margin: EdgeInsets.only(bottom: tokens.spacingM),
                        color: Theme.of(context).colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(tokens.shapeM),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                          ),
                        ),
                        child: InkWell(
                          onTap: () => _showNoteDialog(note: note),
                          borderRadius: BorderRadius.circular(tokens.shapeM),
                          child: Padding(
                            padding: EdgeInsets.all(tokens.spacingM),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        note.title ?? 'Untitled Note',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: Theme.of(context).colorScheme.error,
                                        size: 20,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            title: const Text('Delete Note'),
                                            content: const Text('Are you sure you want to delete this note?'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, false),
                                                child: const Text('Cancel'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                child: Text(
                                                  'Delete',
                                                  style: TextStyle(
                                                    color: Theme.of(context).colorScheme.error,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );

                                        if (confirm == true) {
                                          await QuickNoteRepository.deleteQuickNote(note.id);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                if (note.content != null && note.content!.isNotEmpty) ...[
                                  SizedBox(height: tokens.spacingS),
                                  Text(
                                    note.content!,
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                                        ),
                                    maxLines: 4,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                SizedBox(height: tokens.spacingM),
                                Text(
                                  dateStr,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                        color: Theme.of(context).colorScheme.outline,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
