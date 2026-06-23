import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart';

class EmergencyContactPage extends StatefulWidget {
  const EmergencyContactPage({super.key});

  @override
  State<EmergencyContactPage> createState() => _EmergencyContactPageState();
}

class _EmergencyContactPageState extends State<EmergencyContactPage> {
  final List<TextEditingController> nameControllers =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> phoneControllers =
      List.generate(3, (_) => TextEditingController());
  final List<TextEditingController> relationshipControllers =
      List.generate(3, (_) => TextEditingController());

  int activeContactIndex = 0;
  bool isLoading = true;
  bool isSaving = false;

  final String databaseURL =
      "https://smart-flood-system-c5823-default-rtdb.asia-southeast1.firebasedatabase.app";

  FirebaseDatabase get database {
    return FirebaseDatabase.instanceFor(
      app: Firebase.app(),
      databaseURL: databaseURL,
    );
  }

  DatabaseReference get contactRef {
    final user = FirebaseAuth.instance.currentUser;
    return database.ref("EmergencyContacts/${user!.uid}");
  }

  @override
  void initState() {
    super.initState();
    loadContact();
  }

  Future<void> loadContact() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final snapshot = await contactRef.get().timeout(const Duration(seconds: 10));

      for (int i = 0; i < 3; i++) {
        nameControllers[i].clear();
        phoneControllers[i].clear();
        relationshipControllers[i].clear();
      }
      activeContactIndex = 0;

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

        // Check if this is the old schema (single contact at root)
        if (data.containsKey("name") && data["name"] != null) {
          nameControllers[0].text = data["name"]?.toString() ?? "";
          phoneControllers[0].text = data["phone"]?.toString() ?? "";
          relationshipControllers[0].text =
              data["relationship"]?.toString() ?? "";
          activeContactIndex = 0;

          // Migrate to new schema in the background
          await migrateToNewSchema(
            nameControllers[0].text,
            phoneControllers[0].text,
            relationshipControllers[0].text,
          );
        } else {
          // New multi-contact schema
          activeContactIndex =
              int.tryParse(data["activeContactIndex"]?.toString() ?? "0") ?? 0;
          if (activeContactIndex < 0 || activeContactIndex > 2) {
            activeContactIndex = 0;
          }

          if (data["contacts"] != null) {
            final contactsList = List<dynamic>.from(data["contacts"]);
            for (int i = 0; i < contactsList.length && i < 3; i++) {
              if (contactsList[i] != null) {
                final contact = Map<dynamic, dynamic>.from(contactsList[i]);
                nameControllers[i].text = contact["name"]?.toString() ?? "";
                phoneControllers[i].text = contact["phone"]?.toString() ?? "";
                relationshipControllers[i].text =
                    contact["relationship"]?.toString() ?? "";
              }
            }
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      showMessage("Failed to load contacts: $e");
    }

    if (!mounted) return;

    setState(() {
      isLoading = false;
    });
  }

  Future<void> migrateToNewSchema(
      String name, String phone, String relationship) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      await contactRef.set({
        "uid": user!.uid,
        "email": user.email ?? "Unknown email",
        "activeContactIndex": 0,
        "contacts": [
          {
            "name": name,
            "phone": phone,
            "relationship": relationship,
          },
          {
            "name": "",
            "phone": "",
            "relationship": "",
          },
          {
            "name": "",
            "phone": "",
            "relationship": "",
          }
        ],
        "updatedAt": DateTime.now().toString(),
        "updatedAtEpoch": DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
      debugPrint("Successfully migrated to multi-contact schema.");
    } catch (e) {
      debugPrint("Migration failed: $e");
    }
  }

  Future<void> saveContact() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage("Please login first.");
      return;
    }

    // Validate active contact is filled
    final activeName = nameControllers[activeContactIndex].text.trim();
    final activePhone = phoneControllers[activeContactIndex].text.trim();
    final activeRelationship =
        relationshipControllers[activeContactIndex].text.trim();

    if (activeName.isEmpty || activePhone.isEmpty || activeRelationship.isEmpty) {
      showMessage(
          "Please fill details for the active contact (Contact ${activeContactIndex + 1}).");
      return;
    }

    if (activePhone.length < 9) {
      showMessage("Active contact's phone number must be valid.");
      return;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final contactsData = <Map<String, String>>[];
      for (int i = 0; i < 3; i++) {
        contactsData.add({
          "name": nameControllers[i].text.trim(),
          "phone": phoneControllers[i].text.trim(),
          "relationship": relationshipControllers[i].text.trim(),
        });
      }

      await contactRef.set({
        "uid": user.uid,
        "email": user.email ?? "Unknown email",
        "activeContactIndex": activeContactIndex,
        "contacts": contactsData,
        "updatedAt": DateTime.now().toString(),
        "updatedAtEpoch": DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });

      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      showMessage("Emergency contacts saved successfully.");
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      showMessage("Failed to save contacts: $e");
    }
  }

  Future<void> callEmergencyContact() async {
    final phone = phoneControllers[activeContactIndex].text.trim();

    if (phone.isEmpty) {
      showMessage("No active emergency phone number saved.");
      return;
    }

    final uri = Uri(
      scheme: "tel",
      path: phone,
    );

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      showMessage("Unable to open phone dialer.");
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  Color getBackgroundColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF0F172A) : Colors.lightBlue.shade50;
  }

  Color getCardColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  }

  Color getMainTextColor(bool isDarkMode) {
    return isDarkMode ? Colors.white : Colors.black87;
  }

  Color getSubTextColor(bool isDarkMode) {
    return isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDarkMode,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: TextStyle(
          color: getMainTextColor(isDarkMode),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor:
              isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade100,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(
              color: isDarkMode ? Colors.grey.shade700 : Colors.grey.shade300,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(
              color: Colors.redAccent,
              width: 2,
            ),
          ),
        ),
      ),
    );
  }

  Widget buildHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDarkMode
              ? [
                  const Color(0xFF7F1D1D),
                  const Color(0xFF0F172A),
                ]
              : [
                  Colors.redAccent,
                  Colors.deepOrange,
                ],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emergency_rounded,
              color: Colors.white,
              size: 50,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "Emergency Contacts",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Save up to 3 emergency contacts and select the active one below",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.3,
              color: Colors.white.withOpacity(0.88),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildContactForm(int index, bool isDarkMode) {
    return RefreshIndicator(
      onRefresh: loadContact,
      color: Colors.redAccent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            RadioListTile<int>(
              title: Text(
                "Active Contact",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: activeContactIndex == index
                      ? Colors.redAccent
                      : getMainTextColor(isDarkMode),
                ),
              ),
              subtitle: const Text("Select this contact to dial in emergencies"),
              value: index,
              groupValue: activeContactIndex,
              activeColor: Colors.redAccent,
              onChanged: (val) {
                setState(() {
                  activeContactIndex = val!;
                });
              },
            ),
            const Divider(),
            const SizedBox(height: 12),
            buildTextField(
              controller: nameControllers[index],
              label: "Contact Name",
              icon: Icons.person_rounded,
              isDarkMode: isDarkMode,
            ),
            buildTextField(
              controller: phoneControllers[index],
              label: "Phone Number",
              icon: Icons.phone_rounded,
              keyboardType: TextInputType.phone,
              isDarkMode: isDarkMode,
            ),
            buildTextField(
              controller: relationshipControllers[index],
              label: "Relationship",
              icon: Icons.family_restroom_rounded,
              isDarkMode: isDarkMode,
            ),
            const SizedBox(height: 40), // extra padding for pull-to-refresh feel
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (int i = 0; i < 3; i++) {
      nameControllers[i].dispose();
      phoneControllers[i].dispose();
      relationshipControllers[i].dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: getBackgroundColor(isDarkMode),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: getBackgroundColor(isDarkMode),
          foregroundColor: getMainTextColor(isDarkMode),
          title: const Text("Emergency Contacts"),
          centerTitle: true,
          bottom: TabBar(
            labelColor: isDarkMode ? Colors.white : Colors.redAccent,
            unselectedLabelColor: getSubTextColor(isDarkMode),
            indicatorColor: Colors.redAccent,
            tabs: const [
              Tab(text: "Contact 1"),
              Tab(text: "Contact 2"),
              Tab(text: "Contact 3"),
            ],
          ),
        ),
        body: isLoading
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: buildHeader(isDarkMode),
                  ),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      decoration: BoxDecoration(
                        color: getCardColor(isDarkMode),
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: TabBarView(
                        children: [
                          buildContactForm(0, isDarkMode),
                          buildContactForm(1, isDarkMode),
                          buildContactForm(2, isDarkMode),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    color: getCardColor(isDarkMode),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: isSaving ? null : saveContact,
                            icon: isSaving
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.save_rounded),
                            label: const Text(
                              "Save All Contacts",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: callEmergencyContact,
                            icon: const Icon(Icons.call_rounded),
                            label: Text(
                              "Call Active Contact (Contact ${activeContactIndex + 1})",
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              side: const BorderSide(
                                  color: Colors.redAccent, width: 2),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}