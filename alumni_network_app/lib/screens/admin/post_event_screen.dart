import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../services/event_bus.dart';
import '../../providers/auth_provider.dart';
import 'package:file_picker/file_picker.dart';

class PostEventScreen extends StatefulWidget {
  const PostEventScreen({super.key});

  @override
  State<PostEventScreen> createState() => _PostEventScreenState();
}

class _PostEventScreenState extends State<PostEventScreen> {
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _dateController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _selectedAudience = 'all'; // 'all', 'student', 'alumni'
  bool _isLoading = false;
  bool _hasDocument = false;
  bool _hasPhotos = false;
  String? _pickedDocumentPath;
  String? _pickedPhotosPath;
  String? _pickedDocumentName;
  String? _pickedPhotosName;

  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.any);
    if (result != null) {
      setState(() {
        _hasDocument = true;
        _pickedDocumentPath = result.files.single.path;
        _pickedDocumentName = result.files.single.name;
      });
    } else {
      if (_pickedDocumentName == null) setState(() => _hasDocument = false);
    }
  }

  Future<void> _pickPhotos() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null) {
      setState(() {
        _hasPhotos = true;
        _pickedPhotosPath = result.files.single.path;
        _pickedPhotosName = result.files.single.name;
      });
    } else {
      if (_pickedPhotosName == null) setState(() => _hasPhotos = false);
    }
  }

  void _submitEvent() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a title')));
      return;
    }
    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a location')));
      return;
    }
    if (_dateController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a date')));
      return;
    }
    if (_descriptionController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a description')));
      return;
    }
    
    setState(() => _isLoading = true);
    final user = Provider.of<AuthProvider>(context, listen: false).user;
    final api = ApiService();

    try {
      String? docUrl;
      String? photoUrl;

      if (_hasDocument && _pickedDocumentPath != null) {
        final res = await api.upload('/upload', _pickedDocumentPath!);
        if (res.statusCode == 200) {
          final data = jsonDecode(await res.stream.bytesToString());
          docUrl = data['url'];
        }
      }

      if (_hasPhotos && _pickedPhotosPath != null) {
        final res = await api.upload('/upload', _pickedPhotosPath!);
        if (res.statusCode == 200) {
          final data = jsonDecode(await res.stream.bytesToString());
          photoUrl = data['url'];
        }
      }

      final response = await api.post('/events', {
        'created_by': user!.userId,
        'title': _titleController.text,
        'location': _locationController.text,
        'date': _dateController.text,
        'description': _descriptionController.text,
        'target_audience': _selectedAudience,
        'has_document': _hasDocument,
        'has_photos': _hasPhotos,
        'document_url': docUrl,
        'photo_url': photoUrl,
      });

      if (response.statusCode == 200 && mounted) {
        EventBus.emitRefresh();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event posted successfully!')));
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to post event.')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Post New Event')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Event Title *', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(labelText: 'Location *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_on)),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(labelText: 'Date (e.g., Oct 25, 2024) *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
            ),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _selectedAudience,
              decoration: const InputDecoration(labelText: 'Target Audience *', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Members')),
                DropdownMenuItem(value: 'student', child: Text('Students Only')),
                DropdownMenuItem(value: 'alumni', child: Text('Alumni Only')),
              ],
              onChanged: (val) => setState(() => _selectedAudience = val!),
            ),
            const SizedBox(height: 15),
            Column(
              children: [
                TextField(
                  controller: _descriptionController,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Description *',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(4),
                        topRight: Radius.circular(4),
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(4),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CheckboxListTile(
                              title: const Row(children: [Icon(Icons.attachment, size: 18), SizedBox(width: 5), Text('Attach Doc', style: TextStyle(fontSize: 12))]),
                              value: _hasDocument,
                              onChanged: (val) {
                                if (val == true) _pickDocument();
                                else setState(() { _hasDocument = false; _pickedDocumentName = null; _pickedDocumentPath = null; });
                              },
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            if (_pickedDocumentName != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(_pickedDocumentName!, style: const TextStyle(fontSize: 10, color: Colors.blue), overflow: TextOverflow.ellipsis),
                              ),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 40, color: Colors.grey[300]),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CheckboxListTile(
                              title: const Row(children: [Icon(Icons.insert_photo, size: 18), SizedBox(width: 5), Text('Add Photos', style: TextStyle(fontSize: 12))]),
                              value: _hasPhotos,
                              onChanged: (val) {
                                if (val == true) _pickPhotos();
                                else setState(() { _hasPhotos = false; _pickedPhotosName = null; _pickedPhotosPath = null; });
                              },
                              dense: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                            ),
                            if (_pickedPhotosName != null)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 10),
                                child: Text(_pickedPhotosName!, style: const TextStyle(fontSize: 10, color: Colors.green), overflow: TextOverflow.ellipsis),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _submitEvent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('POST EVENT', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
