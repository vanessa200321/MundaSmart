import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/weather_screen.dart';
import 'core/theme/app_theme.dart';

const Color forestGreen = Color(0xFF2E7D32);
const Color lightGreen = Color(0xFFE8F5E9);
const Color appBackground = Color(0xFFF7FAF5);

const List<String> provinceOptions = [
  'Central',
  'Copperbelt',
  'Eastern',
  'Luapula',
  'Lusaka',
  'Muchinga',
  'Northern',
  'North-Western',
  'Southern',
  'Western',
];

const List<String> cropOptions = [
  'Maize',
  'Tomatoes',
  'Soybeans',
  'Groundnuts',
];

const List<String> stageOptions = [
  'Preparing the land',
  'Planting',
  'Growing',
  'Harvesting',
];

String? matchSavedValue(String? savedValue, List<String> options) {
  if (savedValue == null || savedValue.trim().isEmpty) {
    return null;
  }

  final cleaned = savedValue.trim().toLowerCase();
  final withoutProvince = cleaned.replaceFirst(RegExp(r'\s+province$'), '');

  for (final option in options) {
    if (option.toLowerCase() == cleaned ||
        option.toLowerCase() == withoutProvince) {
      return option;
    }
  }

  return null;
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ClimateSmartFarmerApp());
}

class ClimateSmartFarmerApp extends StatelessWidget {
  const ClimateSmartFarmerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MundaSmart',
      theme: AppTheme.lightTheme,
      home: const AppGate(),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return hasProfile
        ? const MainNavigationScreen()
        : const ProfileSetupScreen();
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int selectedIndex = 0;

  final List<Widget> screens = const [
    HomeScreen(),
    AdviceScreen(),
    WeatherScreen(),
    CalendarScreen(),
    ProfileScreen(),
  ];

  final List<String> titles = const [
    'ClimateSmart Farmer',
    'Farming Advice',
    'Weather',
    'Farming Calendar',
    'My Profile',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titles[selectedIndex])),
      body: IndexedStack(index: selectedIndex, children: screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.lightbulb_outline),
            selectedIcon: Icon(Icons.lightbulb),
            label: 'Advice',
          ),
          NavigationDestination(
            icon: Icon(Icons.cloud_outlined),
            selectedIcon: Icon(Icons.cloud),
            label: 'Weather',
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

Future<Map<String, String?>> loadFarmerProfile() async {
  final prefs = await SharedPreferences.getInstance();

  return {
    'location': prefs.getString('farmer_location'),
    'crop': prefs.getString('farmer_crop'),
    'stage': prefs.getString('farmer_stage'),
  };
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, String?> profile = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refreshProfile();
  }

  Future<void> refreshProfile() async {
    final data = await loadFarmerProfile();
    if (!mounted) return;

    setState(() {
      profile = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return RefreshIndicator(
      onRefresh: refreshProfile,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: lightGreen,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.agriculture, size: 42, color: forestGreen),
                const SizedBox(height: 12),
                const Text(
                  'Welcome to ClimateSmart Farmer',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: forestGreen,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Get farming advice, weather information and seasonal reminders to support your farming activities.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Your farming details',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          InfoCard(
            icon: Icons.location_on,
            title: 'Province',
            value: profile['location'] ?? 'Not set',
          ),
          InfoCard(
            icon: Icons.grass,
            title: 'Your crop',
            value: profile['crop'] ?? 'Not set',
          ),
          InfoCard(
            icon: Icons.agriculture,
            title: 'Farming stage',
            value: profile['stage'] ?? 'Not set',
          ),
          const SizedBox(height: 20),
          const Text(
            'Explore the app',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          const FeatureCard(
            icon: Icons.lightbulb_outline,
            title: 'Farming Advice',
            description: 'Explore advice for your province and crop.',
          ),
          const FeatureCard(
            icon: Icons.cloud_outlined,
            title: 'Weather',
            description: 'View current weather and a five-day forecast.',
          ),
          const FeatureCard(
            icon: Icons.calendar_month,
            title: 'Farming Calendar',
            description: 'View seasonal farming activities and reminders.',
          ),
          const SizedBox(height: 12),
          const OfflineNotice(),
        ],
      ),
    );
  }
}

class AdviceScreen extends StatefulWidget {
  const AdviceScreen({super.key});

  @override
  State<AdviceScreen> createState() => _AdviceScreenState();
}

class _AdviceScreenState extends State<AdviceScreen> {
  String province = 'Lusaka';
  String crop = 'Maize';
  bool loading = true;

  final Set<int> expandedCards = {};

  final Map<String, String> provinceAdvice = {
    'Central':
        'Monitor rainfall and soil moisture. Prepare fields early and use suitable planting dates for your area.',
    'Copperbelt':
        'Monitor heavy rainfall and drainage. Avoid waterlogging and keep fields free from weeds.',
    'Eastern':
        'Plan planting around the onset of reliable rainfall. Monitor pests and diseases throughout the season.',
    'Luapula':
        'Pay attention to drainage and excess moisture. Monitor crop diseases during wet conditions.',
    'Lusaka':
        'Monitor rainfall closely and conserve soil moisture during dry periods. Prepare fields before planting.',
    'Muchinga':
        'Check local rainfall patterns before planting. Maintain soil fertility and monitor crop growth.',
    'Northern':
        'Monitor excess moisture and ensure good drainage. Inspect crops regularly for disease.',
    'North-Western':
        'Prepare fields before the rains and monitor soil conditions during crop establishment.',
    'Southern':
        'Conserve moisture, use suitable planting dates and monitor dry spells carefully.',
    'Western':
        'Consider local flood and water conditions. Protect fields from waterlogging where necessary.',
  };

  final Map<String, List<String>> cropAdvice = {
    'Maize': [
      'Use certified seed suitable for your area.',
      'Plant when there is adequate soil moisture and reliable rainfall.',
      'Weed early to reduce competition for nutrients and water.',
      'Monitor for fall armyworm and other pests.',
      'Harvest when the crop has reached maturity and dry grain properly before storage.',
    ],
    'Tomatoes': [
      'Use healthy seedlings and prepare well-drained soil.',
      'Water consistently without waterlogging the plants.',
      'Monitor for pests and diseases, especially during wet conditions.',
      'Use staking where appropriate to support plants.',
      'Harvest ripe tomatoes carefully to reduce damage.',
    ],
    'Soybeans': [
      'Use suitable certified soybean seed.',
      'Prepare a well-drained field and plant at the recommended spacing.',
      'Control weeds early in the growing season.',
      'Monitor for insect pests and leaf diseases.',
      'Harvest when pods are mature and dry.',
    ],
    'Groundnuts': [
      'Use good-quality seed and prepare a loose, well-drained seedbed.',
      'Plant when there is adequate soil moisture.',
      'Control weeds early, taking care not to damage plants.',
      'Monitor for leaf diseases and pests.',
      'Harvest at maturity and dry properly to reduce mould risk.',
    ],
  };

  @override
  void initState() {
    super.initState();
    loadDetails();
  }

  Future<void> loadDetails() async {
    final data = await loadFarmerProfile();

    if (!mounted) return;

    setState(() {
      province = matchSavedValue(data['location'], provinceOptions) ?? 'Lusaka';
      crop = matchSavedValue(data['crop'], cropOptions) ?? 'Maize';
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final tips = cropAdvice[crop] ?? cropAdvice['Maize']!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Advice for $province Province',
          style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(provinceAdvice[province] ?? provinceAdvice['Lusaka']!),
        const SizedBox(height: 18),
        Row(
          children: [
            const Text(
              'Advice for your crop',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            Chip(label: Text('Your crop: $crop'), backgroundColor: lightGreen),
          ],
        ),
        const SizedBox(height: 8),
        ...List.generate(tips.length, (index) {
          final expanded = expandedCards.contains(index);

          return Card(
            child: ExpansionTile(
              leading: const Icon(Icons.eco, color: forestGreen),
              title: Text('Farming tip ${index + 1}'),
              initiallyExpanded: expanded,
              onExpansionChanged: (value) {
                setState(() {
                  if (value) {
                    expandedCards.add(index);
                  } else {
                    expandedCards.remove(index);
                  }
                });
              },
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Text(tips[index]),
                ),
              ],
            ),
          );
        }),
        const OfflineNotice(),
      ],
    );
  }
}

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  String crop = 'Maize';
  String stage = 'Preparing the land';
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadDetails();
  }

  Future<void> loadDetails() async {
    final data = await loadFarmerProfile();
    if (!mounted) return;

    setState(() {
      crop = matchSavedValue(data['crop'], cropOptions) ?? 'Maize';
      stage =
          matchSavedValue(data['stage'], stageOptions) ?? 'Preparing the land';
      loading = false;
    });
  }

  String get currentPeriod {
    final month = DateTime.now().month;

    if (month == 10 || month == 11) {
      return 'Land preparation and planting';
    } else if (month == 12 || month == 1) {
      return 'Crop establishment';
    } else if (month == 2 || month == 3) {
      return 'Crop care and monitoring';
    } else if (month == 4 || month == 5) {
      return 'Harvest preparation and harvesting';
    }

    return 'Post-harvest activities and farm planning';
  }

  final List<Map<String, String>> periods = const [
    {
      'title': 'October â€“ November',
      'description': 'Prepare land, plan planting and obtain suitable seed.',
    },
    {
      'title': 'December â€“ January',
      'description': 'Monitor germination, crop establishment and weeds.',
    },
    {
      'title': 'February â€“ March',
      'description': 'Monitor crop growth, pests, diseases and soil moisture.',
    },
    {
      'title': 'April â€“ May',
      'description': 'Prepare for harvesting and dry produce properly.',
    },
    {
      'title': 'June â€“ September',
      'description':
          'Plan the next season, maintain equipment and manage stored produce.',
    },
  ];

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: lightGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Current general farming period',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                currentPeriod,
                style: const TextStyle(
                  fontSize: 20,
                  color: forestGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Seasonal farming calendar',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...periods.map(
          (period) => Card(
            child: ExpansionTile(
              leading: const Icon(Icons.calendar_month, color: forestGreen),
              title: Text(period['title']!),
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(period['description']!),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Your farming reminders',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.grass, color: forestGreen),
            title: Text('Crop: $crop'),
            subtitle: Text(
              crop == 'Maize'
                  ? 'Check soil moisture, weed early and monitor for fall armyworm.'
                  : crop == 'Tomatoes'
                  ? 'Monitor watering, staking, pests and tomato diseases.'
                  : crop == 'Soybeans'
                  ? 'Monitor weeds, crop growth and pod development.'
                  : 'Monitor weeds, crop health and groundnut maturity.',
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.agriculture, color: forestGreen),
            title: Text('Your farming stage: $stage'),
            subtitle: Text(
              stage == 'Preparing the land'
                  ? 'Prepare the field and organise suitable seed and inputs.'
                  : stage == 'Planting'
                  ? 'Check planting conditions, spacing and soil moisture.'
                  : stage == 'Growing'
                  ? 'Monitor weeds, pests, diseases and crop development.'
                  : 'Check maturity, harvest carefully and dry produce properly.',
            ),
          ),
        ),
        const OfflineNotice(),
        const SizedBox(height: 8),
        const Text(
          'This is a general seasonal guide, not an exact planting forecast. '
          'Rainfall and suitable planting dates vary by district, soil, crop variety '
          'and season. Consult your local agricultural extension officer.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, String?> profile = {};
  bool loading = true;

  @override
  void initState() {
    super.initState();
    refreshProfile();
  }

  Future<void> refreshProfile() async {
    final data = await loadFarmerProfile();
    if (!mounted) return;

    setState(() {
      profile = data;
      loading = false;
    });
  }

  Future<void> editProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ProfileSetupScreen(isEditing: true),
      ),
    );

    await refreshProfile();
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const CircleAvatar(
          radius: 42,
          backgroundColor: lightGreen,
          child: Icon(Icons.person, size: 48, color: forestGreen),
        ),
        const SizedBox(height: 18),
        InfoCard(
          icon: Icons.location_on,
          title: 'Province',
          value: profile['location'] ?? 'Not set',
        ),
        InfoCard(
          icon: Icons.grass,
          title: 'Crop',
          value: profile['crop'] ?? 'Not set',
        ),
        InfoCard(
          icon: Icons.agriculture,
          title: 'Farming stage',
          value: profile['stage'] ?? 'Not set',
        ),
        const SizedBox(height: 18),
        FilledButton.icon(
          onPressed: editProfile,
          icon: const Icon(Icons.edit),
          label: const Text('Edit Profile'),
        ),
        const SizedBox(height: 12),
        const OfflineNotice(),
      ],
    );
  }
}

class ProfileSetupScreen extends StatefulWidget {
  final bool isEditing;

  const ProfileSetupScreen({super.key, this.isEditing = false});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  String? selectedProvince;
  String? selectedCrop;
  String? selectedStage;

  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    loadExistingProfile();
  }

  Future<void> loadExistingProfile() async {
    final data = await loadFarmerProfile();

    if (!mounted) return;

    setState(() {
      selectedProvince = matchSavedValue(data['location'], provinceOptions);
      selectedCrop = matchSavedValue(data['crop'], cropOptions);
      selectedStage = matchSavedValue(data['stage'], stageOptions);
      loading = false;
    });
  }

  Future<void> saveProfile() async {
    if (selectedProvince == null ||
        selectedCrop == null ||
        selectedStage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your province, crop and farming stage.'),
        ),
      );
      return;
    }

    setState(() {
      saving = true;
    });

    final prefs = await SharedPreferences.getInstance();

    await prefs.setString('farmer_location', selectedProvince!);
    await prefs.setString('farmer_crop', selectedCrop!);
    await prefs.setString('farmer_stage', selectedStage!);

    if (!mounted) return;

    if (widget.isEditing) {
      Navigator.pop(context, true);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.isEditing,
        title: Text(
          widget.isEditing ? 'Edit Profile' : 'Set Up Your Farm Profile',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.agriculture, size: 55, color: forestGreen),
          const SizedBox(height: 12),
          const Text(
            'Tell us about your farm',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your selections help us show relevant farming advice and weather information.',
          ),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(
            initialValue: selectedProvince,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select your province',
              border: OutlineInputBorder(),
            ),
            items: provinceOptions
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text('$value Province'),
                  ),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedProvince = value;
              });
            },
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: selectedCrop,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select your main crop',
              border: OutlineInputBorder(),
            ),
            items: cropOptions
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedCrop = value;
              });
            },
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: selectedStage,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Select your farming stage',
              border: OutlineInputBorder(),
            ),
            items: stageOptions
                .map(
                  (value) => DropdownMenuItem(value: value, child: Text(value)),
                )
                .toList(),
            onChanged: (value) {
              setState(() {
                selectedStage = value;
              });
            },
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: saving ? null : saveProfile,
            style: FilledButton.styleFrom(
              backgroundColor: forestGreen,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: saving
                ? const CircularProgressIndicator(color: Colors.white)
                : Text(widget.isEditing ? 'Save Changes' : 'Continue'),
          ),
        ],
      ),
    );
  }
}

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
    return Card(
      child: ListTile(
        leading: Icon(icon, color: forestGreen),
        title: Text(title),
        subtitle: Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
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
      child: ListTile(
        leading: Icon(icon, color: forestGreen, size: 30),
        title: Text(title),
        subtitle: Text(description),
      ),
    );
  }
}

class OfflineNotice extends StatelessWidget {
  const OfflineNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: lightGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        children: [
          Icon(Icons.offline_bolt, color: forestGreen),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your saved farm details, farming advice and calendar are available offline. Live weather requires an internet connection.',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
