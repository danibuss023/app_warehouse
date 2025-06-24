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
  String selectedFilter = 'All';
  final List<String> filterOptions = ['All', 'Item In', 'Item Out', 'Item Added', 'Item Deleted'];

  List<DocumentSnapshot> _filterDocuments(List<DocumentSnapshot> docs) {
    if (selectedFilter == 'All') {
      return docs;
    }
    
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;
      
      String action = data['action'] ?? '';
      
      switch (selectedFilter) {
        case 'Item In':
          return action == 'item_in';
        case 'Item Out':
          return action == 'item_out';
        case 'Item Added':
          return action == 'item_added';
        case 'Item Deleted':
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
          title: const Text('Generate Report'),
          content: const Text('Select the time period for the item in/out report:'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _generateReport('daily');
              },
              child: const Text('Daily'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _generateReport('weekly');
              },
              child: const Text('Weekly'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _generateReport('monthly');
              },
              child: const Text('Monthly'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
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
              Text('Generating report...'),
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
    buffer.writeln('INVENTORY REPORT - ${period.toUpperCase()}');
    buffer.writeln('Period: ${DateFormat('dd MMM yyyy').format(startDate)} - ${DateFormat('dd MMM yyyy').format(endDate)}');
    buffer.writeln('Generated: ${DateFormat('dd MMM yyyy HH:mm').format(DateTime.now())}');
    buffer.writeln('');
    
    // CSV Headers
    buffer.writeln('Date,Time,Action,SKU,Item Name,Brand,Category,Amount,Previous Stock,New Stock,User,Description');
    
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
    buffer.writeln('SUMMARY');
    
    final itemInCount = docs.where((doc) => (doc.data() as Map)['action'] == 'item_in').length;
    final itemOutCount = docs.where((doc) => (doc.data() as Map)['action'] == 'item_out').length;
    final totalItemIn = docs
        .where((doc) => (doc.data() as Map)['action'] == 'item_in')
        .fold(0, (sum, doc) => sum + ((doc.data() as Map)['amount'] as int? ?? 0));
    final totalItemOut = docs
        .where((doc) => (doc.data() as Map)['action'] == 'item_out')
        .fold(0, (sum, doc) => sum + ((doc.data() as Map)['amount'] as int? ?? 0));
    
    buffer.writeln('Total Item In Transactions,$itemInCount');
    buffer.writeln('Total Item Out Transactions,$itemOutCount');
    buffer.writeln('Total Items In,$totalItemIn');
    buffer.writeln('Total Items Out,$totalItemOut');
    buffer.writeln('Net Movement,${totalItemIn - totalItemOut}');
    
    return buffer.toString();
  }

  String _getActionLabel(String action) {
    switch (action) {
      case 'item_in':
        return 'Item In';
      case 'item_out':
        return 'Item Out';
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
      final filename = 'inventory_report_${period}_${DateFormat('yyyyMMdd_HHmmss').format(now)}.csv';
      
      Directory? directory;
      if (Platform.isAndroid) {
        try {
          final downloadsDir = Directory('/storage/emulated/0/Download');
          if (await downloadsDir.exists()) {
            directory = downloadsDir;
          }
        } catch (e) {
          print('Failed to access Downloads folder: $e');
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
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6F3D),
        title: const Text('History', style: TextStyle(color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            onPressed: _showReportDialog,
            tooltip: 'Generate Report',
          ),
        ],
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text(
                      'Filter: ', 
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButton<String>(
                          value: selectedFilter,
                          isExpanded: true,
                          underline: const SizedBox(),
                          items: filterOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(
                                value,
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              setState(() {
                                selectedFilter = newValue;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _showReportDialog,
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('Generate Report', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF6F3D),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

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

                List<DocumentSnapshot> filteredDocs = _filterDocuments(snapshot.data!.docs);

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
                              selectedFilter = 'All';
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
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _getActionIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getActionTitle(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatTimestamp(),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                _getActionChip(),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('SKU', itemSku),
                  _buildInfoRow('Item', itemName),
                  _buildInfoRow('Merk', itemMerk),
                  _buildInfoRow('Category', category),
                  if (action == 'item_in' || action == 'item_out')
                    _buildAmountInfo()
                  else
                    _buildInfoRow('Amount', amount.toString()),
                  if (description.isNotEmpty)
                    _buildInfoRow('Description', description),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'By: ${userEmail.split('@').first}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _getActionIcon() {
    switch (action) {
      case 'item_in':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.green[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.arrow_downward, color: Colors.green[700], size: 20),
        );
      case 'item_out':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.arrow_upward, color: Colors.red[700], size: 20),
        );
      case 'item_added':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.add, color: Colors.blue[700], size: 20),
        );
      case 'item_deleted':
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.orange[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.delete, color: Colors.orange[700], size: 20),
        );
      default:
        return Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.info, color: Colors.grey[700], size: 20),
        );
    }
  }

  Widget _getActionChip() {
    Color chipColor;
    switch (action) {
      case 'item_in':
        chipColor = Colors.green;
        break;
      case 'item_out':
        chipColor = Colors.red;
        break;
      case 'item_added':
        chipColor = Colors.blue;
        break;
      case 'item_deleted':
        chipColor = Colors.orange;
        break;
      default:
        chipColor = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withOpacity(0.3)),
      ),
      child: Text(
        _getActionTitle(),
        style: TextStyle(
          color: chipColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getActionTitle() {
    switch (action) {
      case 'item_in':
        return 'Item In';
      case 'item_out':
        return 'Item Out';
      case 'item_added':
        return 'Item Added';
      case 'item_deleted':
        return 'Item Deleted';
      default:
        return 'Unknown Action';
    }
  }

  String _formatTimestamp() {
    if (timestamp == null) return 'Unknown time';
    final date = timestamp!.toDate();
    return DateFormat('dd MMM yyyy, HH:mm').format(date);
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInfo() {
    if (action == 'item_in' || action == 'item_out') {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 80,
              child: Text(
                'Amount:',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Expanded(
              child: Text(
                '${previousAmount ?? 0} → ${newAmount ?? 0} (${action == 'item_in' ? '+' : '-'}$amount)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: action == 'item_in' ? Colors.green[700] : Colors.red[700],
                ),
              ),
            ),
          ],
        ),
      );
    }
    return _buildInfoRow('Amount', amount.toString());
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