import 'package:flutter/material.dart';

class SelectLanguageScreen extends StatefulWidget {
  const SelectLanguageScreen({super.key});

  @override
  State<SelectLanguageScreen> createState() => _SelectLanguageScreenState();
}

class _SelectLanguageScreenState extends State<SelectLanguageScreen> {
  final TextEditingController _searchController = TextEditingController();
  String selectedLanguage = 'English';

  final List<String> allLanguages = [
    'English',
    'Espanol',
    'Deutsch',
    'Portugues',
    'Francais',
    'Italiano',
    'jezyk polski',
    'Bahasa Indonesia',
    'Chinese',
    'Korean',
    'Japanese',
    'Arabic',
    'Vietnamese',
    'Turkish',
    'Malay',
  ];

  @override
  Widget build(BuildContext context) {
    final filteredLanguages =
        allLanguages
            .where(
              (lang) => lang.toLowerCase().contains(
                _searchController.text.toLowerCase(),
              ),
            )
            .toList();

    return Scaffold(
      backgroundColor: const Color.fromRGBO(247, 247, 247, 1),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.arrow_back_ios, size: 18),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Select Language',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),

            // Search Bar (fixed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'Search for a language',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Colors.black12),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Language List inside a Card (Scrollable only this part)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: const Color.fromRGBO(0, 0, 0, 0.1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 5,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListView.separated(
                    itemCount: filteredLanguages.length,
                    itemBuilder: (context, index) {
                      final lang = filteredLanguages[index];
                      final isSelected = lang == selectedLanguage;

                      return ListTile(
                        title: Text(
                          lang,
                          style: const TextStyle(
                            color: Color.fromRGBO(29, 29, 29, 0.7),
                            fontSize: 14,
                          ),
                        ),
                        trailing:
                            isSelected
                                ? const Icon(
                                  Icons.check,
                                  color: Color(0xFF348F6C),
                                  size: 20,
                                )
                                : null,
                        selected: isSelected,
                        selectedTileColor: const Color(0xFFEAF5F1),
                        onTap: () {
                          setState(() {
                            selectedLanguage = lang;
                          });
                        },
                      );
                    },
                    separatorBuilder:
                        (_, __) => const Divider(
                          height: 0,
                          thickness: 0.5,
                          color: Color.fromRGBO(70, 85, 104, 0.2),
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
