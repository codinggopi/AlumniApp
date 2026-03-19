import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/directory/alumni_directory.dart';
import 'screens/internships/internship_list.dart';
import 'screens/auth/register_screen.dart';
import 'screens/events/events_list_screen.dart';
import 'screens/chat/inbox_screen.dart';
import 'screens/profile/edit_profile_screen.dart';
import 'screens/auth/splash_screen.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
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
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();
    _startFlow();
  }

  void _startFlow() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      await Provider.of<AuthProvider>(context, listen: false).checkAuth();
      setState(() => _showSplash = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_showSplash) return const SplashScreen();

    final auth = Provider.of<AuthProvider>(context);
    if (auth.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      DashboardView(onTabChange: (index) => setState(() => _selectedIndex = index)),
      const AlumniDirectoryScreen(),
      const InternshipListScreen(),
      const EventsListScreen(),
      const InboxScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _selectedIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Directory'),
          BottomNavigationBarItem(icon: Icon(Icons.work), label: 'Internships'),
          BottomNavigationBarItem(icon: Icon(Icons.event), label: 'Events'),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: 'Messages'),
        ],
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  final Function(int)? onTabChange;
  const DashboardView({super.key, this.onTabChange});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final user = auth.user;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.red),
            onPressed: () => auth.logout(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Colors.blue, Colors.indigo]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 35,
                    backgroundColor: Colors.white24,
                    child: Icon(Icons.person, size: 40, color: Colors.white),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hi, ${user?.fullName ?? "User"}!',
                          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          user?.role.toUpperCase() ?? "",
                          style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            const Text('Quick Actions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              children: [
                _buildActionCard(context, Icons.work, 'Internships', Colors.orange, () {
                  onTabChange?.call(2);
                }),
                _buildActionCard(context, Icons.people, 'Directory', Colors.green, () {
                  onTabChange?.call(1);
                }),
                _buildActionCard(context, Icons.event, 'Events', Colors.purple, () {
                  onTabChange?.call(3);
                }),
                _buildActionCard(context, Icons.person_outline, 'My Profile', Colors.blue, () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                }),
                if (user?.role == 'admin')
                  _buildActionCard(context, Icons.person_add, 'Register User', Colors.red, () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen()));
                  }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(BuildContext context, IconData icon, String title, Color color, VoidCallback onTap) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color),
            const SizedBox(height: 10),
            const Text(''), // Placeholder for spacing
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
