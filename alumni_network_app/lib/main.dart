import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';
import 'providers/auth_provider.dart';
import 'providers/message_count_provider.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'services/api_service.dart';
import 'services/fcm_service.dart';
import 'services/permission_service.dart';
import 'models/quick_action.dart';
import 'screens/auth/login_screen.dart';
import 'screens/internships/internship_list.dart';
import 'screens/events/events_list_screen.dart';
import 'screens/chat/inbox_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/admin/user_list_screen.dart';
import 'screens/directory/alumni_directory.dart';
import 'screens/connections/connection_requests_screen.dart';
import 'screens/auth/splash_screen.dart' as animated;
import 'screens/resources/resource_list_screen.dart';
import 'screens/notifications/notifications_screen.dart';
import 'screens/notifications/send_notification_screen.dart';
import 'screens/dashboard/student_dashboard.dart';
import 'screens/dashboard/alumni_dashboard.dart';
import 'screens/dashboard/alumni_leaderboard_screen.dart';
import 'screens/dashboard/alumni_mentorship_screen.dart';
import 'screens/feedback/feedback_screen.dart';
import 'screens/todo/todo_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await FcmService.initialize();
  await initTodoNotifications();
  await ApiService.init();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MessageCountProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      title: 'Alumni Network',
      debugShowCheckedModeBanner: false,
      themeMode: themeProvider.mode,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2F5BFF),
          brightness: Brightness.light,
        ),
        primaryColor: const Color(0xFF2F5BFF),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        cardColor: const Color(0xFFFFFFFF),
        dividerColor: const Color(0xFFE0E0E0),
        iconTheme: const IconThemeData(color: Color(0xFF424242)),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF1A1A2E)),
          bodyMedium: TextStyle(color: Color(0xFF424242)),
          bodySmall: TextStyle(color: Color(0xFF757575)),
          titleLarge: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w700),
          titleMedium: TextStyle(color: Color(0xFF1A1A2E), fontWeight: FontWeight.w600),
          titleSmall: TextStyle(color: Color(0xFF424242), fontWeight: FontWeight.w500),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF1A1A2E),
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Color(0xFF1A1A2E)),
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1A1A2E),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFFFFFFFF),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.zero,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFFFFFFFF),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2F5BFF),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF5F7FA),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF2F5BFF), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF757575)),
          hintStyle: const TextStyle(color: Color(0xFF9E9E9E)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFFFFFFFF),
          selectedItemColor: Color(0xFF2F5BFF),
          unselectedItemColor: Color(0xFF9E9E9E),
          elevation: 8,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: TextStyle(fontSize: 11),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Color(0xFF1A1A2E),
          iconColor: Color(0xFF424242),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFFF5F7FA),
          labelStyle: const TextStyle(color: Color(0xFF424242)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF3B82F6),
          brightness: Brightness.dark,
        ),
        primaryColor: const Color(0xFF3B82F6),
        scaffoldBackgroundColor: const Color(0xFF0F172A),
        cardColor: const Color(0xFF1E293B),
        dividerColor: const Color(0xFF334155),
        iconTheme: const IconThemeData(color: Color(0xFFCBD5E1)),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFF1F5F9)),
          bodyMedium: TextStyle(color: Color(0xFFCBD5E1)),
          bodySmall: TextStyle(color: Color(0xFF94A3B8)),
          titleLarge: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.w700),
          titleMedium: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.w600),
          titleSmall: TextStyle(color: Color(0xFFCBD5E1), fontWeight: FontWeight.w500),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF1E293B),
          foregroundColor: Color(0xFFF1F5F9),
          elevation: 0,
          centerTitle: false,
          iconTheme: IconThemeData(color: Color(0xFFF1F5F9)),
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFFF1F5F9),
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: EdgeInsets.zero,
        ),
        drawerTheme: const DrawerThemeData(
          backgroundColor: Color(0xFF1E293B),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            textStyle: const TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF0F172A),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF334155)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
          ),
          labelStyle: const TextStyle(color: Color(0xFF94A3B8)),
          hintStyle: const TextStyle(color: Color(0xFF64748B)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E293B),
          selectedItemColor: Color(0xFF3B82F6),
          unselectedItemColor: Color(0xFF64748B),
          elevation: 8,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: TextStyle(fontSize: 11),
        ),
        listTileTheme: const ListTileThemeData(
          textColor: Color(0xFFF1F5F9),
          iconColor: Color(0xFFCBD5E1),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: const Color(0xFF334155),
          labelStyle: const TextStyle(color: Color(0xFFCBD5E1)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
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
    Provider.of<AuthProvider>(context, listen: false).checkAuth();
    _requestPermissions();
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) setState(() => _animationFinished = true);
    });
  }

  Future<void> _requestPermissions() async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) await FcmService.requestPermission(context);
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
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).bottomNavigationBarTheme.backgroundColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          type: BottomNavigationBarType.fixed,
          selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
          unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
          backgroundColor: Colors.transparent,
          elevation: 0,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          onTap: (index) {
            setState(() => _selectedIndex = index);
            if (index == 3) {
              Provider.of<MessageCountProvider>(context, listen: false).reset();
            }
          },
          items: [
            const BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
            const BottomNavigationBarItem(icon: Icon(Icons.work_outline), activeIcon: Icon(Icons.work), label: 'Internships'),
            const BottomNavigationBarItem(icon: Icon(Icons.event_outlined), activeIcon: Icon(Icons.event), label: 'Events'),
            BottomNavigationBarItem(
              label: 'Messages',
              icon: Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), child: const Icon(Icons.chat_bubble_outline)),
              activeIcon: Badge(isLabelVisible: unread > 0, label: Text(unread > 99 ? '99+' : '$unread'), child: const Icon(Icons.chat_bubble)),
            ),
          ],
        ),
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
  int _statsRefreshKey = 0; // increment to force stats widget rebuild
  int? _loadedUserId;

  @override
  void initState() {
    super.initState();
    _loadCustomOrder();
  }

  Future<void> _loadCustomOrder() async {
    try {
      if (!mounted) return;
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final user = auth.user;
      if (user == null) return;
      
      _loadedUserId = user.userId;
      final role = user.role.toLowerCase();
      
      final prefs = await SharedPreferences.getInstance();
      // Use user-specific key for persistence
      final order = prefs.getStringList('user_${user.userId}_quick_actions_order');
      
      if (order != null && mounted) {
        setState(() {
          _customOrder = order;
        });
      } else if (mounted) {
        // Fallback to role-based if user-specific not found (for migration)
        final oldOrder = prefs.getStringList('${role}_quick_actions_order');
        if (oldOrder != null) {
          setState(() => _customOrder = oldOrder);
        }
      }
    } catch (e) {
      debugPrint('Load custom order error: $e');
    }
  }

  Future<void> _pickImage(AuthProvider auth) async {
    final granted = await PermissionService.checkMediaPermission(context);
    if (!granted) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null) return;
    final file = result.files.single;

    String? path = file.path;
    if (path == null && file.bytes != null) {
      final ext = file.extension ?? 'jpg';
      final tempPath = '${Directory.systemTemp.path}/avatar_${DateTime.now().millisecondsSinceEpoch}.$ext';
      await File(tempPath).writeAsBytes(file.bytes!);
      path = tempPath;
    }
    if (path != null) _uploadImage(path, auth);
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
          // Evict old image from cache before updating
          final oldUrl = auth.user?.profilePictureUrl;
          if (oldUrl != null && oldUrl.isNotEmpty) {
            final fullOld = oldUrl.startsWith('http') ? oldUrl : '${ApiService.baseUrl}$oldUrl';
            NetworkImage(fullOld).evict();
          }
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

  void _handleRefresh(BuildContext context, AuthProvider auth) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text('Refreshing...', style: TextStyle(color: Colors.white, fontSize: 16, decoration: TextDecoration.none)),
          ],
        ),
      ),
    );
    await auth.checkAuth();
    await _loadCustomOrder();
    if (mounted) {
      setState(() => _statsRefreshKey++);
      Navigator.pop(context);
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
    
    // Safety check: if user changed but order wasn't reloaded, reload it
    if (user != null && user.userId != _loadedUserId) {
      Future.microtask(() => _loadCustomOrder());
    }

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      drawer: _buildSideDrawer(context, user, role, availableActions, auth),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good ${_greeting()},',
              style: TextStyle(fontSize: 13, color: Theme.of(context).textTheme.bodySmall?.color, fontWeight: FontWeight.w400),
            ),
            user == null
                ? const SizedBox(
                    width: 100, height: 18,
                    child: LinearProgressIndicator(borderRadius: BorderRadius.all(Radius.circular(4))),
                  )
                : Text(
                    (user.fullName).split(' ').first,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Theme.of(context).textTheme.titleLarge?.color),
                  ),
          ],
        ),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
        elevation: 0,
        actions: [
          Consumer<ThemeProvider>(
            builder: (_, tp, __) => IconButton(
              icon: Icon(tp.icon),
              tooltip: tp.mode == ThemeMode.system
                  ? 'System theme'
                  : tp.mode == ThemeMode.light
                      ? 'Light mode'
                      : 'Dark mode',
              onPressed: tp.toggle,
            ),
          ),
          _NotificationBell(),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => _pickImage(auth),
            child: Padding(
              padding: const EdgeInsets.only(right: 4),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFFE3F2FD),
                backgroundImage: (user?.profilePictureUrl != null && user!.profilePictureUrl!.isNotEmpty)
                    ? NetworkImage(user.profilePictureUrl!.startsWith('http')
                        ? user.profilePictureUrl!
                        : '${ApiService.baseUrl}${user.profilePictureUrl}')
                    : null,
                child: (user?.profilePictureUrl == null || user!.profilePictureUrl!.isEmpty)
                    ? const Icon(Icons.person, size: 20, color: Color(0xFF1565C0))
                    : (_isUploading ? const CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1565C0)) : null),
              ),
            ),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Theme.of(context).iconTheme.color),
            onSelected: (val) {
              if (val == 'refresh') _handleRefresh(context, auth);
              if (val == 'logout') _handleLogout(context, auth);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(
                value: 'refresh',
                child: Row(children: [
                  Icon(Icons.refresh, color: Color(0xFF1565C0), size: 18),
                  SizedBox(width: 10),
                  Text('Refresh'),
                ]),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Row(children: [
                  Icon(Icons.logout, color: Colors.red, size: 18),
                  SizedBox(width: 10),
                  Text('Logout', style: TextStyle(color: Colors.red)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await auth.checkAuth();
          await _loadCustomOrder();
          setState(() => _statsRefreshKey++);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile summary card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1565C0), Color(0xFF283593)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              role.toUpperCase(),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            user?.fullName ?? 'User',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            role == 'alumni'
                                ? '${user?.jobTitle ?? "Professional"} @ ${user?.company ?? "Member"}'
                                : role == 'student'
                                ? (user?.currentStatus ?? 'Active Student')
                                : user?.email ?? '',
                            style: const TextStyle(color: Colors.white70, fontSize: 13),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => _pickImage(auth),
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 36,
                            backgroundColor: Colors.white24,
                            backgroundImage: (user?.profilePictureUrl != null && user!.profilePictureUrl!.isNotEmpty)
                                ? NetworkImage(user.profilePictureUrl!.startsWith('http')
                                    ? user.profilePictureUrl!
                                    : '${ApiService.baseUrl}${user.profilePictureUrl}')
                                : null,
                            child: (user?.profilePictureUrl == null || user!.profilePictureUrl!.isEmpty)
                                ? const Icon(Icons.person, size: 36, color: Colors.white)
                                : (_isUploading ? const CircularProgressIndicator(color: Colors.white) : null),
                          ),
                          Positioned(
                            bottom: 0, right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                              child: const Icon(Icons.camera_alt, color: Color(0xFF1565C0), size: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Admin stats or welcome message
              if (role == 'admin' || role == 'staff')
                _AdminStatsWidget(key: ValueKey(_statsRefreshKey))
              else if (role == 'student')
                StudentDashboard(key: ValueKey(_statsRefreshKey), onTabChange: widget.onTabChange)
              else if (role == 'alumni')
                AlumniDashboard(key: ValueKey(_statsRefreshKey), onTabChange: widget.onTabChange)
              else
                _WelcomeTip(role: role),
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
          id: 'admins',
          icon: Icons.admin_panel_settings,
          title: 'All Admins',
          color: Colors.deepOrange,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const UserListScreen(role: 'admin', title: 'All Admins'),
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

  Widget _buildSideDrawer(BuildContext context, user, String role, List<QuickAction> actions, AuthProvider auth) {
    return _SideDrawer(
      user: user,
      role: role,
      actions: actions,
      auth: auth,
      storageKey: 'user_${user?.userId}_quick_actions_order',
      onOrderChanged: _loadCustomOrder,
      onLogout: () => _handleLogout(context, auth),
    );
  }

  String _greeting() {    final hour = DateTime.now().hour;
    if (hour < 12) return 'Morning';
    if (hour < 16) return 'Afternoon';
    return 'Evening';
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

class _AdminStatsWidget extends StatefulWidget {
  const _AdminStatsWidget({super.key});

  @override
  State<_AdminStatsWidget> createState() => _AdminStatsWidgetState();
}

class _AdminStatsWidgetState extends State<_AdminStatsWidget> {
  Map<String, dynamic>? _stats;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final response = await ApiService().get('/admin/stats');
      if (response.statusCode == 200) {
        setState(() {
          _stats = jsonDecode(response.body);
          _loading = false;
        });
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 6,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
        ),
        itemBuilder: (_, __) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(width: 42, height: 42, decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(height: 20, width: 50, color: Colors.grey[200]),
                    const SizedBox(height: 6),
                    Container(height: 12, width: 70, color: Colors.grey[100]),
                  ],
                )),
              ],
            ),
          ),
        ),
      );
    }
    if (_stats == null) return const SizedBox.shrink();

    final items = [
      _StatItem('Students',    _stats!['total_students'],    Icons.school,           const Color(0xFF1565C0)),
      _StatItem('Alumni',      _stats!['total_alumni'],      Icons.group_work,       const Color(0xFF00897B)),
      _StatItem('Staff',       _stats!['total_staff'],       Icons.badge,            const Color(0xFF6D4C41)),
      _StatItem('Admins',      _stats!['total_admins'],      Icons.admin_panel_settings, const Color(0xFFE65100)),
      _StatItem('Internships', _stats!['total_internships'], Icons.work,             const Color(0xFFF57C00)),
      _StatItem('Events',      _stats!['total_events'],      Icons.event,            const Color(0xFF7B1FA2)),
      _StatItem('Resources',   _stats!['total_resources'],   Icons.library_books,    const Color(0xFF0277BD)),
      _StatItem('Connections', _stats!['total_connections'], Icons.people,           const Color(0xFF2E7D32)),
      _StatItem('Pending',     _stats!['pending_connections'],Icons.hourglass_empty, const Color(0xFFC62828)),
      _StatItem('Messages',    _stats!['total_messages'],    Icons.chat_bubble,      const Color(0xFFAD1457)),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Platform Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            IconButton(
              icon: _loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.refresh, size: 20, color: Color(0xFF9E9E9E)),
              onPressed: _loading ? null : _fetchStats,
              tooltip: 'Refresh',
            ),
          ],
        ),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemBuilder: (context, index) {
            final item = items[index];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(item.icon, color: item.color, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${item.value}',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: item.color),
                        ),
                        Text(
                          item.label,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _StatItem {
  final String label;
  final dynamic value;
  final IconData icon;
  final Color color;
  const _StatItem(this.label, this.value, this.icon, this.color);
}

class _WelcomeTip extends StatelessWidget {
  final String role;
  const _WelcomeTip({required this.role});

  @override
  Widget build(BuildContext context) {
    final tips = {
      'student': ('Connect with Alumni', 'Browse the alumni directory and send connection requests to get mentorship and internship opportunities.', Icons.school, const Color(0xFF1565C0)),
      'alumni': ('Share Opportunities', 'Post internships and connect with students to give back to your community.', Icons.group_work, const Color(0xFF00897B)),
      'staff': ('Manage Resources', 'Upload educational resources and send notifications to keep students informed.', Icons.badge, const Color(0xFF6D4C41)),
    };
    final tip = tips[role] ?? tips['student']!;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: tip.$4.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tip.$4.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tip.$4.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(tip.$3, color: tip.$4, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tip.$1, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: tip.$4)),
                const SizedBox(height: 4),
                Text(tip.$2, style: const TextStyle(fontSize: 12, color: Color(0xFF757575), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SideDrawer extends StatefulWidget {
  final dynamic user;
  final String role;
  final List<QuickAction> actions;
  final AuthProvider auth;
  final String storageKey;
  final VoidCallback onOrderChanged;
  final VoidCallback onLogout;

  const _SideDrawer({
    required this.user,
    required this.role,
    required this.actions,
    required this.auth,
    required this.storageKey,
    required this.onOrderChanged,
    required this.onLogout,
  });

  @override
  State<_SideDrawer> createState() => _SideDrawerState();
}

class _SideDrawerState extends State<_SideDrawer> {
  late List<QuickAction> _actions;
  bool _isReordering = false;

  @override
  void initState() {
    super.initState();
    _actions = List.from(widget.actions);
  }

  @override
  void didUpdateWidget(_SideDrawer old) {
    super.didUpdateWidget(old);
    if (!_isReordering) _actions = List.from(widget.actions);
  }

  Future<void> _saveOrder() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(widget.storageKey, _actions.map((a) => a.id).toList());
    setState(() => _isReordering = false);
    widget.onOrderChanged();
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Theme.of(context).drawerTheme.backgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1565C0), Color(0xFF283593)],
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Colors.white24,
                    backgroundImage: (widget.user?.profilePictureUrl != null &&
                            widget.user!.profilePictureUrl!.isNotEmpty)
                        ? NetworkImage(widget.user!.profilePictureUrl!.startsWith('http')
                            ? widget.user!.profilePictureUrl!
                            : '${ApiService.baseUrl}${widget.user!.profilePictureUrl}')
                        : null,
                    child: (widget.user?.profilePictureUrl == null ||
                            widget.user!.profilePictureUrl!.isEmpty)
                        ? const Icon(Icons.person, size: 28, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.user?.fullName ?? 'User',
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            widget.role.toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Toolbar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(
                children: [
                  Text('Quick Actions', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const Spacer(),
                  if (!_isReordering)
                    GestureDetector(
                      onTap: () => setState(() => _isReordering = true),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.tune, size: 13, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 4),
                            Text('Arrange', style: TextStyle(fontSize: 11, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    )
                  else
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => setState(() {
                            _actions = List.from(widget.actions);
                            _isReordering = false;
                          }),
                          child: Text('Cancel', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _saveOrder,
                          child: Text('Save', style: TextStyle(fontSize: 12, color: Theme.of(context).primaryColor, fontWeight: FontWeight.w700)),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            // Actions list
            Expanded(
              child: _isReordering
                  ? ReorderableListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: _actions.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = _actions.removeAt(oldIndex);
                          _actions.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, index) {
                        final action = _actions[index];
                        return Container(
                          key: ValueKey(action.id),
                          margin: const EdgeInsets.only(bottom: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: action.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(action.icon, color: action.color, size: 18),
                            ),
                            title: Text(action.title, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13, fontWeight: FontWeight.w500)),
                            trailing: Icon(Icons.drag_handle, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.4)),
                          ),
                        );
                      },
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      itemCount: _actions.length,
                      itemBuilder: (context, index) => _DrawerActionTile(action: _actions[index]),
                    ),
            ),
            const Divider(height: 1),
            // Role-specific items
            if (widget.role == 'alumni') ...[
              ListTile(
                leading: const Icon(Icons.rate_review_outlined, color: Color(0xFF7B1FA2)),
                title: const Text('My Feedback', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.school_outlined, color: Color(0xFF00897B)),
                title: const Text('Mentorship Slots', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AlumniMentorshipScreen()));
                },
              ),
              ListTile(
                leading: const Icon(Icons.leaderboard_outlined, color: Color(0xFFF57C00)),
                title: const Text('Leaderboard', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AlumniLeaderboardScreen()));
                },
              ),
              const Divider(height: 1),
            ],
            if (widget.role == 'student' || widget.role == 'staff' || widget.role == 'admin') ...[
              ListTile(
                leading: const Icon(Icons.rate_review_outlined, color: Color(0xFF7B1FA2)),
                title: const Text('Feedback', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const FeedbackScreen()));
                },
              ),
              const Divider(height: 1),
            ],
            if (widget.role == 'student') ...[
              ListTile(
                leading: const Icon(Icons.checklist_rounded, color: Color(0xFF1565C0)),
                title: const Text('My Tasks', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const TodoScreen()));
                },
              ),
              const Divider(height: 1),
            ],            ListTile(
              leading: const Icon(Icons.person_outline, color: Color(0xFF1565C0)),
              title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500, fontSize: 14)),
              onTap: () {
                Navigator.pop(context);
                widget.onLogout();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _DrawerActionTile extends StatefulWidget {
  final QuickAction action;
  const _DrawerActionTile({required this.action});

  @override
  State<_DrawerActionTile> createState() => _DrawerActionTileState();
}

class _DrawerActionTileState extends State<_DrawerActionTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: _hovered ? widget.action.color.withValues(alpha: 0.08) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.action.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(widget.action.icon, color: widget.action.color, size: 20),
          ),
          title: Text(
            widget.action.title,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
              color: _hovered ? widget.action.color : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
          trailing: Icon(Icons.chevron_right, size: 18, color: Theme.of(context).iconTheme.color?.withValues(alpha: 0.4)),
          onTap: () {
            Navigator.pop(context); // close drawer
            widget.action.onTap();
          },
        ),
      ),
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
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _scale = 0.94),
        onTapUp: (_) => setState(() => _scale = 1.0),
        onTapCancel: () => setState(() => _scale = 1.0),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 100),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            decoration: BoxDecoration(
              color: _hovered ? widget.color.withValues(alpha: 0.06) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _hovered ? widget.color.withValues(alpha: 0.4) : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: _hovered
                      ? widget.color.withValues(alpha: 0.18)
                      : Colors.black.withValues(alpha: 0.06),
                  blurRadius: _hovered ? 16 : 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: _hovered ? 0.2 : 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(widget.icon, size: 26, color: widget.color),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      color: _hovered ? widget.color : const Color(0xFF1A1A2E),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
