import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'providers/auth_provider.dart';
import 'providers/message_count_provider.dart';
import 'providers/notification_provider.dart';
import 'services/api_service.dart';
import 'models/quick_action.dart';
import 'screens/auth/login_screen.dart';
import 'screens/internships/internship_list.dart';
import 'screens/events/events_list_screen.dart';
import 'screens/chat/inbox_screen.dart';
import 'screens/dashboard/customize_dashboard_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/admin/user_list_screen.dart';
import 'screens/directory/alumni_directory.dart';
import 'screens/connections/connection_requests_screen.dart';
import 'screens/auth/splash_screen.dart' as animated;
import 'screens/resources/resource_list_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/notifications/send_notification_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MessageCountProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Alumni Network',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        fontFamily: 'Inter',
      ),
      home: const AuthWrapper(),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _animationFinished = false;

  @override
  void initState() {
    super.initState();
    // Run auth check and animation in parallel
    Provider.of<AuthProvider>(context, listen: false).checkAuth();

    // Minimum splash duration to show animation
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _animationFinished = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_animationFinished) return const animated.SplashScreen();

    final auth = Provider.of<AuthProvider>(context);
    if (auth.isAuthenticated) return const HomeScreen();
    return const LoginScreen();
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  late List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardView(
        onTabChange: (index) => setState(() => _selectedIndex = index),
      ),
      const InternshipListScreen(),
      const EventsListScreen(),
      const InboxScreen(),
    ];
    // Start polling only after auth is confirmed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.isAuthenticated) {
        Provider.of<MessageCountProvider>(context, listen: false).startPolling();
        Provider.of<NotificationProvider>(context, listen: false).startPolling();
      }
    });
  }

  @override
  void dispose() {
    Provider.of<MessageCountProvider>(context, listen: false).stopPolling();
    Provider.of<NotificationProvider>(context, listen: false).stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = Provider.of<MessageCountProvider>(context).unreadCount;

    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() => _selectedIndex = index);
          // Clear badge when Messages tab is tapped
          if (index == 3) {
            Provider.of<MessageCountProvider>(context, listen: false).reset();
          }
        },
        items: [
          const BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Home',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.work),
            label: 'Internships',
          ),
          const BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Events',
          ),
          BottomNavigationBarItem(
            label: 'Messages',
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text(unread > 99 ? '99+' : '$unread'),
              child: const Icon(Icons.chat),
            ),
          ),
        ],
      ),
    );
  }
}

class DashboardView extends StatefulWidget {
  final Function(int)? onTabChange;
  const DashboardView({super.key, this.onTabChange});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  List<String> _customOrder = [];
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadCustomOrder();
  }

  Future<void> _loadCustomOrder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final role = (auth.user?.role ?? 'student').toLowerCase();
      final order = prefs.getStringList('${role}_quick_actions_order');
      if (order != null && mounted) {
        setState(() {
          _customOrder = order;
        });
      }
    } catch (e) {
      debugPrint('Load custom order error: $e');
    }
  }

  Future<void> _pickImage(AuthProvider auth) async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result != null && result.files.single.path != null) {
      _uploadImage(result.files.single.path!, auth);
    }
  }

  Future<void> _uploadImage(String path, AuthProvider auth) async {
    setState(() => _isUploading = true);
    final api = ApiService();
    try {
      final response = await api.upload('/upload', path);
      if (response.statusCode == 200) {
        final data = await response.stream.bytesToString();
        final Map<String, dynamic> decoded = jsonDecode(data);
        if (decoded.containsKey('url')) {
          final imageUrl = decoded['url'];
          await api.patch('/profile/${auth.user!.userId}', {
            'profile_picture_url': imageUrl,
          });
          await auth.checkAuth();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile picture updated!')),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Upload error: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _handleLogout(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text(
              'Logging out...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                decoration: TextDecoration.none,
              ),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        Navigator.pop(context);
        auth.logout();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;
    final role = (user?.role ?? 'student').toLowerCase();

    List<QuickAction> availableActions = _getActionsForUser(role);

    if (_customOrder.isNotEmpty) {
      final List<QuickAction> sorted = [];
      for (var id in _customOrder) {
        final action = availableActions.where((a) => a.id == id).firstOrNull;
        if (action != null) sorted.add(action);
      }
      // Add any remaining actions not in customOrder
      for (var action in availableActions) {
        if (!sorted.contains(action)) sorted.add(action);
      }
      availableActions = sorted;
    }

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          _NotificationBell(),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => _handleLogout(context, auth),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await auth.checkAuth();
          await _loadCustomOrder();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.indigo],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _pickImage(auth),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 35,
                            backgroundColor: Colors.white24,
                            backgroundImage:
                                (user?.profilePictureUrl != null &&
                                    user!.profilePictureUrl!.isNotEmpty)
                                ? NetworkImage(
                                    user.profilePictureUrl!.startsWith('http')
                                        ? user.profilePictureUrl!
                                        : '${ApiService.baseUrl}${user.profilePictureUrl}',
                                  )
                                : null,
                            child:
                                (user?.profilePictureUrl == null ||
                                    user!.profilePictureUrl!.isEmpty)
                                ? const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.white,
                                  )
                                : (_isUploading
                                      ? const CircularProgressIndicator(
                                          color: Colors.white,
                                        )
                                      : null),
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Colors.blue,
                                size: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hi, ${user?.fullName ?? "User"}!',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          if (role != 'admin' && role != 'staff' ||
                              (user?.currentStatus != null &&
                                  user!.currentStatus!.isNotEmpty))
                            Text(
                              role == 'alumni'
                                  ? '${user?.jobTitle ?? "Professional"} @ ${user?.company ?? "Member"}'
                                  : (user?.currentStatus ?? 'Active Student'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          const SizedBox(height: 2),
                          Text(
                            role.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (user != null)
                    TextButton.icon(
                      onPressed: () async {
                        final updated = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomizeDashboardScreen(
                              storageKey: '${role}_quick_actions_order',
                              currentOrder: availableActions
                                  .map((e) => e.id)
                                  .toList(),
                              availableIds: availableActions
                                  .map((e) => e.id)
                                  .toList(),
                            ),
                          ),
                        );
                        if (updated == true) _loadCustomOrder();
                      },
                      icon: const Icon(Icons.settings, size: 18),
                      label: const Text('Customize'),
                    ),
                ],
              ),
              const SizedBox(height: 15),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: availableActions.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 15,
                  mainAxisSpacing: 15,
                  childAspectRatio: 1.1,
                ),
                itemBuilder: (context, index) {
                  final action = availableActions[index];
                  return _buildActionCard(
                    context,
                    action.icon,
                    action.title,
                    action.color,
                    action.onTap,
                    index,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<QuickAction> _getActionsForUser(String role) {
    List<QuickAction> actions = [
      QuickAction(
        id: 'internships',
        icon: Icons.work,
        title: 'Internships',
        color: Colors.orange,
        onTap: () => widget.onTabChange?.call(1),
      ),
      QuickAction(
        id: 'events',
        icon: Icons.event,
        title: 'Events',
        color: Colors.purple,
        onTap: () => widget.onTabChange?.call(2),
      ),
      QuickAction(
        id: 'profile',
        icon: Icons.person_outline,
        title: 'My Profile',
        color: Colors.blue,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EditProfileScreen()),
        ),
      ),
      QuickAction(
        id: 'messages',
        icon: Icons.message,
        title: 'Inbox',
        color: Colors.pinkAccent,
        onTap: () => widget.onTabChange?.call(3),
      ),
      QuickAction(
        id: 'resources',
        icon: Icons.library_books,
        title: 'Resources',
        color: Colors.amber,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ResourceListScreen()),
        ),
      ),
    ];

    if (role == 'admin') {
      actions.insertAll(0, [
        
        QuickAction(
          id: 'students',
          icon: Icons.school,
          title: 'All Students',
          color: Colors.indigo,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const UserListScreen(role: 'student', title: 'All Students'),
            ),
          ),
        ),
        QuickAction(
          id: 'alumni',
          icon: Icons.group_work,
          title: 'All Alumnies',
          color: Colors.teal,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const UserListScreen(role: 'alumni', title: 'All Alumnies'),
            ),
          ),
        ),
        QuickAction(
          id: 'staff',
          icon: Icons.badge,
          title: 'All Staffs',
          color: const Color.fromARGB(255, 120, 45, 130),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const UserListScreen(role: 'staff', title: 'All Staffs'),
            ),
          ),
        ),
        QuickAction(
          id: 'send_notification',
          icon: Icons.campaign,
          title: 'Send Notification',
          color: Colors.deepOrange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SendNotificationScreen()),
          ),
        ),

        QuickAction(
          id: 'register',
          icon: Icons.person_add,
          title: 'Register User',
          color: Colors.red,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const RegisterScreen()),
          ),
        ),
      ]);
    } else if (role == 'student') {
      actions.add(
        QuickAction(
          id: 'directory',
          icon: Icons.group,
          title: 'Alumni Directory',
          color: Colors.teal,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AlumniDirectoryScreen()),
          ),
        ),
      );
    } else if (role == 'alumni') {
      actions.add(
        QuickAction(
          id: 'connection_requests',
          icon: Icons.person_add_alt_1,
          title: 'Connection Requests',
          color: Colors.deepPurple,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ConnectionRequestsScreen()),
          ),
        ),
      );
    } else if (role == 'staff') {
      actions.insertAll(0, [
        QuickAction(
          id: 'students',
          icon: Icons.school,
          title: 'All Students',
          color: Colors.indigo,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const UserListScreen(role: 'student', title: 'All Students'),
            ),
          ),
        ),
        QuickAction(
          id: 'alumni',
          icon: Icons.group_work,
          title: 'All Alumnies',
          color: Colors.teal,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const UserListScreen(role: 'alumni', title: 'All Alumnies'),
            ),
          ),
        ),
        QuickAction(
          id: 'staff',
          icon: Icons.badge,
          title: 'All Staffs',
          color: const Color.fromARGB(255, 150, 36, 162),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const UserListScreen(role: 'staff', title: 'All Staffs'),
            ),
          ),
        ),
        QuickAction(
          id: 'send_notification',
          icon: Icons.campaign,
          title: 'Send Notification',
          color: Colors.deepOrange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const SendNotificationScreen()),
          ),
        ),
      ]);
    }
    return actions;
  }

  Widget _buildActionCard(
    BuildContext context,
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
    int index,
  ) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 100)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: child,
          ),
        );
      },
      child: _AnimatedActionCard(
        icon: icon,
        title: title,
        color: color,
        onTap: onTap,
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final unread = Provider.of<NotificationProvider>(context).unreadCount;
    return IconButton(
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text(unread > 99 ? '99+' : '$unread'),
        child: const Icon(Icons.notifications_outlined),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const NotificationsScreen()),
        ).then((_) {
          Provider.of<NotificationProvider>(context, listen: false).fetchCount();
        });
      },
    );
  }
}

class _AnimatedActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;

  const _AnimatedActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
  });

  @override
  State<_AnimatedActionCard> createState() => _AnimatedActionCardState();
}

class _AnimatedActionCardState extends State<_AnimatedActionCard> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.92),
      onTapUp: (_) => setState(() => _scale = 1.0),
      onTapCancel: () => setState(() => _scale = 1.0),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: Card(
          elevation: 4,
          shadowColor: widget.color.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Colors.white, widget.color.withValues(alpha: 0.05)],
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icon, size: 32, color: widget.color),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
