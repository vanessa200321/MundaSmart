
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClimateSmartApp());
}

const Color forestGreen = Color(0xFF2E7D32);
const Color lightGreen = Color(0xFFE8F5E9);
const Color backgroundColor = Color(0xFFF7FAF5);

class ClimateSmartApp extends StatelessWidget {
  const ClimateSmartApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ClimateSmart Farmer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: forestGreen),
        scaffoldBackgroundColor: backgroundColor,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.black87,
          elevation: 0,
        ),
      ),
      home: const AppGate(),
    );
  }
}

// Checks whether a farmer has already created a profile.
class AppGate extends StatefulWidget {
  const AppGate({super.key});

  @override
  State<AppGate> createState() => _AppGateState();
}

class _AppGateState extends State<AppGate> {
  bool loading = true;
  bool hasProfile = false;

  @override
  void initState() {
    super.initState();
    checkProfile();
  }

  Future<void> checkProfile() async {
    final prefs = await SharedPreferences.getInstance();

    final location = prefs.getString('farmer_location');
    final crop = prefs.getString('farmer_crop');
    final stage = prefs.getString('farmer_stage');

    if (!mounted) return;

    setState(() {
      hasProfile = location != null && crop != null && stage != null;
      loading = false;
    });
  }

  void profileSaved() {
    setState(() {
      hasProfile = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!hasProfile) {
      return ProfileSetupScreen(onSaved: profileSaved);
    }

    return const MainNavigationScreen();
  }
}

// Farmer profile setup and editing.
class ProfileSetupScreen extends StatefulWidget {
  final VoidCallback? onSaved;

  const ProfileSetupScreen({super.key, this.onSaved});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final List<String> provinces = [
    'Central Province',
    'Copperbelt Province',
    'Eastern Province',
    'Luapula Province',
    'Lusaka Province',
    'Muchinga Province',
    'Northern Province',
    'North-Western Province',
    'Southern Province',
    'Western Province',
  ];

  final List<String> crops = [
    'Maize',
    'Tomatoes',
    'Soybeans',
    'Groundnuts',
  ];

  final List<String> stages = [
    'Preparing the land',
    'Planting',
    'Growing',
    'Harvesting',
  ];

  String? selectedLocation;
  String? selectedCrop;
  String? selectedStage;

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      selectedLocation = prefs.getString('farmer_location');
      selectedCrop = prefs.getString('farmer_crop');
      selectedStage = prefs.getString('farmer_stage');
      isLoading = false;
    });
  }

  Future<void> saveProfile() async {
    if (selectedLocation == null ||
        selectedCrop == null ||
        selectedStage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete all the fields.'),
        ),
      );
      return;
    }

    setState(() => isSaving = true);

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('farmer_location', selectedLocation!);
      await prefs.setString('farmer_crop', selectedCrop!);
      await prefs.setString('farmer_stage', selectedStage!);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
        ),
      );

      widget.onSaved?.call();
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save profile: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Farmer Profile Setup'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.agriculture,
              size: 65,
              color: forestGreen,
            ),
            const SizedBox(height: 15),
            const Text(
              'Welcome! Let’s set up your farm.',
              style: TextStyle(
                fontSize: 23,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tell us a little about your farm so we can provide '
                  'relevant farming information.',
            ),
            const SizedBox(height: 28),

            const Text('Your Location'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedLocation,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select your province',
              ),
              items: provinces.map((province) {
                return DropdownMenuItem(
                  value: province,
                  child: Text(province),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => selectedLocation = value);
              },
            ),

            const SizedBox(height: 20),
            const Text('Main Crop'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedCrop,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select your crop',
              ),
              items: crops.map((crop) {
                return DropdownMenuItem(
                  value: crop,
                  child: Text(crop),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => selectedCrop = value);
              },
            ),

            const SizedBox(height: 20),
            const Text('Current Farming Stage'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: selectedStage,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Select farming stage',
              ),
              items: stages.map((stage) {
                return DropdownMenuItem(
                  value: stage,
                  child: Text(stage),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => selectedStage = value);
              },
            ),

            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: isSaving ? null : saveProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: forestGreen,
                  foregroundColor: Colors.white,
                ),
                child: isSaving
                    ? const CircularProgressIndicator(
                  color: Colors.white,
                )
                    : const Text('Save Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Main navigation for the four app sections.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int selectedIndex = 0;

  final List<Widget> pages = const [
    HomeScreen(),
    AdviceScreen(),
    CalendarScreen(),
    ProfileScreen(),
  ];

  final List<String> titles = [
    'ClimateSmart Farmer',
    'Farming Advice',
    'Planting Calendar',
    'My Farm Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          titles[selectedIndex],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: IndexedStack(
        index: selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.eco_outlined),
            selectedIcon: Icon(Icons.eco),
            label: 'Advice',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

// Home dashboard.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String location = '';
  String crop = '';
  String stage = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadFarmer();
  }

  Future<void> loadFarmer() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      location = prefs.getString('farmer_location') ?? 'Not set';
      crop = prefs.getString('farmer_crop') ?? 'Not set';
      stage = prefs.getString('farmer_stage') ?? 'Not set';
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: forestGreen,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'WELCOME TO YOUR FARM',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                'Grow smarter. Farm better. 🌱',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '$location • $crop',
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Your Farm Overview',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InfoCard(
                icon: Icons.grass,
                title: 'Main Crop',
                value: crop,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InfoCard(
                icon: Icons.location_on,
                title: 'Province',
                value: location.replaceAll(' Province', ''),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.agriculture,
          title: 'Farming Stage',
          value: stage,
        ),
        const SizedBox(height: 24),
        const Text(
          'Start Here',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        const FeatureCard(
          icon: Icons.eco,
          title: 'Farming Advice',
          description: 'Explore practical crop-growing guidance.',
        ),
        const FeatureCard(
          icon: Icons.calendar_month,
          title: 'Planting Calendar',
          description: 'See important activities during the season.',
        ),
        const SizedBox(height: 15),
        const Text(
          'Your farming information is stored on this device.',
          style: TextStyle(color: Colors.grey, fontSize: 12),
        ),
      ],
    );
  }
}

// Reusable information card.
class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const InfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: forestGreen, size: 28),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: forestGreen, size: 30),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}

// Province-specific offline farming advice.
class AdviceScreen extends StatefulWidget {
  const AdviceScreen({super.key});

  @override
  State<AdviceScreen> createState() => _AdviceScreenState();
}

class _AdviceScreenState extends State<AdviceScreen> {
  String province = '';
  String mainCrop = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadFarmerProfile();
  }

  Future<void> loadFarmerProfile() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      province = prefs.getString('farmer_location') ?? 'Not set';
      mainCrop = prefs.getString('farmer_crop') ?? 'Not set';
      loading = false;
    });
  }

  String get regionalDescription {
    switch (province) {
      case 'Lusaka Province':
        return 'Much of the Lusaka plateau is in Agro-Ecological '
            'Region IIa. Rainfall is seasonal, but its onset and '
            'distribution vary from year to year.';

      case 'Central Province':
        return 'Central Province has important plateau farming areas. '
            'Consider rainfall onset, soil moisture and local soil '
            'conditions when planning planting.';

      case 'Eastern Province':
        return 'Eastern Province includes several important crop-growing '
            'areas. Planting decisions should consider local rainfall, '
            'soil moisture and district conditions.';

      case 'Southern Province':
        return 'Southern Province includes both plateau and drier '
            'valley environments. Local rainfall and water availability '
            'are important for crop planning.';

      case 'Western Province':
        return 'Western Province includes sandy areas and floodplains. '
            'Soil type, drainage and local water conditions are '
            'important for crop management.';

      case 'Copperbelt Province':
      case 'Luapula Province':
      case 'Northern Province':
      case 'North-Western Province':
        return 'These provinces include wetter northern farming areas. '
            'Drainage, soil conditions and rainfall distribution '
            'should guide crop management.';

      case 'Muchinga Province':
        return 'Muchinga Province has varied farming environments. '
            'Conditions differ by district and elevation, so local '
            'rainfall and soil information should guide planting.';

      default:
        return 'Select your province in your farmer profile to '
            'receive more relevant regional guidance.';
    }
  }

  List<String> get maizeTips {
    if (province == 'Lusaka Province') {
      return [
        'Prepare your field before the rainy season. Clear unwanted '
            'vegetation and plan for proper drainage.',
        'Do not plant just because the first shower has fallen. '
            'Wait for effective rainfall and adequate soil moisture.',
        'Choose a suitable maize variety based on the expected '
            'length of the growing season and local recommendations.',
        'Use healthy, certified seed and follow the recommended '
            'spacing and planting depth for that variety.',
        'Monitor the field for weeds, especially during early '
            'crop establishment.',
        'Inspect maize regularly for fall armyworm and other pests. '
            'Seek local extension advice before applying pesticides.',
        'Maintain soil cover and use appropriate water-conservation '
            'practices to help manage dry spells.',
        'Make sure fields have drainage channels where waterlogging '
            'is a risk.',
      ];
    }

    return [
      'Prepare the field early and check soil conditions before planting.',
      'Plant after effective rainfall has established sufficient '
          'soil moisture.',
      'Select varieties suited to your local growing season.',
      'Use healthy seed and follow recommended planting practices.',
      'Control weeds early and inspect regularly for pests.',
      'Monitor rainfall and avoid waterlogging or prolonged moisture stress.',
      'Ask your local agricultural extension officer about '
          'district-specific recommendations.',
    ];
  }

  List<String> get tomatoTips {
    if (province == 'Lusaka Province') {
      return [
        'Choose a sunny site with fertile, well-drained soil.',
        'Prepare nursery beds or seedling trays using clean '
            'planting material.',
        'Transplant healthy seedlings carefully to avoid damaging roots.',
        'Water consistently. Avoid keeping the soil waterlogged.',
        'Use mulch where appropriate to conserve moisture and '
            'reduce weed growth.',
        'Provide stakes or supports to keep plants and fruit off the soil.',
        'Inspect leaves and fruits regularly for pests and disease symptoms.',
        'Avoid unnecessary overhead watering, especially when '
            'disease pressure is high.',
        'Remove badly affected plant material appropriately and '
            'seek advice when disease symptoms are unclear.',
      ];
    }

    return [
      'Choose a sunny site with fertile, well-drained soil.',
      'Use healthy seedlings and transplant carefully.',
      'Water consistently while avoiding waterlogged soil.',
      'Use mulch to conserve moisture and reduce weeds.',
      'Inspect plants regularly for pests and disease.',
      'Follow local extension advice on suitable varieties and crop care.',
    ];
  }

  Widget buildAdviceCard({
    required String title,
    required IconData icon,
    required List<String> tips,
    required bool isMainCrop,
  }) {
    return Card(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: forestGreen, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$title Farming',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (isMainCrop)
                  const Chip(
                    label: Text('Your crop'),
                    backgroundColor: lightGreen,
                  ),
              ],
            ),
            const Divider(height: 25),
            ...tips.map((tip) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: forestGreen,
                      size: 19,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        tip,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        Container(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: lightGreen,
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on, color: forestGreen),
                  SizedBox(width: 7),
                  Text(
                    'YOUR REGIONAL FARMING GUIDE',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: forestGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                province,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(regionalDescription),
              const SizedBox(height: 10),
              Text(
                'Your main crop: $mainCrop',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Recommended Crop Guidance',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        buildAdviceCard(
          title: 'Maize',
          icon: Icons.grass,
          tips: maizeTips,
          isMainCrop: mainCrop == 'Maize',
        ),
        buildAdviceCard(
          title: 'Tomatoes',
          icon: Icons.spa,
          tips: tomatoTips,
          isMainCrop: mainCrop == 'Tomatoes',
        ),
        const SizedBox(height: 5),
        const Card(
          color: Colors.white,
          child: Padding(
            padding: EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important Farming Note',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: forestGreen,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'These are general regional recommendations, '
                      'not live weather-based instructions. Actual planting '
                      'decisions should consider rainfall, soil moisture, '
                      'crop variety and district conditions. Consult an '
                      'agricultural extension officer for local advice '
                      'and pesticide recommendations.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 15),
        const Text(
          'This guidance is stored in the app and can be viewed offline.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}

// General seasonal farming calendar.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  final List<Map<String, String>> activities = const [
    {
      'period': 'October – November',
      'title': 'Land Preparation and Planting',
      'description':
      'Prepare fields, check seed availability and plant when '
          'effective rains have established sufficient soil moisture.',
    },
    {
      'period': 'December – January',
      'title': 'Crop Establishment',
      'description':
      'Check germination, fill gaps where appropriate, control weeds '
          'and monitor crop health.',
    },
    {
      'period': 'February – March',
      'title': 'Crop Care and Monitoring',
      'description':
      'Monitor pests and diseases, manage water and inspect crop '
          'development regularly.',
    },
    {
      'period': 'April – May',
      'title': 'Harvest Preparation',
      'description':
      'Assess crop maturity, prepare storage facilities and harvest '
          'when crops are ready.',
    },
    {
      'period': 'June – September',
      'title': 'Post-Harvest and Planning',
      'description':
      'Dry and store produce properly, review the season and prepare '
          'for the next farming cycle.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const Text(
          'Zambia Seasonal Farming Guide',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'A general guide for the rainy-season farming cycle. '
              'Actual planting dates vary by province, rainfall and crop variety.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 20),
        ...activities.map((activity) {
          return Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 14),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity['period']!,
                    style: const TextStyle(
                      color: forestGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    activity['title']!,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(activity['description']!),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }
}

// Farmer profile page.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String location = '';
  String crop = '';
  String stage = '';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      location = prefs.getString('farmer_location') ?? '';
      crop = prefs.getString('farmer_crop') ?? '';
      stage = prefs.getString('farmer_stage') ?? '';
      loading = false;
    });
  }

  Future<void> editProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(),
      ),
    );

    await loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const CircleAvatar(
          radius: 42,
          backgroundColor: lightGreen,
          child: Icon(
            Icons.person,
            size: 48,
            color: forestGreen,
          ),
        ),
        const SizedBox(height: 15),
        const Center(
          child: Text(
            'Farmer Profile',
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 25),
        InfoCard(
          icon: Icons.location_on,
          title: 'Province',
          value: location,
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.grass,
          title: 'Main Crop',
          value: crop,
        ),
        const SizedBox(height: 12),
        InfoCard(
          icon: Icons.agriculture,
          title: 'Farming Stage',
          value: stage,
        ),
        const SizedBox(height: 25),
        SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: editProfile,
            icon: const Icon(Icons.edit),
            label: const Text('Edit My Profile'),
            style: ElevatedButton.styleFrom(
              backgroundColor: forestGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
