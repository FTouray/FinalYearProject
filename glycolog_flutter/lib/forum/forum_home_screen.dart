import 'package:glycolog/home/base_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:glycolog/services/auth_service.dart';
import 'forum_thread_list_screen.dart';

class ForumHomeScreen extends StatefulWidget {
  const ForumHomeScreen({super.key});

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
      errorMessage = null;
    });

    try {
      final token = await AuthService().getAccessToken();
      final headers = {'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

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
          errorMessage = "Failed to load categories (${response.statusCode})";
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        errorMessage = "Error: $e";
        isLoading = false;
      });
    }
  }

  Future<void> _createCategoryDialog() async {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("📝 Create a New Category"),
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
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, "create"),
            child: const Text("Create"),
          ),
        ],
      ),
    );

    if (result == "create" && nameController.text.trim().isNotEmpty) {
      final token = await AuthService().getAccessToken();
      final headers = {'Content-Type': 'application/json'};
      if (token != null) headers['Authorization'] = 'Bearer $token';

      final payload = {
        "name": nameController.text.trim(),
        "description": descController.text.trim(),
      };

      final response = await http.post(
        Uri.parse("$apiUrl/forum/category/create/"),
        headers: headers,
        body: jsonEncode(payload),
      );

      if (response.statusCode == 201) {
        await fetchCategories();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("✅ Category created!")),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("⚠️ Failed to create (code ${response.statusCode})")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BaseScaffoldScreen(
      selectedIndex: 1,
      onItemTapped: (index) {
        final routes = ['/home', '/forum', '/settings'];
        if (index >= 0 && index < routes.length) {
          Navigator.pushNamed(context, routes[index]);
        }
      },
      body: Scaffold(
        appBar: AppBar(
          title: const Text("💬 Community Forum"),
          actions: [
            IconButton(
                icon: const Icon(Icons.refresh), onPressed: fetchCategories),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12.0),
          child: isLoading
              ? const Center(child: CircularProgressIndicator())
              : errorMessage != null
                  ? Center(
                      child: Text(errorMessage!,
                          style:
                              const TextStyle(color: Colors.red, fontSize: 16)),
                    )
                  : categories.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text("No categories found 💤",
                                  style: TextStyle(fontSize: 18)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.add),
                                label: const Text("Create a Category"),
                                onPressed: _createCategoryDialog,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final category = categories[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(vertical: 8),
                              child: ListTile(
                                contentPadding: const EdgeInsets.all(12),
                                title: Text(
                                  category['name'] ?? 'Unnamed Category',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16),
                                ),
                                subtitle: Text(
                                  category['description'] ??
                                      'No description provided.',
                                  style: const TextStyle(fontSize: 14),
                                ),
                                leading:
                                    const Icon(Icons.forum, color: Colors.blue),
                                trailing: const Icon(Icons.arrow_forward_ios,
                                    size: 16),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ForumThreadListScreen(
                                      categoryId: category['id'],
                                      categoryName: category['name'],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _createCategoryDialog,
          label: const Text("New Category"),
          icon: const Icon(Icons.add),
          backgroundColor: Colors.blueAccent,
        ),
      ),
    );
  }
}
