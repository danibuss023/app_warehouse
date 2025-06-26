import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'history_page.dart';

class ItemOutPage extends StatefulWidget {
  const ItemOutPage({super.key});

  @override
  State<ItemOutPage> createState() => _ItemOutPageState();
}

class _ItemOutPageState extends State<ItemOutPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isRefreshing = false;
  
  late AnimationController _loadingAnimationController;
  late Animation<double> _loadingAnimation;
  late AnimationController _fadeAnimationController;
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
  }

  @override
  void dispose() {
    _searchController.dispose();
    _loadingAnimationController.dispose();
    _fadeAnimationController.dispose();
    super.dispose();
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
            _buildSearchBar(),
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
                    'Barang keluar',
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

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        onChanged: (value) {
          setState(() {
            _searchQuery = value.toLowerCase();
          });
        },
        decoration: InputDecoration(
          hintText: 'cari',
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 16),
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
    );
  }

  Widget _buildItemsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('categories').snapshots(),
      builder: (context, categoriesSnapshot) {
        if (categoriesSnapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Terjadi kesalahan saat memuat data: ${categoriesSnapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }


        if (categoriesSnapshot.connectionState == ConnectionState.waiting && _searchQuery.isEmpty) {
          return _buildAnimatedLoadingWidget();
        }

        if (!categoriesSnapshot.hasData || categoriesSnapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'Data tidak ditemukan',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          );
        }

        return FutureBuilder<List<Map<String, dynamic>>>(
          future: _getAllItemsFromCategories(categoriesSnapshot.data!.docs),
          builder: (context, itemsSnapshot) {
            if (itemsSnapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text('Terjadi kesalahan saat memuat data: ${itemsSnapshot.error}'),
                  ],
                ),
              );
            }


            if (itemsSnapshot.connectionState == ConnectionState.waiting && _searchQuery.isEmpty) {
              return _buildAnimatedLoadingWidget();
            }

            final allItems = itemsSnapshot.data ?? [];
            

            final filteredItems = allItems.where((item) {
              if (_searchQuery.isEmpty) return true;
              
              final itemName = (item['name'] ?? '').toString().toLowerCase();
              final itemSku = (item['sku'] ?? '').toString().toLowerCase();
              final itemMerk = (item['merk'] ?? '').toString().toLowerCase();
              
              return itemName.contains(_searchQuery) || 
                     itemSku.contains(_searchQuery) ||
                     itemMerk.contains(_searchQuery);
            }).toList();

            if (filteredItems.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      _searchQuery.isEmpty ? 'Data tidak ditemukan' : 'Tidak ada data yang cocok dengan pencarian Anda',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                    if (_searchQuery.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Coba kata kunci yang berbeda',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ],
                ),
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
                          child: ItemOutCard(
                            category: item['categoryName'] ?? '',
                            itemData: {
                              'sku': item['sku'] ?? '',
                              'name': item['name'] ?? 'Unknown Item',
                              'merk': item['merk'] ?? '',
                              'amount': item['amount'] ?? 0,
                            },
                            onStockRemoved: () {
                              setState(() {});
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
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
                      'src/itemout.png',
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


  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;
    
    setState(() {
      _isRefreshing = true;
    });
    
    try {

      await Future.delayed(const Duration(milliseconds: 500));
      

      if (mounted) {
        setState(() {});
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }


  Future<List<Map<String, dynamic>>> _getAllItemsFromCategories(
      List<QueryDocumentSnapshot> categoryDocs) async {
    List<Map<String, dynamic>> allItems = [];
    
    try {
      for (var categoryDoc in categoryDocs) {
        final categoryName = categoryDoc.id;
        
        final itemsSnapshot = await FirebaseFirestore.instance
            .collection('categories')
            .doc(categoryName)
            .collection('items')
            .get();

        for (var itemDoc in itemsSnapshot.docs) {
          final itemData = itemDoc.data();
          allItems.add({
            'itemId': itemDoc.id,
            'categoryName': categoryName,
            'sku': itemData['sku'] ?? 'No SKU',
            'name': itemData['name'] ?? 'Unknown Item',
            'merk': itemData['merk'] ?? '',
            'amount': itemData['amount'] ?? 0,
          });
        }
      }
    } catch (e) {
      print('Error loading items: $e');
      rethrow;
    }

    return allItems;
  }
}

class ItemOutCard extends StatelessWidget {
  final String category;
  final Map<String, dynamic> itemData;
  final VoidCallback onStockRemoved;

  const ItemOutCard({
    super.key,
    required this.category,
    required this.itemData,
    required this.onStockRemoved,
  });

  @override
  Widget build(BuildContext context) {
    final String sku = itemData['sku'] ?? '';
    final String name = itemData['name'] ?? '';
    final String merk = itemData['merk'] ?? '';
    final int currentAmount = itemData['amount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [

            SizedBox(
              width: 48,
              height: 48,
              child: Center(
                child: Image.asset(
                  'src/item.png',
                  width: 55,
                  height: 55,
                  errorBuilder: (context, error, stackTrace) {

                    return const Icon(
                      Icons.inventory_2,
                      color: Color(0xFFFF6F3D),
                      size: 24,
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
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sku,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Stok: $currentAmount',
                    style: TextStyle(
                      fontSize: 14,
                      color: currentAmount > 10 
                          ? Colors.green[600]
                          : currentAmount > 0 
                              ? Colors.orange[600]
                              : Colors.red[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            

            GestureDetector(
              onTap: currentAmount > 0 ? () => _showRemoveStockDialog(context) : null,
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Opacity(
                    opacity: currentAmount > 0 ? 1.0 : 0.3,
                    child: Image.asset(
                      'src/decrease.png',
                      width: 22,
                      height: 22,
                      errorBuilder: (context, error, stackTrace) {

                        return Icon(
                          Icons.remove,
                          color: currentAmount > 0 ? const Color(0xFFFF6F3D) : Colors.grey,
                          size: 20,
                        );
                      },
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



Future<void> _showCenterNotification(BuildContext context, int removeAmount) async {
  print('DEBUG: _showCenterNotification called with amount: $removeAmount');
  

  final completer = Completer<void>();
  
  try {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withOpacity(0.6),
      builder: (BuildContext dialogContext) {
        print('DEBUG: Dialog builder called');
        
        return WillPopScope(
          onWillPop: () async {
            print('DEBUG: Dialog will pop');
            if (!completer.isCompleted) {
              completer.complete();
            }
            return true;
          },
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            child: Center(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.85,
                ),
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6F3D),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [

                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            width: 80,
                            height: 80,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: Color(0xFFFF6F3D),
                              size: 50,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 20),
                    

                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: const Text(
                            'SUCCESS!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2.0,
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    

                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Text(
                            'Stock "${itemData['name']}" removed successfully',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 8),
                    

                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Transform.scale(
                          scale: value,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '-$removeAmount items removed',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    

                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.0, end: 1.0),
                      duration: const Duration(milliseconds: 900),
                      curve: Curves.easeOut,
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value,
                          child: Row(
                            children: [

                              Expanded(
                                child: SizedBox(
                                  height: 45,
                                  child: TextButton(
                                    onPressed: () {
                                      print('DEBUG: Undo button pressed');
                                      if (!completer.isCompleted) {
                                        completer.complete();
                                      }
                                      Navigator.of(dialogContext).pop();
                                      _undoLastTransaction(context, removeAmount);
                                    },
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.white.withOpacity(0.2),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'UNDO',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              
                              const SizedBox(width: 16),
                              

                              Expanded(
                                child: SizedBox(
                                  height: 45,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      print('DEBUG: OK button pressed');
                                      if (!completer.isCompleted) {
                                        completer.complete();
                                      }
                                      Navigator.of(dialogContext).pop();
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: const Color(0xFFFF6F3D),
                                      elevation: 2,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'OK',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.0,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    ).then((_) {
      print('DEBUG: Dialog completed normally');
      if (!completer.isCompleted) {
        completer.complete();
      }
    }).catchError((error) {
      print('DEBUG: Dialog error: $error');
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    });
    

    Timer? autoTimer;
    autoTimer = Timer(const Duration(seconds: 4), () {
      print('DEBUG: Auto dismiss timer triggered');
      if (context.mounted && !completer.isCompleted) {
        try {
          Navigator.of(context, rootNavigator: false).pop();
          print('DEBUG: Dialog auto dismissed successfully');
          completer.complete();
        } catch (e) {
          print('DEBUG: Error auto dismissing dialog: $e');
        }
      }
      autoTimer?.cancel();
    });
    

    await completer.future.timeout(
      const Duration(seconds: 6),
      onTimeout: () {
        print('DEBUG: Dialog timeout reached');
        autoTimer?.cancel();
      },
    );
    
    autoTimer.cancel();
    print('DEBUG: Notification process completed');
    
  } catch (e) {
    print('DEBUG: Error in _showCenterNotification: $e');
  }
}

 void _showRemoveStockDialog(BuildContext context) {
  final amountController = TextEditingController();
  final noteController = TextEditingController();
  String? amountError;
  bool isLoading = false;
  final int currentAmount = itemData['amount'] ?? 0;

  if (currentAmount <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${itemData['name']} is out of stock'),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
    return;
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            backgroundColor: Colors.white,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.85,
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [

                  Text(
                    'REMOVE STOCK',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFFF6F3D),
                      fontFamily: 'Lexend',
                      letterSpacing: 1.2,
                    ),
                  ),
                  

                  

                  Text(
                    itemData['name'] ?? 'Unknown Item',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                      fontFamily: 'Lexend',
                    ),
                    textAlign: TextAlign.center,
                  ),
                  

                  

                  Text(
                    'CURRENT STOCK : ${itemData['amount'] ?? 0}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.grey[600],
                      fontFamily: 'Lexend',
                      letterSpacing: 0.5,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      enabled: !isLoading,
                      style: const TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        hintText: 'amount to remove (Max: $currentAmount)',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontFamily: 'Lexend',
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                        errorText: amountError,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        prefixIcon: Container(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.remove_circle_outline,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: TextField(
                      controller: noteController,
                      enabled: !isLoading,

                      style: const TextStyle(
                        fontFamily: 'Lexend',
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                      ),
                      decoration: InputDecoration(
                        hintText: 'note (optional)',
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontFamily: 'Lexend',
                          fontSize: 16,
                          fontWeight: FontWeight.w300,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        prefixIcon: Container(
                          padding: const EdgeInsets.all(12),
                          child: Icon(
                            Icons.edit_note,
                            color: Colors.grey[600],
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  

                  if (isLoading) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFFFF6F3D),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Removing stock...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                            fontFamily: 'Lexend',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                  ],
                  

                  Row(
                    children: [

                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: TextButton(
                            onPressed: isLoading ? null : () => Navigator.pop(context),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              foregroundColor: Colors.grey[700],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              'CANCEL',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                fontFamily: 'Lexend',
                                letterSpacing: 1.0,
                                color: isLoading ? Colors.grey[400] : Colors.grey[700],
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
                            onPressed: isLoading ? null : () async {
                              final amountText = amountController.text.trim();
                              final note = noteController.text.trim();

                              if (amountText.isEmpty) {
                                setState(() => amountError = 'Amount is required');
                                return;
                              }

                              final amount = int.tryParse(amountText);
                              if (amount == null || amount <= 0) {
                                setState(() => amountError = 'Enter valid positive number');
                                return;
                              }

                              if (amount > currentAmount) {
                                setState(() => amountError = 'Amount exceeds current stock ($currentAmount)');
                                return;
                              }


                              setState(() {
                                isLoading = true;
                                amountError = null;
                              });

                              try {
                                await _removeStock(context, amount, note);
                                Navigator.pop(context);
                                onStockRemoved();
                              } catch (e) {
                                setState(() {
                                  isLoading = false;
                                  amountError = e.toString();
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isLoading ? Colors.grey[400] : const Color(0xFFFF6F3D),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: isLoading 
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Text(
                                    'SAVE',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Lexend',
                                      letterSpacing: 1.0,
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
          );
        },
      );
    },
  );
}

Future<void> _removeStock(BuildContext context, int removeAmount, String note) async {
  final itemRef = FirebaseFirestore.instance
      .collection('categories')
      .doc(category)
      .collection('items')
      .doc(itemData['sku']);

  try {
    await FirebaseFirestore.instance.runTransaction((transaction) async {
      final snapshot = await transaction.get(itemRef);
      if (!snapshot.exists) {
        throw Exception('Item not found');
      }

      final currentData = snapshot.data() as Map<String, dynamic>;
      final currentAmount = currentData['amount'] as int;
      
      if (removeAmount > currentAmount) {
        throw Exception('Amount exceeds current stock');
      }
      
      final newAmount = currentAmount - removeAmount;


      transaction.update(itemRef, {
        'amount': newAmount,
        'last_updated': FieldValue.serverTimestamp(),
      });
    });


    try {
      await HistoryHelper.addHistoryEntry(
        action: 'item_out',
        itemSku: itemData['sku'],
        itemName: itemData['name'],
        itemMerk: itemData['merk'],
        category: category,
        amount: removeAmount,
        previousAmount: itemData['amount'],
        newAmount: itemData['amount'] - removeAmount,
        description: note.isNotEmpty ? note : 'Stock removed via Item Out page',
      );
      print('DEBUG: History entry added');
    } catch (e) {
      print('Warning: Could not save history: $e');
    }


    if (context.mounted) {
      print('DEBUG: Calling _showCenterNotification');
      await _showCenterNotification(context, removeAmount);
    }
    
  } catch (e) {
    print('DEBUG: Error in _removeStock: $e');
    if (context.mounted) {
      _showErrorNotification(context, 'Failed to remove stock: $e');
    }
    rethrow;
  }
}


void _showErrorNotification(BuildContext context, String message) {
  print('DEBUG: _showErrorNotification called with message: $message');
  
  showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withOpacity(0.6),
    builder: (BuildContext dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Center(
          child: Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.85,
            ),
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.error,
                          color: Colors.red,
                          size: 50,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
                const Text(
                  'ERROR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                  ),
                ),
                
                const SizedBox(height: 12),
                

                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 24),
                

                SizedBox(
                  width: double.infinity,
                  height: 45,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.red,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.0,
                      ),
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
  Future<void> _undoLastTransaction(BuildContext context, int amount) async {
    try {
      final itemRef = FirebaseFirestore.instance
          .collection('categories')
          .doc(category)
          .collection('items')
          .doc(itemData['sku']);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(itemRef);
        if (!snapshot.exists) return;

        final currentData = snapshot.data() as Map<String, dynamic>;
        final currentAmount = currentData['amount'] as int;
        final newAmount = currentAmount + amount;

        transaction.update(itemRef, {
          'amount': newAmount,
          'last_updated': FieldValue.serverTimestamp(),
        });


        Future.delayed(Duration.zero, () async {
          try {
            await HistoryHelper.addHistoryEntry(
              action: 'item_in',
              itemSku: itemData['sku'],
              itemName: itemData['name'],
              itemMerk: itemData['merk'],
              category: category,
              amount: amount,
              previousAmount: currentAmount,
              newAmount: newAmount,
              description: 'Undo last Item Out transaction',
            );
          } catch (e) {
            print('Warning: Could not save undo history: $e');
          }
        });
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaction undone successfully'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Undo failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}