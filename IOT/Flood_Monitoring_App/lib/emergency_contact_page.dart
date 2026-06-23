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

  DatabaseReference contactReference(String uid) {
    return database.ref("EmergencyContacts/$uid");
  }

  @override
  void initState() {
    super.initState();
    loadContacts();
  }

  Future<void> loadContacts() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage("Please login first.");
      return;
    }

    try {
      final snapshot = await contactReference(user.uid).get().timeout(
            const Duration(seconds: 10),
          );

      clearAllControllers();

      if (snapshot.exists && snapshot.value != null) {
        final data = Map<dynamic, dynamic>.from(snapshot.value as Map);

        if (data.containsKey("name") && data["name"] != null) {
          nameControllers[0].text = data["name"]?.toString() ?? "";
          phoneControllers[0].text = data["phone"]?.toString() ?? "";
          relationshipControllers[0].text =
              data["relationship"]?.toString() ?? "";

          activeContactIndex = 0;

          await migrateOldSingleContactSchema(
            uid: user.uid,
            email: user.email ?? "Unknown email",
          );
        } else {
          activeContactIndex =
              int.tryParse(data["activeContactIndex"]?.toString() ?? "0") ?? 0;

          if (activeContactIndex < 0 || activeContactIndex > 2) {
            activeContactIndex = 0;
          }

          final contactsRaw = data["contacts"];

          for (int i = 0; i < 3; i++) {
            dynamic contactRaw;

            if (contactsRaw is List && i < contactsRaw.length) {
              contactRaw = contactsRaw[i];
            } else if (contactsRaw is Map) {
              contactRaw = contactsRaw[i] ?? contactsRaw[i.toString()];
            }

            if (contactRaw != null && contactRaw is Map) {
              final contact = Map<dynamic, dynamic>.from(contactRaw);

              nameControllers[i].text = contact["name"]?.toString() ?? "";
              phoneControllers[i].text = contact["phone"]?.toString() ?? "";
              relationshipControllers[i].text =
                  contact["relationship"]?.toString() ?? "";
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

  void clearAllControllers() {
    for (int i = 0; i < 3; i++) {
      nameControllers[i].clear();
      phoneControllers[i].clear();
      relationshipControllers[i].clear();
    }

    activeContactIndex = 0;
  }

  Future<void> migrateOldSingleContactSchema({
    required String uid,
    required String email,
  }) async {
    try {
      final contactsData = generateContactsData();

      await contactReference(uid).set({
        "uid": uid,
        "email": email,
        "activeContactIndex": activeContactIndex,
        "contacts": contactsData,
        "updatedAt": DateTime.now().toString(),
        "updatedAtEpoch": DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });
    } catch (e) {
      debugPrint("Migration failed: $e");
    }
  }

  List<Map<String, String>> generateContactsData() {
    return List.generate(
      3,
      (index) {
        return {
          "name": nameControllers[index].text.trim(),
          "phone": phoneControllers[index].text.trim(),
          "relationship": relationshipControllers[index].text.trim(),
        };
      },
    );
  }

  bool hasAnyContactField(int index) {
    return nameControllers[index].text.trim().isNotEmpty ||
        phoneControllers[index].text.trim().isNotEmpty ||
        relationshipControllers[index].text.trim().isNotEmpty;
  }

  bool isContactComplete(int index) {
    return nameControllers[index].text.trim().isNotEmpty &&
        phoneControllers[index].text.trim().isNotEmpty &&
        relationshipControllers[index].text.trim().isNotEmpty;
  }

  bool isPhoneValid(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), "");
    return digitsOnly.length >= 9;
  }

  Future<void> saveContacts() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      showMessage("Please login first.");
      return;
    }

    if (!isContactComplete(activeContactIndex)) {
      showMessage(
        "Please complete Contact ${activeContactIndex + 1} before selecting it as emergency contact.",
      );
      return;
    }

    final activePhone = phoneControllers[activeContactIndex].text.trim();

    if (!isPhoneValid(activePhone)) {
      showMessage("Contact ${activeContactIndex + 1} phone number is not valid.");
      return;
    }

    for (int i = 0; i < 3; i++) {
      if (hasAnyContactField(i) && !isContactComplete(i)) {
        showMessage(
          "Please complete all fields for Contact ${i + 1}, or leave it empty.",
        );
        return;
      }

      if (isContactComplete(i) && !isPhoneValid(phoneControllers[i].text.trim())) {
        showMessage("Contact ${i + 1} phone number is not valid.");
        return;
      }
    }

    setState(() {
      isSaving = true;
    });

    try {
      await contactReference(user.uid).set({
        "uid": user.uid,
        "email": user.email ?? "Unknown email",
        "activeContactIndex": activeContactIndex,
        "contacts": generateContactsData(),
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
    if (!isContactComplete(activeContactIndex)) {
      showMessage("Please complete Contact ${activeContactIndex + 1} first.");
      return;
    }

    final phone = phoneControllers[activeContactIndex].text.trim();

    if (!isPhoneValid(phone)) {
      showMessage("Invalid phone number.");
      return;
    }

    final uri = Uri(
      scheme: "tel",
      path: phone,
    );

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launched) {
      showMessage("Unable to open phone dialer.");
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Color getBackgroundColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF0F172A) : Colors.lightBlue.shade50;
  }

  Color getCardColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF1E293B) : Colors.white;
  }

  Color getInputColor(bool isDarkMode) {
    return isDarkMode ? const Color(0xFF0F172A) : Colors.grey.shade100;
  }

  Color getMainTextColor(bool isDarkMode) {
    return isDarkMode ? Colors.white : Colors.black87;
  }

  Color getSubTextColor(bool isDarkMode) {
    return isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700;
  }

  Widget buildHeader(bool isDarkMode) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.12),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emergency_rounded,
              color: Colors.white,
              size: 64,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            "Emergency Contacts",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Save up to 3 contacts and toggle which one to call during emergency.",
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              height: 1.4,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildContactToggleSection(bool isDarkMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Choose contact to call",
            style: TextStyle(
              color: getMainTextColor(isDarkMode),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            "Tap one contact below. The selected contact will be used for the emergency call button.",
            style: TextStyle(
              color: getSubTextColor(isDarkMode),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: List.generate(
              3,
              (index) {
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: index == 2 ? 0 : 8,
                    ),
                    child: buildContactToggleButton(index, isDarkMode),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildContactToggleButton(int index, bool isDarkMode) {
    final selected = activeContactIndex == index;
    final complete = isContactComplete(index);
    final name = nameControllers[index].text.trim();
    final relationship = relationshipControllers[index].text.trim();

    return GestureDetector(
      onTap: () {
        setState(() {
          activeContactIndex = index;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(
          vertical: 14,
          horizontal: 8,
        ),
        decoration: BoxDecoration(
          color: selected
              ? Colors.redAccent
              : isDarkMode
                  ? const Color(0xFF0F172A)
                  : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? Colors.redAccent
                : complete
                    ? Colors.green
                    : Colors.grey.withOpacity(0.35),
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: selected
                  ? Colors.white
                  : complete
                      ? Colors.green
                      : getSubTextColor(isDarkMode),
            ),
            const SizedBox(height: 8),
            Text(
              "Contact ${index + 1}",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: selected ? Colors.white : getMainTextColor(isDarkMode),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              name.isEmpty ? "Not set" : name,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: selected ? Colors.white70 : getSubTextColor(isDarkMode),
                fontSize: 11,
              ),
            ),
            if (relationship.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                relationship,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      selected ? Colors.white70 : getSubTextColor(isDarkMode),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget buildActiveContactCard(bool isDarkMode) {
    final index = activeContactIndex;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.person_pin_rounded,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  "Contact ${index + 1} Details",
                  style: TextStyle(
                    color: getMainTextColor(isDarkMode),
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Text(
                  "CALL TARGET",
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
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
        ],
      ),
    );
  }

  Widget buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDarkMode,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: (_) {
          setState(() {});
        },
        style: TextStyle(
          color: getMainTextColor(isDarkMode),
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: getInputColor(isDarkMode),
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

  Widget buildActionButtons(bool isDarkMode) {
    final activeName = nameControllers[activeContactIndex].text.trim();
    final activePhone = phoneControllers[activeContactIndex].text.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: getCardColor(isDarkMode),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDarkMode ? 0.25 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Colors.redAccent,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  activeName.isEmpty
                      ? "Selected: Contact ${activeContactIndex + 1}"
                      : "Selected: $activeName",
                  style: TextStyle(
                    color: getMainTextColor(isDarkMode),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (activePhone.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(
                  Icons.phone_rounded,
                  color: Colors.green,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    activePhone,
                    style: TextStyle(
                      color: getSubTextColor(isDarkMode),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: isSaving ? null : saveContacts,
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
              label: Text(
                isSaving ? "Saving Contacts..." : "Save All Contacts",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
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
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton.icon(
              onPressed: callEmergencyContact,
              icon: const Icon(Icons.call_rounded),
              label: Text(
                "Call Contact ${activeContactIndex + 1}",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(
                  color: Colors.redAccent,
                  width: 2,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
            ),
          ),
        ],
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

    return Scaffold(
      backgroundColor: getBackgroundColor(isDarkMode),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: getBackgroundColor(isDarkMode),
        foregroundColor: getMainTextColor(isDarkMode),
        title: const Text("Emergency Contacts"),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () {
              setState(() {
                isLoading = true;
              });

              loadContacts();
            },
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: RefreshIndicator(
                onRefresh: loadContacts,
                color: Colors.redAccent,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(18),
                  children: [
                    buildHeader(isDarkMode),
                    const SizedBox(height: 18),
                    buildContactToggleSection(isDarkMode),
                    const SizedBox(height: 18),
                    buildActiveContactCard(isDarkMode),
                    const SizedBox(height: 18),
                    buildActionButtons(isDarkMode),
                    const SizedBox(height: 18),
                  ],
                ),
              ),
            ),
    );
  }
}