import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../../services/api_service.dart';
import '../../services/permission_service.dart';
import '../../providers/auth_provider.dart';

// Represents one resource entry to be submitted
class _ResourceEntry {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController linkController = TextEditingController();
  String selectedAudience = 'all';
  String resourceType = 'document';
  String? pickedDocumentPath;
  String? pickedDocumentName;
  bool isUploading = false;
  bool isDone = false;

  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    linkController.dispose();
  }
}

class UploadResourceScreen extends StatefulWidget {
  const UploadResourceScreen({super.key});

  @override
  State<UploadResourceScreen> createState() => _UploadResourceScreenState();
}

class _UploadResourceScreenState extends State<UploadResourceScreen> {
  final List<_ResourceEntry> _entries = [_ResourceEntry()];
  bool _isSubmitting = false;

  @override
  void dispose() {
    for (final e in _entries) {
      e.dispose();
    }
    super.dispose();
  }

  void _addEntry() {
    setState(() => _entries.add(_ResourceEntry()));
  }

  void _removeEntry(int index) {
    setState(() {
      _entries[index].dispose();
      _entries.removeAt(index);
    });
  }

  Future<void> _pickDocument(int index) async {
    final granted = await PermissionService.checkMediaPermission(context);
    if (!granted) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null) {
      setState(() {
        _entries[index].pickedDocumentPath = result.files.single.path;
        _entries[index].pickedDocumentName = result.files.single.name;
      });
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _submitAll() async {
    // Validate all entries
    for (int i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      if (e.titleController.text.trim().isEmpty) {
        _showSnackBar('Entry ${i + 1}: Please enter a title');
        return;
      }
      if (e.resourceType == 'document' && e.pickedDocumentPath == null) {
        _showSnackBar('Entry ${i + 1}: Please select a document');
        return;
      }
      if (e.resourceType == 'link' && e.linkController.text.trim().isEmpty) {
        _showSnackBar('Entry ${i + 1}: Please enter a URL');
        return;
      }
    }

    setState(() => _isSubmitting = true);
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final api = ApiService();
    int successCount = 0;

    for (int i = 0; i < _entries.length; i++) {
      final e = _entries[i];
      setState(() => e.isUploading = true);

      try {
        String finalUrl = e.linkController.text.trim();

        if (e.resourceType == 'document' && e.pickedDocumentPath != null) {
          final res = await api.upload('/upload', e.pickedDocumentPath!);
          if (res.statusCode == 200) {
            final data = jsonDecode(await res.stream.bytesToString());
            finalUrl = data['url'];
          } else {
            _showSnackBar('Entry ${i + 1}: Failed to upload document');
            setState(() => e.isUploading = false);
            continue;
          }
        }

        final response = await api.post('/resources', {
          'created_by': user!.userId,
          'title': e.titleController.text.trim(),
          'description': e.descriptionController.text.trim(),
          'resource_type': e.resourceType,
          'url': finalUrl,
          'target_audience': e.selectedAudience,
        });

        if (response.statusCode == 200) {
          successCount++;
          setState(() {
            e.isUploading = false;
            e.isDone = true;
          });
        } else {
          _showSnackBar('Entry ${i + 1}: Failed to share resource');
          setState(() => e.isUploading = false);
        }
      } catch (err) {
        debugPrint('Upload error entry $i: $err');
        setState(() => e.isUploading = false);
      }
    }

    setState(() => _isSubmitting = false);

    if (successCount > 0 && mounted) {
      _showSnackBar('$successCount resource(s) shared successfully!');
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_entries.length == 1 ? 'Share Resource' : 'Share ${_entries.length} Resources'),
        actions: [
          TextButton.icon(
            onPressed: _isSubmitting ? null : _addEntry,
            icon: const Icon(Icons.add),
            label: const Text('Add More'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _entries.length,
              itemBuilder: (context, index) => _buildEntryCard(index),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: _isSubmitting
                ? const Center(child: CircularProgressIndicator())
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _submitAll,
                      icon: const Icon(Icons.cloud_upload),
                      label: Text(
                        _entries.length == 1
                            ? 'SHARE RESOURCE'
                            : 'SHARE ALL ${_entries.length} RESOURCES',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEntryCard(int index) {
    final e = _entries[index];
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: e.isDone ? Colors.green : theme.primaryColor,
                  child: e.isUploading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(
                          e.isDone ? Icons.check : Icons.description_outlined,
                          size: 16,
                          color: Colors.white,
                        ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Resource ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Spacer(),
                if (_entries.length > 1)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red, size: 20),
                    onPressed: () => _removeEntry(index),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: e.titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: e.descriptionController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Description (Optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: e.selectedAudience,
              decoration: const InputDecoration(
                labelText: 'Target Audience',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Members')),
                DropdownMenuItem(value: 'student', child: Text('Students Only')),
                DropdownMenuItem(value: 'alumni', child: Text('Alumni Only')),
              ],
              onChanged: (val) => setState(() => e.selectedAudience = val!),
            ),
            const SizedBox(height: 10),
            // Resource type toggle
            Row(
              children: [
                const Text('Type:', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 12),
                ChoiceChip(
                  label: const Text('Document'),
                  selected: e.resourceType == 'document',
                  onSelected: (_) => setState(() {
                    e.resourceType = 'document';
                    e.linkController.clear();
                  }),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: const Text('Web Link'),
                  selected: e.resourceType == 'link',
                  onSelected: (_) => setState(() {
                    e.resourceType = 'link';
                    e.pickedDocumentPath = null;
                    e.pickedDocumentName = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (e.resourceType == 'document') ...[
              OutlinedButton.icon(
                onPressed: () => _pickDocument(index),
                icon: const Icon(Icons.attach_file),
                label: const Text('Select Document'),
              ),
              if (e.pickedDocumentName != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Row(
                    children: [
                      Icon(Icons.insert_drive_file, size: 16, color: theme.primaryColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          e.pickedDocumentName!,
                          style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.w500, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
            ] else
              TextField(
                controller: e.linkController,
                decoration: const InputDecoration(
                  labelText: 'URL (e.g. https://example.com) *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.link),
                  isDense: true,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
