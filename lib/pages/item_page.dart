import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'history_page.dart';

class ItemPage extends StatefulWidget {
  const ItemPage({super.key});

  @override
  State<ItemPage> createState() => _ItemPageState();
}

class _ItemPageState extends State<ItemPage> with TickerProviderStateMixin {
  String selectedCategory = 'All';
  List<String> categories = ['All'];
  List<Map<String, dynamic>> allItems = [];
  List<Map<String, dynamic>> filteredItems = [];
  TextEditingController searchController = TextEditingController();
  bool _isRefreshing = false;
  bool _isInitialLoading = true; // Tambahkan ini


  late AnimationController _loadingAnimationController;
  late AnimationController _fadeAnimationController;
  

  late Animation<double> _loadingAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    

    _loadingAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat();
    
    _loadingAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _loadingAnimationController,
      curve: Curves.easeInOut,
    ));


    _fadeAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _fadeAnimationController.forward();
    
    loadCategories();
    loadAllItems();
    _initializeData();
    searchController.addListener(_filterItems);
  }

  @override
  void dispose() {
    searchController.dispose();
    _loadingAnimationController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }

 Future<void> _initializeData() async {
    setState(() {
      _isInitialLoading = true;
    });
    
    await Future.delayed(const Duration(milliseconds: 500)); // Delay untuk animasi
    
    await loadCategories();
    await loadAllItems();
    
    if (mounted) {
      setState(() {
        _isInitialLoading = false;
      });
    }
  }
  Future<void> loadCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('categories').get();
      final categoryList = snapshot.docs.map((doc) => doc.id).toList();
      if (mounted) {
        setState(() {
          categories = ['All', ...categoryList];
        });
      }
    } catch (e) {
      print('Error loading categories: $e');
    }
  }

Future<void> loadAllItems() async {
  try {
    final categoriesSnapshot = await FirebaseFirestore.instance.collection('categories').get();
    List<Map<String, dynamic>> items = [];

    for (var categoryDoc in categoriesSnapshot.docs) {
      final itemsSnapshot = await categoryDoc.reference.collection('items').get();
      
      for (var itemDoc in itemsSnapshot.docs) {
        final itemData = itemDoc.data();
        
        // Ambil data history berdasarkan SKU
        final historyData = await _getItemHistoryData(itemData['sku'] ?? '');
        
        items.add({
          ...itemData,
          'category': categoryDoc.id,
          'docId': itemDoc.id,
          // Override dengan data dari history
          'dateAdded': historyData['dateAdded'],
          'lastModified': historyData['lastModified'],
          'editedBy': historyData['editedBy'],
        });
      }
    }

    if (mounted) {
      setState(() {
        allItems = items;
        filteredItems = items;
      });
    }
  } catch (e) {
    print('Error loading items: $e');
  }
}

Future<Map<String, dynamic>> _getItemHistoryData(String sku) async {
  try {
    // Ambil history berdasarkan SKU, diurutkan berdasarkan timestamp
    final historySnapshot = await FirebaseFirestore.instance
        .collection('history')
        .where('itemSku', isEqualTo: sku)
        .orderBy('timestamp', descending: false)
        .get();

    if (historySnapshot.docs.isEmpty) {
      return {
        'dateAdded': null,
        'lastModified': null,
        'editedBy': null,
      };
    }

    // Ambil entry pertama (tanggal masuk)
    final firstEntry = historySnapshot.docs.first.data();
    
    // Ambil entry terakhir (terakhir edit)
    final lastEntry = historySnapshot.docs.last.data();

    return {
      'dateAdded': firstEntry['timestamp'],
      'lastModified': lastEntry['timestamp'],
      'editedBy': lastEntry['editedBy'] ?? 'Unknown',
    };
  } catch (e) {
    print('Error getting history data: $e');
    return {
      'dateAdded': null,
      'lastModified': null,
      'editedBy': null,
    };
  }
}

  void _filterItems() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredItems = allItems.where((item) {
        final matchesSearch = query.isEmpty ||
            item['name'].toString().toLowerCase().contains(query) ||
            item['sku'].toString().toLowerCase().contains(query) ||
            item['merk'].toString().toLowerCase().contains(query);
        
        final matchesCategory = selectedCategory == 'All' || 
            item['category'] == selectedCategory;
        
        return matchesSearch && matchesCategory;
      }).toList();
    });
  }


 Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {
      // Delay untuk menunjukkan animasi loading
      await Future.delayed(const Duration(milliseconds: 800));
      
      await loadCategories();
      await loadAllItems();
      
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  String _formatDate(dynamic dateValue) {
    if (dateValue == null) return 'N/A';
    
    try {
      if (dateValue is Timestamp) {
        final date = dateValue.toDate();
        return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
      } else if (dateValue is String) {

        final date = DateTime.tryParse(dateValue);
        if (date != null) {
          return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
        }
        return dateValue;
      }
      return dateValue.toString();
    } catch (e) {
      return 'Invalid Date';
    }
  }


  Future<void> _launchGoogleDriveUrl(String? url) async {
    if (url == null || url.isEmpty || url == 'N/A') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak ada link dokumentasi tersedia'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      final Uri uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal membuka link: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F1F1),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchAndFilter(),
            Expanded(child: _buildItemsList()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 100,
      decoration: const BoxDecoration(
        color: Color(0xFFFF6F3D),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.arrow_back, color: Colors.white, size: 16),
                      SizedBox(width: 4),
                      Text('Kembali', style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
              const Expanded(
                child: Center(
                  child: Text(
                    'Barang',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 60),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchAndFilter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                hintText: 'cari berdasarkan sku atau nama',
                hintStyle: TextStyle(color: Colors.grey[500]),
                prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 15),
          SizedBox(
            width: 110,
            child: DropdownButtonFormField<String>(
              value: selectedCategory,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              style: const TextStyle(fontSize: 14, color: Colors.black),
              decoration: InputDecoration(
                labelText: 'Filter',
                labelStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey[400]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFFF6F3D)),
                ),
              ),
              items: categories.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value!;
                });
                _filterItems();
              },
            ),
          ),
        ],
      ),
    );
  }

 Widget _buildItemsList() {
    // Jika initial loading
    if (_isInitialLoading) {
      return _buildAnimatedLoadingWidget();
    }
    
    // Jika masih loading refresh dan belum ada data
    if (allItems.isEmpty && _isRefreshing) {
      return _buildAnimatedLoadingWidget();
    }

    // Jika tidak ada data sama sekali setelah loading selesai
    if (allItems.isEmpty && !_isRefreshing) {
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 800),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        curve: Curves.easeOutCubic,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 30 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: value,
                      child: Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Data tidak ditemukan',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
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

    // Jika ada data tapi hasil filter kosong
    if (filteredItems.isEmpty) {
      return TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 600),
        tween: Tween<double>(begin: 0.0, end: 1.0),
        curve: Curves.easeOutBack,
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: Opacity(
              opacity: value,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Transform.scale(
                      scale: 0.8 + (0.2 * value),
                      child: Icon(Icons.search_off, size: 64, color: Colors.grey[400]),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Data tidak ditemukan',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      searchController.text.isEmpty 
                        ? 'Tidak ada item dalam kategori ini' 
                        : 'Tidak ada item yang sesuai dengan pencarian',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 14,
                      ),
                    ),
                    if (searchController.text.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Coba kata kunci yang berbeda',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: const Color(0xFFFF6F3D),
      backgroundColor: Colors.white,
      strokeWidth: 3.0,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filteredItems.length,
        itemBuilder: (context, index) {
          final item = filteredItems[index];
          
          return TweenAnimationBuilder<double>(
            duration: Duration(milliseconds: 300 + (index * 100)),
            tween: Tween<double>(begin: 0.0, end: 1.0),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(50 * (1 - value), 0),
                child: Opacity(
                  opacity: value,
                  child: _buildItemCard(item),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildAnimatedLoadingWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [

          AnimatedBuilder(
            animation: _loadingAnimation,
            builder: (context, child) {
              return Transform.rotate(
                angle: _loadingAnimation.value * 2 * 3.14159,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(
                      colors: [
                        const Color(0xFFFF6F3D).withOpacity(0.1),
                        const Color(0xFFFF6F3D),
                        const Color(0xFFFF6F3D).withOpacity(0.1),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                  child: Center(
                    child: Image.asset(
                      'src/item.png',
                      width: 30,
                      height: 30,
                      color: Colors.white,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.inventory_2,
                          color: Colors.white,
                          size: 30,
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          

          AnimatedBuilder(
            animation: _loadingAnimation,
            builder: (context, child) {
              int dotCount = ((_loadingAnimation.value * 3) % 3).floor() + 1;
              String dots = '.' * dotCount;
              
              return Text(
                'Loading items$dots',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
          

          AnimatedBuilder(
            animation: _loadingAnimation,
            builder: (context, child) {
              return Container(
                width: 200,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (_loadingAnimation.value * 0.8) + 0.2,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF6F3D), Color(0xFFFF8A65)],
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [

          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 50,
            height: 50,
            child: Center(
              child: Image.asset(
                'src/item.png',
                width: 55,
                height: 55,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.inventory_2,
                    color: Color(0xFFFF6F3D),
                    size: 30,
                  );
                },
              ),
            ),
          ),
          const SizedBox(width: 16),
          

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black,
                  ),
                  child: Text(item['name'] ?? 'Unknown Item'),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 200),
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  child: Text('${item['merk'] ?? 'Unknown'} • ${item['sku'] ?? 'Unknown'}'),
                ),
                const SizedBox(height: 2),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 300),
                  style: TextStyle(
                    color: (item['amount'] ?? 0) > 0 ? Colors.green[700] : Colors.red[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                  child: Text('Stok: ${item['amount'] ?? 0}'),
                ),
              ],
            ),
          ),
          

          Row(
            children: [
              AnimatedScale(
                duration: const Duration(milliseconds: 150),
                scale: 1.0,
                child: GestureDetector(
                  onTap: () => _confirmDelete(context, item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              AnimatedScale(
                duration: const Duration(milliseconds: 150),
                scale: 1.0,
                child: GestureDetector(
                  onTap: () => _showItemInfo(context, item),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF6F3D).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      color: Color(0xFFFF6F3D),
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showItemInfo(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: 0.7 + (0.3 * value),
                child: Opacity(
                  opacity: value,
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 600),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [

                        Container(
                          padding: const EdgeInsets.all(20),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 50,
                                height: 50,
                                child: Image.asset(
                                  'src/item.png',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.inventory_2,
                                      color: Color(0xFFFF6F3D),
                                      size: 30,
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'] ?? 'Unknown Item',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    Text(
                                      item['category'] ?? 'Unknown Category',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(Icons.close, color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        

                        Flexible(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [

                                _buildInfoRow('SKU', item['sku']?.toString() ?? 'N/A'),
                                _buildInfoRow('Nama', item['name']?.toString() ?? 'N/A'),
                                _buildInfoRow('Merk', item['merk']?.toString() ?? 'N/A'),
                                _buildInfoRow('Jumlah Stok', item['amount']?.toString() ?? '0'),
                                

                                _buildInfoRowWithDescription(
                                  'Tanggal Masuk', 
                                  _formatDate(item['dateAdded']),
                                  'Tanggal pertama kali item ini ditambahkan ke dalam sistem inventori'
                                ),
                                
                                _buildInfoRowWithDescription(
                                  'Terakhir Edit', 
                                  _formatDate(item['lastModified']),
                                  'Tanggal terakhir kali stok item ini diperbarui atau diubah'
                                ),
                                
                                _buildInfoRow('Diedit Oleh', item['editedBy']?.toString() ?? 'N/A'),
                                

                                _buildDescriptionRow(
                                  'Dokumentasi', 
                                  item['description']?.toString() ?? 'N/A',
                                  'Link dokumentasi atau gambar komponen di Google Drive'
                                ),
                                
                                const SizedBox(height: 10),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRowWithDescription(String label, String value, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  '$label:',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 100),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionRow(String label, String value, String description) {
    bool isValidUrl = value != 'N/A' && value.isNotEmpty && 
                     (value.startsWith('http') || value.startsWith('https'));
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 100,
                child: Text(
                  '$label:',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isValidUrl) ...[

                      GestureDetector(
                        onTap: () => _launchGoogleDriveUrl(value),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF6F3D).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFFFF6F3D).withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.link,
                                size: 16,
                                color: Color(0xFFFF6F3D),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Buka Dokumentasi',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFFFF6F3D),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.open_in_new,
                                size: 14,
                                color: Color(0xFFFF6F3D),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else ...[

                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 100),
            child: Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
  void _confirmDelete(BuildContext context, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutBack,
          builder: (context, value, child) {
            return Transform.scale(
              scale: 0.8 + (0.2 * value),
              child: Opacity(
                opacity: value,
                child: AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  title: const Text('Delete Item'),
                  content: Text('Are you sure you want to delete "${item['name']}"?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await _deleteItem(item);
                      },
                      child: const Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
     void dispose() {
    searchController.dispose();
    _loadingAnimationController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
  }
  }


  Future<void> _deleteItem(Map<String, dynamic> item) async {
    try {

      await FirebaseFirestore.instance
          .collection('categories')
          .doc(item['category'])
          .collection('items')
          .doc(item['docId'])
          .delete();


      await HistoryHelper.addHistoryEntry(
        action: 'item_deleted',
        itemSku: item['sku']?.toString() ?? 'Unknown SKU',
        itemName: item['name']?.toString() ?? 'Unknown Item',
        itemMerk: item['merk']?.toString() ?? 'Unknown Brand',
        category: item['category']?.toString() ?? 'Unknown Category',
        amount: item['amount'] ?? 0,
        description: 'Item permanently deleted from inventory',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('Item deleted successfully'),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );


        loadAllItems();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.error,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Error deleting item: $e'),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }
}