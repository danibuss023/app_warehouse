import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String selectedFilter = 'Semua';
  final List<String> filterOptions = ['Semua', 'Barang masuk', 'Barang keluar', 'Barang baru', 'Barang dihapus'];

  List<DocumentSnapshot> _filterDocuments(List<DocumentSnapshot> docs) {
    if (selectedFilter == 'Semua') {
      return docs;
    }
    
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;
      
      String action = data['action'] ?? '';
      
      switch (selectedFilter) {
        case 'Barang masuk':
          return action == 'item_in';
        case 'Barang keluar':
          return action == 'item_out';
        case 'Barang baru':
          return action == 'item_added';
        case 'Barang dihapus':
          return action == 'item_deleted';
        default:
          return false;
      }
    }).toList();
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Unduh Laporan'),
          content: const Text('Pilih periode laporan sesuai kebutuhanmu:'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _generateReport('daily');
              },
              child: const Text('Hari'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _generateReport('weekly');
              },
              child: const Text('Minggu'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _generateReport('monthly');
              },
              child: const Text('Bulan'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _generateReport(String period) async {
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 20),
              Text('Membuat Laporan...'),
            ],
          ),
        ),
      );

      if (Platform.isAndroid) {
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            var storageStatus = await Permission.storage.status;
            if (!storageStatus.isGranted) {
              storageStatus = await Permission.storage.request();
              if (!storageStatus.isGranted) {
                Navigator.pop(context);
                _showErrorSnackBar('Storage permission required to save report');
                return;
              }
            }
          }
        }
      }

      final now = DateTime.now();
      DateTime startDate;
      
      switch (period) {
        case 'daily':
          startDate = DateTime(now.year, now.month, now.day);
          break;
        case 'weekly':
          startDate = now.subtract(Duration(days: now.weekday - 1));
          startDate = DateTime(startDate.year, startDate.month, startDate.day);
          break;
        case 'monthly':
          startDate = DateTime(now.year, now.month, 1);
          break;
        default:
          startDate = DateTime(now.year, now.month, now.day);
      }

      final endDate = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final querySnapshot = await FirebaseFirestore.instance
          .collection('history')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .orderBy('timestamp', descending: true)
          .get();

      final filteredDocs = querySnapshot.docs.where((doc) {
        final data = doc.data();
        final action = data['action'] ?? '';
        return action == 'item_in' || action == 'item_out';
      }).toList();

      final csvContent = _generateCSVContent(filteredDocs, period, startDate, endDate);

      final filePath = await _saveReportToFile(csvContent, period);
      
      Navigator.pop(context); 
      
      if (filePath != null) {
        _showSuccessDialog(filePath);
      } else {
        _showErrorSnackBar('Failed to save report');
      }

    } catch (e) {
      Navigator.pop(context); 
      _showErrorSnackBar('Error generating report: $e');
    }
  }

  String _generateCSVContent(List<DocumentSnapshot> docs, String period, DateTime startDate, DateTime endDate) {
    final buffer = StringBuffer();
    
    // Header
    buffer.writeln('REPORT - ${period.toUpperCase()}');
    buffer.writeln('Periode: ${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}');
    buffer.writeln('Dibuat: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}');
    buffer.writeln('');
    
    // CSV Headers
    buffer.writeln('Date,Time,Action,SKU,Nama Barang,Merek,Kategori,Jumlah,Stok lama,Stok baru,User,Deskripsi');
    
    // Data
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = data['timestamp'] as Timestamp?;
      final date = timestamp?.toDate() ?? DateTime.now();
      
      final row = [
        DateFormat('dd/MM/yyyy').format(date),
        DateFormat('HH:mm:ss').format(date),
        _getActionLabel(data['action'] ?? ''),
        _escapeCsvField(data['item_sku'] ?? ''),
        _escapeCsvField(data['item_name'] ?? ''),
        _escapeCsvField(data['item_merk'] ?? ''),
        _escapeCsvField(data['category'] ?? ''),
        data['amount']?.toString() ?? '0',
        data['previous_amount']?.toString() ?? '',
        data['new_amount']?.toString() ?? '',
        _escapeCsvField(data['user_email']?.split('@').first ?? ''),
        _escapeCsvField(data['description'] ?? ''),
      ];
      
      buffer.writeln(row.join(','));
    }
    
    // Summary
    buffer.writeln('');
    buffer.writeln('Ringkasan');
    
    final itemInCount = docs.where((doc) => (doc.data() as Map)['action'] == 'item_in').length;
    final itemOutCount = docs.where((doc) => (doc.data() as Map)['action'] == 'item_out').length;
    final totalItemIn = docs
        .where((doc) => (doc.data() as Map)['action'] == 'item_in')
        .fold(0, (sum, doc) => sum + ((doc.data() as Map)['amount'] as int? ?? 0));
    final totalItemOut = docs
        .where((doc) => (doc.data() as Map)['action'] == 'item_out')
        .fold(0, (sum, doc) => sum + ((doc.data() as Map)['amount'] as int? ?? 0));
    
    buffer.writeln('Jumlah transaksi barang masuk,$itemInCount');
    buffer.writeln('Jumlah transaksi barang keluar,$itemOutCount');
    buffer.writeln('Jumlah barang masuk,$totalItemIn');
    buffer.writeln('Jumlah barang keluar,$totalItemOut');
    buffer.writeln('Selisih barang masuk dan barang keluar,${totalItemIn - totalItemOut}');
    
    return buffer.toString();
  }

  String _getActionLabel(String action) {
    switch (action) {
      case 'item_in':
        return 'Barang masuk';
      case 'item_out':
        return 'Barang keluar';
      default:
        return action;
    }
  }

  String _escapeCsvField(String field) {
    if (field.contains(',') || field.contains('"') || field.contains('\n')) {
      return '"${field.replaceAll('"', '""')}"';
    }
    return field;
  }

  Future<String?> _saveReportToFile(String content, String period) async {
    try {
      final now = DateTime.now();
      final filename = 'Report_warehouse_${period}_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
      
      Directory? directory;
      if (Platform.isAndroid) {
        try {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            directory = downloadsDir;
          }
        } catch (e) {
          print('Gagal mengakses folder Downloads: $e');
        }
        
        if (directory == null) {
          directory = await getExternalStorageDirectory();
          if (directory != null) {
            final documentsDir = Directory('${directory.path}/Documents');
            if (!await documentsDir.exists()) {
              await documentsDir.create(recursive: true);
            }
            directory = documentsDir;
          }
        }
      } else {
        // iOS
        directory = await getApplicationDocumentsDirectory();
      }
      
      if (directory == null) {
        throw Exception('Could not access storage directory');
      }
      
      final file = File('${directory.path}/$filename');
      await file.writeAsString(content);
      
      print('File saved to: ${file.path}');
      return file.path;
      
    } catch (e) {
      print('Error saving file: $e');
      return null;
    }
  }

  void _showSuccessDialog(String filePath) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 12),
              Text('Report Generated'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Report has been saved successfully!'),
              SizedBox(height: 12),
              Text(
                'File location:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  filePath,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              SizedBox(height: 12),
              Text(
                'You can find the file in your device\'s file manager.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Copy Path'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFFF6F3D),
                foregroundColor: Colors.white,
              ),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
 Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: const Color(0xFFF1F1F1),
    body: Column(
      children: [
        _buildHeader(), // ✅ custom header ganti AppBar
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[100],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              SizedBox(
                width: 120,
                child: DropdownButtonFormField<String>(
                  value: selectedFilter,
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade400),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFFF6F3D)),
                    ),
                  ),
                  items: filterOptions.map((option) {
                    return DropdownMenuItem<String>(
                      value: option,
                      child: Text(option),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        selectedFilter = value;
                      });
                    }
                  },
                ),
              ),
            ],
          ),
        ),

        // 🔥 History List
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('history')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6F3D)),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                      const SizedBox(height: 16),
                      Text(
                        'Error: ${snapshot.error}',
                        style: TextStyle(color: Colors.red[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                );
              }

              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No history data found',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                );
              }

              List<DocumentSnapshot> filteredDocs =
                  _filterDocuments(snapshot.data!.docs);

              if (filteredDocs.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.filter_list_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No data found for "$selectedFilter" filter',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            selectedFilter = 'Semua';
                          });
                        },
                        child: const Text('Clear Filter'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                itemBuilder: (context, index) {
                  final doc = filteredDocs[index];
                  final data = doc.data() as Map<String, dynamic>;

                  return HistoryCard(
                    action: data['action'] ?? '',
                    itemSku: data['item_sku'] ?? '',
                    itemName: data['item_name'] ?? '',
                    itemMerk: data['item_merk'] ?? '',
                    category: data['category'] ?? '',
                    amount: data['amount'] ?? 0,
                    previousAmount: data['previous_amount'],
                    newAmount: data['new_amount'],
                    timestamp: data['timestamp'],
                    userEmail: data['user_email'] ?? '',
                    description: data['description'] ?? '',
                  );
                },
              );
            },
          ),
        ),
      ],
    ),
  );
}
  Widget _buildHeader() {
  return Container(
    height: 100,
    decoration: const BoxDecoration(
      color: Color(0xFFFF6F3D),
      borderRadius: BorderRadius.only(
        // bottomLeft: Radius.circular(20),
        // bottomRight: Radius.circular(20),
      ),
    ),
    child: SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // 🔙 Tombol Back dengan background hitam transparan
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2), // transparan
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.arrow_back, color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      "Kembali",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const Expanded(
              child: Center(
                child: Text(
                  "History",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            SizedBox(width: 40), // Space to balance the back button
            // 📥 Tombol Download kanan
            GestureDetector(
              onTap: _showReportDialog,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.download, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
 }

class HistoryCard extends StatelessWidget {
  final String action;
  final String itemSku;
  final String itemName;
  final String itemMerk;
  final String category;
  final int amount;
  final int? previousAmount;
  final int? newAmount;
  final Timestamp? timestamp;
  final String userEmail;
  final String description;

  const HistoryCard({
    super.key,
    required this.action,
    required this.itemSku,
    required this.itemName,
    required this.itemMerk,
    required this.category,
    required this.amount,
    this.previousAmount,
    this.newAmount,
    this.timestamp,
    required this.userEmail,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: _getBackgroundColor(),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Image.asset(
                  _getActionImage(),
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to icon if image not found
                    return Icon(
                      _getActionIconData(),
                      color: _getIconColor(),
                      size: 36,
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getActionTitle(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Text(
                                  _formatTimestamp(),
                                  style: const TextStyle(
                                    color: Colors.black87,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                               Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    color: Color.fromARGB(255, 109, 109, 109).withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.access_time,
                                    size: 12,
                                    color: Color.fromARGB(255, 109, 109, 109),
                                  ),
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            Icons.person,
                            size: 16,
                            color: const Color.fromARGB(255, 90, 90, 90),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'By : ${userEmail.split('@').first}',
                            style: const TextStyle(
                              color: Color.fromARGB(255, 90, 90, 90),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('SKU', itemSku),
                      _buildInfoRow('Nama', itemName),
                      // _buildInfoRow('Kategori', category),
                      _buildAmountRow(),
                      if (description.isNotEmpty)
                        _buildInfoRow('Deskripsi', description.isEmpty ? '---' : description),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '---' : value,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountRow() {
    String amountText;
    if (action == 'item_in' || action == 'item_out') {
      if (previousAmount != null && newAmount != null) {
        amountText = '$previousAmount → $newAmount (${action == 'item_in' ? '+' : '-'}$amount)';
      } else {
        amountText = amount.toString();
      }
    } else {
      amountText = amount.toString();
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 70,
            child: Text(
              'Jumlah',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Text(
            ': ',
            style: TextStyle(
              fontSize: 13,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              amountText,
              style: TextStyle(
                fontSize: 13,
                color: (action == 'item_in' || action == 'item_out') ? 
                       (action == 'item_in' ? Colors.green[700] : Colors.red[700]) : 
                       Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getActionImage() {
    switch (action) {
      case 'item_in':
        return 'src/in.png';
      case 'item_out':
        return 'src/out.png'; 
      case 'item_added':
        return 'src/addd.png'; 
      case 'item_deleted':
        return 'assets/images/item_deleted.png'; 
      default:
        return 'assets/images/default_action.png';
    }
  }

  Color _getBackgroundColor() {
    switch (action) {
      case 'item_in':
        return Colors.green.withOpacity(0.2); // Green transparent for item in
      case 'item_out':
        return Colors.red.withOpacity(0.2);
      case 'item_added':
        return Colors.blue.withOpacity(0.2); 
      case 'item_deleted':
        return Colors.orange.withOpacity(0.2); 
      default:
        return Colors.grey.withOpacity(0.2); 
    }
  }

  Color _getIconColor() {
    switch (action) {
      case 'item_in':
        return Colors.green[700]!;
      case 'item_out':
        return Colors.red[700]!;
      case 'item_added':
        return Colors.blue[700]!;
      case 'item_deleted':
        return Colors.orange[700]!;
      default:
        return Colors.grey[700]!;
    }
  }

  IconData _getActionIconData() {
    switch (action) {
      case 'item_in':
        return Icons.arrow_downward_rounded;
      case 'item_out':
        return Icons.arrow_upward_rounded;
      case 'item_added':
        return Icons.add_rounded;
      case 'item_deleted':
        return Icons.delete_rounded;
      default:
        return Icons.inventory_rounded;
    }
  }

  String _getActionTitle() {
    switch (action) {
      case 'item_in':
        return 'Barang masuk';
      case 'item_out':
        return 'Barang keluar';
      case 'item_added':
        return 'Barang baru';
      case 'item_deleted':
        return 'Barang dihapus';
      default:
        return 'Aksi tidak dikenal';
    }
  }

  String _formatTimestamp() {
    if (timestamp == null) return 'Waktu tidak diketahui';
    final date = timestamp!.toDate();
    return DateFormat('dd MMM yyyy HH:mm').format(date);
  }
}
class HistoryHelper {
  static Future<void> addHistoryEntry({
    required String action,
    required String itemSku,
    required String itemName,
    required String itemMerk,
    required String category,
    required int amount,
    int? previousAmount,
    int? newAmount,
    String description = '',
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    await FirebaseFirestore.instance.collection('history').add({
      'action': action,
      'item_sku': itemSku,
      'item_name': itemName,
      'item_merk': itemMerk,
      'category': category,
      'amount': amount,
      'previous_amount': previousAmount,
      'new_amount': newAmount,
      'timestamp': FieldValue.serverTimestamp(),
      'user_email': user.email,
      'description': description,
    });
  }
}