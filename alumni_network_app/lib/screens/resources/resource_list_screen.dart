import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';
import '../../models/resource.dart';
import 'upload_resource_screen.dart';

class ResourceListScreen extends StatefulWidget {
  const ResourceListScreen({super.key});

  @override
  State<ResourceListScreen> createState() => _ResourceListScreenState();
}

class _ResourceListScreenState extends State<ResourceListScreen> {
  bool _isLoading = true;
  List<AppResource> _resources = [];

  @override
  void initState() {
    super.initState();
    _fetchResources();
  }

  Future<void> _fetchResources() async {
    setState(() => _isLoading = true);
    final api = ApiService();
    try {
      final response = await api.get('/resources');
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _resources = data.map((json) => AppResource.fromJson(json)).toList();
        });
      }
    } catch (e) {
      debugPrint('Fetch resources error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _launchURL(String url) async {
    final fullUrl = url.startsWith('http') ? url : '${ApiService.baseUrl}$url';
    final uri = Uri.parse(fullUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      // fallback: try in-app browser
      try {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open: $fullUrl')),
          );
        }
      }
    }
  }

  void _deleteResource(int resourceId) async {
    final api = ApiService();
    try {
      final response = await api.delete('/resources/$resourceId');
      if (response.statusCode == 200) {
        _fetchResources();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Resource deleted')),
          );
        }
      }
    } catch (e) {
      debugPrint('Delete resource error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final isStaffOrAdmin = auth.user?.role == 'staff' || auth.user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Educational Resources'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
        actions: [
          if (isStaffOrAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UploadResourceScreen()),
                );
                if (result == true) _fetchResources();
              },
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _resources.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.library_books_outlined, size: 80, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.4)),
                      const SizedBox(height: 16),
                      Text(
                        'No resources available yet',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 18),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchResources,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _resources.length,
                    itemBuilder: (context, index) {
                      final res = _resources[index];
                      final isDocument = res.resourceType == 'document';

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: (isDocument ? Colors.orange : Theme.of(context).primaryColor).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              isDocument ? Icons.description : Icons.link,
                              color: isDocument ? Colors.orange : Theme.of(context).primaryColor,
                            ),
                          ),
                          title: Text(
                            res.title,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (res.description != null && res.description!.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(res.description!),
                                ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.people_outline, size: 14, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.6)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Target: ${res.targetAudience.toUpperCase()}',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12),
                                  ),
                                  const SizedBox(width: 12),
                                  Icon(Icons.open_in_new, size: 14, color: Theme.of(context).primaryColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    isDocument ? 'Tap to open' : 'Tap to visit',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12, color: Theme.of(context).primaryColor),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          trailing: isStaffOrAdmin
                              ? IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                                  onPressed: () => _deleteResource(res.resourceId),
                                )
                              : Icon(Icons.open_in_new, color: Theme.of(context).primaryColor),
                          onTap: () => _launchURL(res.url),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
