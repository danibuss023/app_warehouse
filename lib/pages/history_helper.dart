import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
class HistoryHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static Future<void> addHistoryEntry({
    required String action,
    required String itemSku,
    required String itemName,
    required String itemMerk,
    required String category,
    required int amount,
    required String description,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore.collection('history').add({
        'action': action,
        'item_sku': itemSku,
        'item_name': itemName,
        'item_merk': itemMerk,
        'category': category,
        'amount': amount,
        'description': description,
        'timestamp': FieldValue.serverTimestamp(),
        'user_email': user.email,
        'user_id': user.uid,
      });
    } catch (e) {
      print('Error adding history entry: $e');
      rethrow;
    }
  }
  static Stream<QuerySnapshot> getHistoryStream() {
    return _firestore
        .collection('history')
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
  static Stream<QuerySnapshot> getHistoryByAction(String action) {
    return _firestore
        .collection('history')
        .where('action', isEqualTo: action)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
  static Stream<QuerySnapshot> getHistoryByCategory(String category) {
    return _firestore
        .collection('history')
        .where('category', isEqualTo: category)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }
  static String getActionLabel(String action) {
    switch (action) {
      case 'item_added':
        return 'Barang baru';
      case 'item_updated':
        return 'Item Updated';
      case 'item_deleted':
        return 'Barang dihapus';
      case 'item_in':
        return 'Barang masuk';
      case 'item_out':
        return 'Barang keluar';
      case 'category_added':
        return 'Category Created';
      case 'category_deleted':
        return 'Category Deleted';
      case 'stock_adjustment':
        return 'Stock Adjustment';
      default:
        return 'Unknown Action';
    }
  }
  static String getActionIcon(String action) {
    switch (action) {
      case 'item_added':
        return '➕';
      case 'item_updated':
        return '✏️';
      case 'item_deleted':
        return '🗑️';
      case 'item_in':
        return '📥';
      case 'item_out':
        return '📤';
      case 'category_added':
        return '📁';
      case 'category_deleted':
        return '🗂️';
      case 'stock_adjustment':
        return '⚖️';
      default:
        return 'ℹ️';
    }
  }
  static String getActionColor(String action) {
    switch (action) {
      case 'item_added':
      case 'item_in':
      case 'category_added':
        return 'green';
      case 'item_deleted':
      case 'item_out':
      case 'category_deleted':
        return 'red';
      case 'item_updated':
      case 'stock_adjustment':
        return 'orange';
      default:
        return 'grey';
    }
  }
  static String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    
    final dateTime = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
  static String formatFullDate(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown date';
    
    final dateTime = timestamp.toDate();
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    
    final day = dateTime.day.toString().padLeft(2, '0');
    final month = months[dateTime.month - 1];
    final year = dateTime.year;
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    
    return '$day $month $year, $hour:$minute';
  }
}