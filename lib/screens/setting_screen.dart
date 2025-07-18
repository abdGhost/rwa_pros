import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_switch/flutter_switch.dart';
import 'package:rwa_app/provider/settings_provider.dart';
import 'package:rwa_app/screens/botttom_nav_screen.dart';
import 'package:rwa_app/screens/select_language_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDarkMode = ref.watch(themeModeProvider) == ThemeMode.dark;
    final selectedCurrency = ref.watch(currencyProvider);
    final selectedLanguage = ref.watch(languageProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value:
          isDarkMode ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Text(
                  "Just one last thing",
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Set up your preferred theme, currency, language and you’re good to go",
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                Text(
                  "App setting",
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(
                        color: isDarkMode ? Colors.black26 : Colors.black12,
                        offset: const Offset(0, 4),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      settingTile(
                        context,
                        title: "Dark Mode",
                        trailing: FlutterSwitch(
                          width: 40,
                          height: 20,
                          toggleSize: 16,
                          value: isDarkMode,
                          activeColor: Color(0xFF0087E0),
                          inactiveColor: const Color.fromRGBO(91, 91, 91, 1),
                          toggleColor: Colors.white,
                          onToggle: (val) {
                            ref.read(themeModeProvider.notifier).toggle(val);
                          },
                        ),
                      ),
                      divider(),
                      settingTile(
                        context,
                        title: "Currency",
                        trailing: DropdownButton<String>(
                          value: selectedCurrency,
                          dropdownColor: theme.cardColor,
                          onChanged: null,
                          icon: const SizedBox.shrink(),
                          // onChanged: (value) {
                          //   if (value != null) {
                          //     ref.read(currencyProvider.notifier).set(value);
                          //   }
                          // },
                          items:
                              ['USD', 'EUR', 'INR'].map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(
                                    c,
                                    style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color,
                                      fontSize: 13,
                                    ),
                                  ),
                                );
                              }).toList(),
                          underline: const SizedBox(),
                        ),
                      ),

                      divider(),
                      InkWell(
                        // onTap: () {
                        //   Navigator.push(
                        //     context,
                        //     MaterialPageRoute(
                        //       builder:
                        //           (context) => const SelectLanguageScreen(),
                        //     ),
                        //   );
                        // },
                        child: settingTile(
                          context,
                          title: "Language",
                          trailing: Text(
                            selectedLanguage,
                            style: TextStyle(
                              color: theme.textTheme.bodyMedium?.color,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Center(
                  child: Text(
                    "You can always change or customise these settings later",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BottomNavScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    child: const Text("Finish"),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget settingTile(
    BuildContext context, {
    required String title,
    required Widget trailing,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Text(
            title,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }

  Widget divider() {
    return const Divider(
      height: 0,
      color: Color.fromRGBO(70, 85, 104, 0.3),
      thickness: 0.4,
    );
  }
}
