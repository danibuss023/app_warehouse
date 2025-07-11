import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isPasswordVisible = false;
  bool isLoading = false;
  String error = '';

  Future<void> login() async {
    setState(() {
      isLoading = true;
      error = '';
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLoggedIn', true);
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
    } catch (e) {
      setState(() {
        error = 'Login gagal. Periksa email dan password.';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> forgotPassword() async {
    if (emailController.text.trim().isEmpty) {
      setState(() {
        error = 'Masukkan email terlebih dahulu';
      });
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: emailController.text.trim(),
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Email reset password telah dikirim ke ${emailController.text.trim()}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      setState(() {
        error = 'Gagal mengirim email reset. Periksa alamat email Anda.';
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxFormWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Image.asset('src/logo.png', height: 100)),
                  const SizedBox(height: 30),
                  const Text("Masuk", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),

                  const Text("Pastikan username dan password anda benar!"),
                  const SizedBox(height: 25),

                  TextFormField(
                    controller: emailController,
                    enabled: !isLoading,
                    decoration: InputDecoration(
                      labelText: 'email',
                      labelStyle: const TextStyle(color: Color.fromARGB(255, 110, 110, 110)),
                      prefixIcon: const Icon(Icons.email, color: Color.fromARGB(255, 110, 110, 110)),
                      focusedBorder: outlineBorder,
                      enabledBorder: outlineBorder,
                      border: outlineBorder,
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: passwordController,
                    enabled: !isLoading,
                    obscureText: !isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'password',
                      labelStyle: const TextStyle(color: Color.fromARGB(255, 110, 110, 110)),
                      prefixIcon: const Icon(Icons.lock, color: Color.fromARGB(255, 110, 110, 110)),
                      suffixIcon: IconButton(
                        icon: Icon(
                          isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          color: Color.fromARGB(255, 110, 110, 110),
                        ),
                        onPressed: isLoading ? null : () {
                          setState(() {
                            isPasswordVisible = !isPasswordVisible;
                          });
                        },
                      ),
                      focusedBorder: outlineBorder,
                      enabledBorder: outlineBorder,
                      border: outlineBorder,
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Forgot Password Link
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isLoading ? null : forgotPassword,
                      child: const Text(
                        'Lupa Password?',
                        style: TextStyle(
                          color: Color(0xFFFF6F3D),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : login,
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
                                'Masuk...',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ],
                          )
                        : const Text(
                            'Masuk',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                    ),
                  ),

                  const SizedBox(height: 15),
                  if (error.isNotEmpty)
                    Center(
                      child: AnimatedOpacity(
                        opacity: error.isNotEmpty ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        child: Text(
                          error,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ),
                  
                  const SizedBox(height: 30),
                  const Center(child: Text("©2024"))
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}