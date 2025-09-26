import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'login_page.dart';
import 'item_page.dart';
import 'item_in_page.dart';
import 'item_out_page.dart';
import 'history_page.dart';
import 'dashboard_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
  }

  String getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return "Hello, Good morning!";
    } else if (hour < 17) {
      return "Hello, Good afternoon!";
    } else {
      return "Hello, Good evening!";
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final String displayName = user?.email?.split('@').first ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFFFF6F3D),
        onPressed: () => showAddItemDialog(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30.0),
        ),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          header(displayName, context),
          menuGrid(),
        ],
      ),
    );
  }

  Widget header(String displayName, BuildContext context) {
    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          // Positioned(
          //   top: 0, left: 0, right: 0, bottom: -50,
          //   child: Image.asset('src/header2.png', fit: BoxFit.cover),
          // ),
          // Positioned(
          //   top: 0, left: 0, right: 0, bottom: -30,
          //   child: Image.asset('src/header1.png', fit: BoxFit.cover),
          // ),
            Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 100, // Reduced height for the gradient background
            child: Container(
              decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFFF6F3D), Color(0xFFFF8E53)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                // bottomLeft: Radius.circular(30),
                // bottomRight: Radius.circular(30),
              ),
              ),
            ),
            ),
          Positioned(
            top: 24, left: 20,
            child: Row(
              children: [
                const CircleAvatar(backgroundImage: AssetImage('src/logo.png'), radius: 28),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(getGreeting(), style: const TextStyle(color: Colors.white, fontSize: 14)),
                    Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            top: 25, right: 10,
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.white),
              onSelected: (value) {
                if (value == 'logout') logout(context);
              },
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'logout', 
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Logout'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget menuGrid() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
      child: Wrap(
        spacing: 15,
        runSpacing: 15,
        alignment: WrapAlignment.start,
        children: const [
          MenuImageItem(imagePath: 'src/dashboard.png', label: 'Dashboard'),
          MenuImageItem(imagePath: 'src/item.png', label: 'Stok Barang'),
          MenuImageItem(imagePath: 'src/itemin.png', label: 'Barang Masuk'),
          MenuImageItem(imagePath: 'src/itemout.png', label: 'Barang Keluar'),
          MenuImageItem(imagePath: 'src/history.png', label: 'History'),
        ],
      ),
    );
  }

  // Cloudinary configuration
  static const String cloudName = "do0v30ppn";
  static const String uploadPreset = "ml_default";

Future<String?> _uploadToCloudinary(File imageFile, String itemId) async {
  try {
    final uri = Uri.parse('https://api.cloudinary.com/v1_1/$cloudName/image/upload');
    var request = http.MultipartRequest('POST', uri);
    request.files.add(await http.MultipartFile.fromPath('file', imageFile.path));
    request.fields['upload_preset'] = uploadPreset;
    request.fields['folder'] = 'inventory_items';
    request.fields['public_id'] = 'item_$itemId';
    final response = await request.send();
    
    if (response.statusCode == 200) {
      final responseBody = await response.stream.bytesToString();
      final jsonResponse = json.decode(responseBody);
      return jsonResponse['secure_url'];
    } else {
      final errorBody = await response.stream.bytesToString();
      print('Upload failed with status: ${response.statusCode}');
      print('Error response: $errorBody');
      return null;
    }
  } catch (e) {
    print('Upload error: $e');
    return null;
  }
}

// Helper function to generate item-specific image URL with transformations
String generateImageUrl(String itemId) {
  // Apply transformations in the URL instead of during upload
  return 'https://res.cloudinary.com/$cloudName/image/upload/w_800,h_600,c_fill,q_auto/inventory_items/item_$itemId';
}

// Helper function to get transformed image URL for display
String getItemImageUrl(String itemId) {
  return generateImageUrl(itemId);
}

  // Modified pick and upload function
  Future<String?> _pickAndUploadImage(ImageSource source, String itemId) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (image != null) {
        final File imageFile = File(image.path);
        
        // Validate image file
        if (!_validateImageFile(imageFile)) {
          return null;
        }

        return await _uploadToCloudinary(imageFile, itemId);
      }
      return null;
    } catch (e) {
      print('Error picking image: $e');
      return null;
    }
  }

  bool _validateImageFile(File imageFile) {
    // Check file size (maximum 5MB)
    final fileSizeInBytes = imageFile.lengthSync();
    final fileSizeInMB = fileSizeInBytes / (1024 * 1024);
    
    if (fileSizeInMB > 5) {
      return false;
    }
    
    // Check file extension
    final extension = imageFile.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png', 'gif'].contains(extension)) {
      return false;
    }
    
    return true;
  }

  void showAddItemDialog(BuildContext context) {
    final skuCtrl = TextEditingController();
    final merkCtrl = TextEditingController();
    final nameCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    String? selectedCategory;
    String? imageUrl;
    String? skuErr, merkErr, nameErr, amountErr, categoryErr;
    List<String> categories = [];
    bool isUploadingImage = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> loadCategories() async {
              final snapshot = await FirebaseFirestore.instance.collection('categories').get();
              categories = snapshot.docs.map((doc) => doc.id).toList();
              setState(() {});
            }

            if (categories.isEmpty) loadCategories();

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 5),
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "TAMBAH BARANG",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF666666),
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 25),
                      
// Replace the existing Image Upload Section in your showAddItemDialog method
// with this updated version:

// Image Upload Section
Container(
  width: double.infinity,
  height: 150,
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(15),
    border: Border.all(
      color: const Color.fromARGB(255, 160, 160, 160),
      width: 1,
    ),
  ),
  child: imageUrl != null
      ? Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: Image.network(
                imageUrl!,
                width: double.infinity,
                height: 150,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => setState(() => imageUrl = null),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.8),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),
          ],
        )
      : isUploadingImage
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6F3D)),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Uploading...',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
          : InkWell(
              onTap: () async {
                final sku = skuCtrl.text.trim();
                if (sku.isEmpty) {
                  _showErrorDialog(context, 'Please enter SKU first');
                  return;
                }
                
                // Show image source selection dialog
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Container(
                    margin: const EdgeInsets.all(20),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Pilih Sumber Foto',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF333333),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            // Camera Option
                            GestureDetector(
                              onTap: () async {
                                Navigator.pop(context);
                                setState(() => isUploadingImage = true);
                                final url = await _pickAndUploadImage(ImageSource.camera, sku);
                                setState(() {
                                  isUploadingImage = false;
                                  if (url != null) imageUrl = url;
                                });
                              },
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6F3D).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: const Color(0xFFFF6F3D),
                                    width: 2,
                                  ),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 35,
                                      color: Color(0xFFFF6F3D),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Kamera',
                                      style: TextStyle(
                                        color: Color(0xFFFF6F3D),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            // Gallery Option
                            GestureDetector(
                              onTap: () async {
                                Navigator.pop(context);
                                setState(() => isUploadingImage = true);
                                final url = await _pickAndUploadImage(ImageSource.gallery, sku);
                                setState(() {
                                  isUploadingImage = false;
                                  if (url != null) imageUrl = url;
                                });
                              },
                              child: Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFF6F3D).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(
                                    color: const Color(0xFFFF6F3D),
                                    width: 2,
                                  ),
                                ),
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.photo_library,
                                      size: 35,
                                      color: Color(0xFFFF6F3D),
                                    ),
                                    SizedBox(height: 5),
                                    Text(
                                      'Galeri',
                                      style: TextStyle(
                                        color: Color(0xFFFF6F3D),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            'Batal',
                            style: TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8E8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.add_a_photo,
                        size: 50,
                        color: Color(0xFF999999),
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      'Tambahkan foto Barang',
                      style: TextStyle(
                        color: Color(0xFF999999),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
),
                      const SizedBox(height: 15),
                      
                      _buildRoundedTextField(skuCtrl, 'SKU', errorText: skuErr),
                      const SizedBox(height: 5),
                      
                      _buildRoundedTextField(merkCtrl, 'MERK', errorText: merkErr),
                      const SizedBox(height: 5),
                      
                      _buildRoundedTextField(nameCtrl, 'NAMA BARANG', errorText: nameErr),
                      const SizedBox(height: 5),
                      
                      _buildRoundedTextField(amountCtrl, 'JUMLAH', errorText: amountErr, inputType: TextInputType.number),
                      const SizedBox(height: 10),
                      
                      const Text(
                        "Kategori",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color.fromARGB(255, 75, 75, 75),
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                            color: categoryErr != null ? Colors.red : const Color.fromARGB(255, 160, 160, 160),
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            hint: const Text(
                              'Pilih kategori',
                              style: TextStyle(
                                color: Color.fromARGB(255, 126, 126, 126),
                                fontSize: 14,
                              ),
                            ),
                            isExpanded: true,
                            icon: const Icon(
                              Icons.keyboard_arrow_down,
                              color: Color(0xFF666666),
                            ),
                            items: categories.map((cat) => DropdownMenuItem(
                              value: cat, 
                              child: Text(
                                cat,
                                style: const TextStyle(
                                  color: Color(0xFF333333),
                                  fontSize: 14,
                                ),
                              ),
                            )).toList(),
                            onChanged: (val) => setState(() => selectedCategory = val),
                          ),
                        ),
                      ),
                      if (categoryErr != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, left: 16),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              categoryErr!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () async {
                              final newCat = await showAddCategoryDialog(context);
                              if (newCat != null) {
                                selectedCategory = newCat;
                                loadCategories();
                              }
                            },
                            child: const Text(
                              "Tambah kategori +",
                              style: TextStyle(
                                color: Color(0xFFFF6F3D),
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (categories.isNotEmpty)
                            TextButton(
                              onPressed: () async {
                                await showDeleteCategoryDialog(context, categories);
                                loadCategories();
                              },
                              child: const Text(
                                "Hapus Kategori",
                                style: TextStyle(
                                  color: Color.fromARGB(255, 85, 85, 85),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      Row(
                        children: [
                          // Save Button
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: isUploadingImage ? null : () async {
                                  final sku = skuCtrl.text.trim();
                                  final merk = merkCtrl.text.trim();
                                  final name = nameCtrl.text.trim();
                                  final amountText = amountCtrl.text.trim();

                                  setState(() {
                                    skuErr = sku.isEmpty ? 'Required' : null;
                                    merkErr = merk.isEmpty ? 'Required' : null;
                                    nameErr = name.isEmpty ? 'Required' : null;
                                    amountErr = amountText.isEmpty ? 'Required' : null;
                                    categoryErr = selectedCategory == null ? 'Select category' : null;
                                  });

                                  if ([skuErr, merkErr, nameErr, amountErr, categoryErr].any((e) => e != null)) return;

                                  final amount = int.tryParse(amountText);
                                  if (amount == null) {
                                    setState(() => amountErr = 'Must be a number');
                                    return;
                                  }

                                  final ref = FirebaseFirestore.instance
                                      .collection('categories')
                                      .doc(selectedCategory)
                                      .collection('items')
                                      .doc(sku);

                                  final exists = await ref.get();
                                  if (exists.exists) {
                                    setState(() => skuErr = 'SKU sudah digunakan');
                                    return;
                                  }

                                  try {
                                    // If no image was uploaded, generate the default image URL
                                    final finalImageUrl = imageUrl ?? generateImageUrl(sku);
                                    
                                    await ref.set({
                                      'sku': sku,
                                      'merk': merk,
                                      'name': name,
                                      'amount': amount,
                                      'imageUrl': finalImageUrl,
                                      'hasCustomImage': imageUrl != null, // Track if custom image exists
                                      'timestamp': FieldValue.serverTimestamp(),
                                    });

                                    await HistoryHelper.addHistoryEntry(
                                      action: 'item_added',
                                      itemSku: sku,
                                      itemName: name,
                                      itemMerk: merk,
                                      category: selectedCategory!,
                                      amount: amount,
                                      description: 'New item added to inventory',
                                    );

                                    Navigator.pop(context);
                                    _showSuccessDialog(context, 'Item "$name" added successfully');
                                  } catch (e) {
                                    _showErrorDialog(context, 'Failed to add item: ${e.toString()}');
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isUploadingImage ? Colors.grey : const Color(0xFFFF6F3D),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "Simpan",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(width: 16),
                          
                          Expanded(
                            child: SizedBox(
                              height: 50,
                              child: ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF666666),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(25),
                                  ),
                                  elevation: 0,
                                ),
                                child: const Text(
                                  "Batal",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildRoundedTextField(
    TextEditingController controller, 
    String hint, {
    TextInputType? inputType,
    String? errorText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 255, 255, 255),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: errorText != null ? Colors.red : const Color.fromARGB(255, 136, 136, 136),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: inputType,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                color: Color.fromARGB(255, 117, 117, 117),
                fontSize: 14,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            style: const TextStyle(
              color: Color.fromARGB(255, 114, 114, 114),
              fontSize: 14,
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 16),
            child: Text(
              errorText,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }

  Future<String?> showAddCategoryDialog(BuildContext context) async {
    final controller = TextEditingController();
    String? error;

    return await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Add Category"),
            content: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: "Enter category name",
                errorText: error,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
              TextButton(
                onPressed: () async {
                  final name = controller.text.trim();
                  if (name.isEmpty) {
                    setState(() => error = 'Category name cannot be empty');
                    return;
                  }

                  final exists = await FirebaseFirestore.instance.collection('categories').doc(name).get();
                  if (exists.exists) {
                    setState(() => error = 'Category already exists');
                    return;
                  }

                  try {
                    await FirebaseFirestore.instance.collection('categories').doc(name).set({
                      'created_at': FieldValue.serverTimestamp(),
                    });
                    
                    Navigator.pop(context, name);
                    _showSuccessDialog(context, 'Category "$name" created successfully');
                  } catch (e) {
                    _showErrorDialog(context, 'Failed to create category: ${e.toString()}');
                  }
                },
                child: const Text("Add"),
              ),
            ],
          );
        });
      },
    );
  }

  Future<void> showDeleteCategoryDialog(BuildContext context, List<String> categories) async {
    String? selectedCategory;
    String? error;

    return await showDialog<void>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Delete Category", style: TextStyle(color: Colors.red)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Select a category to delete:"),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: selectedCategory,
                  hint: const Text('Select Category'),
                  items: categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                  onChanged: (val) => setState(() => selectedCategory = val),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    errorText: error,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  "Warning: This will delete the category and ALL items within it!",
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () async {
                  if (selectedCategory == null) {
                    setState(() => error = 'Please select a category');
                    return;
                  }

                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Confirm Delete"),
                      content: Text("Are you sure you want to delete category '$selectedCategory' and all its items?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text("Cancel"),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true) {
                    try {
                      final itemsSnapshot = await FirebaseFirestore.instance
                          .collection('categories')
                          .doc(selectedCategory!)
                          .collection('items')
                          .get();

                      final batch = FirebaseFirestore.instance.batch();
                      for (final doc in itemsSnapshot.docs) {
                        batch.delete(doc.reference);
                      }

                      final categoryRef = FirebaseFirestore.instance.collection('categories').doc(selectedCategory!);
                      batch.delete(categoryRef);

                      await batch.commit();

                      Navigator.pop(context);
                      _showSuccessDialog(context, 'Category "$selectedCategory" deleted successfully');
                    } catch (e) {
                      _showErrorDialog(context, 'Failed to delete category: ${e.toString()}');
                    }
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text("Delete"),
              ),
            ],
          );
        });
      },
    );
  }

  Widget buildTextField(TextEditingController ctrl, String hint,
      {TextInputType? inputType, String? errorText}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: ctrl,
        keyboardType: inputType,
        decoration: InputDecoration(
          hintText: hint,
          errorText: errorText,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 2), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFFF6F3D),
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        Future.delayed(const Duration(seconds: 3), () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        });

        return Dialog(
          backgroundColor: Colors.transparent,
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Flexible(
                    child: Text(
                      message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class MenuImageItem extends StatelessWidget {
  final String imagePath;
  final String label;
  const MenuImageItem({super.key, required this.imagePath, required this.label});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        if (label == 'Dashboard') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const DashboardPage()),
          );
        } else if (label == 'Stok Barang') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ItemPage()),
          );
        } else if (label == 'Barang Masuk') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ItemInPage()),
          );
        } else if(label == 'Barang Keluar') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ItemOutPage()),
          );
        } else if(label == 'History') {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const HistoryPage()),
          );
        }
      },
      child: Container(
        height: 90,
        width: 90,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F1F1),
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 2, offset: Offset(1, 2))],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(imagePath, height: 55, width: 55),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}