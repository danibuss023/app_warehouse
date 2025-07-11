import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController currentPasswordController = TextEditingController();
  final TextEditingController newPasswordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  
  bool isCurrentPasswordVisible = false;
  bool isNewPasswordVisible = false;
  bool isConfirmPasswordVisible = false;
  bool isLoading = false;
  String error = '';
  String success = '';

  Future<void> changePassword() async {
    setState(() {
      isLoading = true;
      error = '';
      success = '';
    });

    // Validasi input
    if (currentPasswordController.text.trim().isEmpty ||
        newPasswordController.text.trim().isEmpty ||
        confirmPasswordController.text.trim().isEmpty) {
      setState(() {
        error = 'Semua field harus diisi';
      });
      setState(() {
        isLoading = false;
      });
      return;
    }

    if (newPasswordController.text.trim() != confirmPasswordController.text.trim()) {
      setState(() {
        error = 'Password baru dan konfirmasi password tidak cocok';
      });
      setState(() {
        isLoading = false;
      });
      return;
    }

    if (newPasswordController.text.trim().length < 6) {
      setState(() {
        error = 'Password baru harus minimal 6 karakter';
      });
      setState(() {
        isLoading = false;
      });
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Re-authenticate user dengan password lama
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPasswordController.text.trim(),
        );

        await user.reauthenticateWithCredential(credential);
        
        // Update password
        await user.updatePassword(newPasswordController.text.trim());
        
        setState(() {
          success = 'Password berhasil diubah';
        });

        // Clear form
        currentPasswordController.clear();
        newPasswordController.clear();
        confirmPasswordController.clear();

        // Kembali ke halaman sebelumnya setelah 2 detik
        Future.delayed(const Duration(seconds: 2), () {
          Navigator.pop(context);
        });
      }
    } catch (e) {
      setState(() {
        if (e.toString().contains('wrong-password')) {
          error = 'Password lama tidak benar';
        } else if (e.toString().contains('weak-password')) {
          error = 'Password terlalu lemah';
        } else {
          error = 'Gagal mengubah password. Silakan coba lagi.';
        }
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final double maxFormWidth = 300;

    final outlineBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(
        color: Color(0xFFFF6F3D),
        width: 2.0,
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFF6F3D),
        title: const Text(
          'Ganti Password',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxFormWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Ganti Password",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Masukkan password lama dan password baru",
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 30),

                  // Current Password Field
                  TextFormField(
                    controller: currentPasswordController,
                    enabled: !isLoading,
                    obscureText: !isCurrentPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password Lama',
                      labelStyle: const TextStyle(color: Color.fromARGB(255, 110, 110, 110)),
                      prefixIcon: const Icon(Icons.lock, color: Color.fromARGB(255, 110, 110, 110)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isCurrentPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Color.fromARGB(255, 110, 110, 110),
                        ),
                        onPressed: isLoading ? null : () {
                          setState(() {
                            isCurrentPasswordVisible = !isCurrentPasswordVisible;
                          });
                        },
                      ),
                      focusedBorder: outlineBorder,
                      enabledBorder: outlineBorder,
                      border: outlineBorder,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // New Password Field
                  TextFormField(
                    controller: newPasswordController,
                    enabled: !isLoading,
                    obscureText: !isNewPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password Baru',
                      labelStyle: const TextStyle(color: Color.fromARGB(255, 110, 110, 110)),
                      prefixIcon: const Icon(Icons.lock_outline, color: Color.fromARGB(255, 110, 110, 110)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isNewPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Color.fromARGB(255, 110, 110, 110),
                        ),
                        onPressed: isLoading ? null : () {
                          setState(() {
                            isNewPasswordVisible = !isNewPasswordVisible;
                          });
                        },
                      ),
                      focusedBorder: outlineBorder,
                      enabledBorder: outlineBorder,
                      border: outlineBorder,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Confirm Password Field
                  TextFormField(
                    controller: confirmPasswordController,
                    enabled: !isLoading,
                    obscureText: !isConfirmPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi Password Baru',
                      labelStyle: const TextStyle(color: Color.fromARGB(255, 110, 110, 110)),
                      prefixIcon: const Icon(Icons.lock_reset, color: Color.fromARGB(255, 110, 110, 110)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Color.fromARGB(255, 110, 110, 110),
                        ),
                        onPressed: isLoading ? null : () {
                          setState(() {
                            isConfirmPasswordVisible = !isConfirmPasswordVisible;
                          });
                        },
                      ),
                      focusedBorder: outlineBorder,
                      enabledBorder: outlineBorder,
                      border: outlineBorder,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Change Password Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : changePassword,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLoading 
                          ? const Color(0xFFFF6F3D).withOpacity(0.6)
                          : const Color(0xFFFF6F3D),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              ),
                              SizedBox(width: 10),
                              Text(
                                'Mengubah...',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ],
                          )
                        : const Text(
                            'Ganti Password',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // Error Message
                  if (error.isNotEmpty)
                    Center(
                      child: AnimatedOpacity(
                        opacity: error.isNotEmpty ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          error,
                          style: const TextStyle(color: Colors.red),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),

                  // Success Message
                  if (success.isNotEmpty)
                    Center(
                      child: AnimatedOpacity(
                        opacity: success.isNotEmpty ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          success,
                          style: const TextStyle(color: Colors.green),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}