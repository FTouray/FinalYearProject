import 'package:Glycolog/home/base_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import 'package:Glycolog/services/auth_service.dart';

import 'forum_thread_list_screen.dart';

class ForumHomeScreen extends StatefulWidget {
  const ForumHomeScreen({Key? key}) : super(key: key);

  @override
  State<ForumHomeScreen> createState() => _ForumHomeScreenState();
}

class _ForumHomeScreenState extends State<ForumHomeScreen> {
  List categories = [];
  bool isLoading = true;
  String? errorMessage;
  final String? apiUrl = dotenv.env['API_URL'];

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    setState(() {
      isLoading = true;
      errorMessage = null; // reset error
    });

    try {
      final token = await AuthService().getAccessToken();
      final headers = {
        'Content-Type': 'application/json',
      };
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        Uri.parse("$apiUrl/forum/categories/"),
        headers: headers,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          categories = data is List ? data : [];
          isLoading = false;
        });
      } else {
        setState(() {
          errorMessage =
              "Failed to load categories (status code ${response.statusCode})";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error fetching categories: $e";
        isLoading = false;
      });
    }
  }

  Future<void> _createCategoryDialog() async {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController descController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Create Category"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: "Category Name"),
            ),
            TextField(
              controller: descController,
              decoration: const InputDecoration(labelText: "Description"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, "create"),
            child: const Text("Create"),
          ),
        ],
      ),
    );

    if (result == "create" && nameController.text.trim().isNotEmpty) {
      try {
        final token = await AuthService().getAccessToken();
        final headers = {
          'Content-Type': 'application/json',
        };
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }

        final payload = {
          "name": nameController.text.trim(),
          "description": descController.text.trim(),
        };

        final response = await http.post(
          Uri.parse("$apiUrl/forum/category/create/"),
          headers: headers,
          body: jsonEncode(payload),
        );

        if (!mounted) return;

        if (response.statusCode == 201) {
          await fetchCategories();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Category created successfully!")),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  "Failed to create category (code ${response.statusCode})"),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error creating category: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffoldScreen(
      selectedIndex: 1, // Forum tab index
      onItemTapped: (index) {
        final routes = ['/home', '/forum', '/settings'];
        if (index >= 0 && index < routes.length) {
          Navigator.pushNamed(context, routes[index]);
        }
      },
      body: Scaffold(
        appBar: AppBar(
          title: const Text("Community Forum"),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: fetchCategories,
              tooltip: "Refresh",
            ),
          ],
        ),
        body: Builder(
          builder: (ctx) {
            if (isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (errorMessage != null) {
              return Center(
                child: Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 16),
                ),
              );
            }

            if (categories.isEmpty) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "No categories found.\nBe the first to create one!",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _createCategoryDialog,
                      icon: const Icon(Icons.add),
                      label: const Text("Create Category"),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                return ListTile(
                  title: Text(category['name'] ?? 'Unnamed Category'),
                  subtitle: Text(category['description'] ?? ''),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ForumThreadListScreen(
                        categoryId: category['id'],
                        categoryName: category['name'],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _createCategoryDialog,
          child: const Icon(Icons.add),
          tooltip: "Create a New Category",
        ),
      ),
    );
  }

}
