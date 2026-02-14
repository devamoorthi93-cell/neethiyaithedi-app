import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/user_model.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:typed_data';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF1A1A2E), // Deep Dark Blue
              const Color(0xFF16213E),
              AppTheme.primaryColor,
            ],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: Stack(
          children: [
            // Decorative background elements
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withValues(alpha: 0.2),
                      blurRadius: 50,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ).animate().scale(duration: 2.seconds, curve: Curves.easeInOut).fadeIn(),
            ),
            
            SafeArea(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Animated Logo
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.5),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.shield_outlined, 
                        size: 64, 
                        color: Colors.white
                      ),
                    ).animate()
                      .scale(duration: 800.ms, curve: Curves.easeOutBack)
                      .shimmer(delay: 1000.ms, duration: 1500.ms, color: Colors.white.withOpacity(0.5)),
                    
                    const SizedBox(height: 32),
                    
                    // Brand Title - Tamil
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'நீதியைத்தேடி',
                        style: GoogleFonts.notoSansTamil(
                          textStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 42,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3, end: 0),
                    ),
                    
                    const SizedBox(height: 12),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'சட்ட விழிப்புணர்வு சங்கம்',
                        style: GoogleFonts.notoSansTamil(
                          textStyle: TextStyle(
                            color: Colors.blue[100],
                            fontSize: 18,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ).animate().fadeIn(delay: 600.ms),
                    ),
                    
                    const SizedBox(height: 60),
                    
                    // Login Button (Triggers Popup)
                    Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withOpacity(0.6),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => _showLoginDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppTheme.primaryColor,
                          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 20),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                          elevation: 0,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'LOGIN TO PORTAL',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                            SizedBox(width: 12),
                            Icon(Icons.login_rounded),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 800.ms).scale(begin: const Offset(0.9, 0.9)),
                    
                    const SizedBox(height: 32),
                    Text(
                      'Secure Access Area',
                      style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                    ).animate().fadeIn(delay: 1000.ms),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showLoginDialog(BuildContext context) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) => Center(
        child: SingleChildScrollView(
          child: LoginPopupCard(),
        ),
      ),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: child,
        );
      },
    );
  }
}

class LoginPopupCard extends ConsumerStatefulWidget {
  const LoginPopupCard({super.key});

  @override
  ConsumerState<LoginPopupCard> createState() => _LoginPopupCardState();
}

class _LoginPopupCardState extends ConsumerState<LoginPopupCard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _memberEmailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  
  // 0 = Member, 1 = Admin
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {
          _currentTabIndex = _tabController.index;
        });
      }
    });
    _loadSavedCredentials();
  }

  Future<void> _loadSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? false;
      if (_rememberMe) {
        _memberEmailController.text = prefs.getString('saved_member_email') ?? '';
        _emailController.text = prefs.getString('saved_admin_email') ?? '';
        _passwordController.text = prefs.getString('saved_password') ?? '';
        _currentTabIndex = prefs.getInt('saved_tab_index') ?? 0;
        _tabController.animateTo(_currentTabIndex);
      }
    });
  }

  Future<void> _saveCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me', _rememberMe);
    if (_rememberMe) {
      await prefs.setString('saved_member_email', _memberEmailController.text);
      await prefs.setString('saved_admin_email', _emailController.text);
      await prefs.setString('saved_password', _passwordController.text);
      await prefs.setInt('saved_tab_index', _currentTabIndex);
    } else {
      await _clearSavedCredentials();
    }
  }

  Future<void> _clearSavedCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('saved_member_email');
    await prefs.remove('saved_admin_email');
    await prefs.remove('saved_password');
    await prefs.remove('saved_tab_index');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _memberEmailController.dispose();
    _passwordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final isMember = _currentTabIndex == 0;
    final identifier = isMember ? _memberEmailController.text.trim() : _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Please enter Email and Password')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final service = ref.read(firebaseServiceProvider);
      UserModel? user;

      if (isMember) {
         // Member Login
         try {
           user = await service.loginMember(identifier, password);
         } catch (e) {
           throw Exception('Member Login Failed: Invalid Email or Password');
         }
      } else {
        // Admin Login
        try {
          user = await service.loginAdmin(identifier, password);
        } catch (e) {
          throw Exception('Admin Login Failed: Check credentials');
        }
      }

      if (user != null) {
        if (!mounted) return;
        
        // Save or clear credentials based on Remember Me
        await _saveCredentials();
        
        Navigator.pop(context); // Close dialog
        ref.read(loggedInUserProvider.notifier).state = user;
        // Trigger navigation for browser history
        Navigator.of(context).pushNamed('/dashboard');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceAll('Exception:', '').trim()),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
          width: 400,
          margin: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.3),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with Close Button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Welcome Back',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      color: Colors.grey,
                      splashRadius: 20,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Tabs
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) {
                    setState(() {
                      _currentTabIndex = index;
                      _passwordController.clear(); // Clear password when switching
                    });
                  },
                  indicator: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey.shade600,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                  tabs: const [
                    Tab(text: 'Member Login'),
                    Tab(text: 'Admin Login'),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Form Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Builder(
                    builder: (context) {
                      final isMember = _currentTabIndex == 0;
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           TextField(
                            controller: isMember ? _memberEmailController : _emailController,
                            decoration: InputDecoration(
                              labelText: isMember ? 'Member Email' : 'Admin Email',
                              prefixIcon: Icon(
                                Icons.email_outlined, 
                                color: AppTheme.primaryColor
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          TextField(
                            controller: _passwordController,
                            obscureText: !_isPasswordVisible,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                                onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          Row(
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: Checkbox(
                                  value: _rememberMe,
                                  onChanged: (value) => setState(() => _rememberMe = value ?? false),
                                  activeColor: AppTheme.primaryColor,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () => setState(() => _rememberMe = !_rememberMe),
                                child: Text(
                                  'Remember Me',
                                  style: TextStyle(color: Colors.grey[700], fontSize: 14),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    }
                  ),
                ),

              
              const SizedBox(height: 32),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          _currentTabIndex == 0 ? 'LOGIN AS MEMBER' : 'LOGIN AS ADMIN',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                        ),
                ),
              ),

              if (_currentTabIndex == 0)
                Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context); // Close login dialog
                      showGeneralDialog(
                        context: context,
                        barrierDismissible: true,
                        barrierLabel: 'Dismiss',
                        barrierColor: Colors.black.withOpacity(0.8),
                        transitionDuration: const Duration(milliseconds: 400),
                        pageBuilder: (context, anim1, anim2) => Center(
        child: SingleChildScrollView(
          child: _RequestMembershipDialog(),
        ),
      ),
                        transitionBuilder: (context, anim1, anim2, child) {
                          return ScaleTransition(
                            scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
                            child: child,
                          );
                        },
                      );
                    },
                    child: Text.rich(
                      TextSpan(
                        text: "Not a member? ",
                        style: TextStyle(color: Colors.grey[600]),
                        children: [
                          TextSpan(
                            text: 'Register as a member',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

    );
  }
}

class _RequestMembershipDialog extends ConsumerStatefulWidget {
  const _RequestMembershipDialog();

  @override
  ConsumerState<_RequestMembershipDialog> createState() => _RequestMembershipDialogState();
}

class _RequestMembershipDialogState extends ConsumerState<_RequestMembershipDialog> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  // Detailed Address Controllers
  final _fatherController = TextEditingController();
  final _doorNoController = TextEditingController();
  final _streetController = TextEditingController();
  final _villageController = TextEditingController();
  final _postOfficeController = TextEditingController();
  final _talukController = TextEditingController();
  final _districtController = TextEditingController();
  final _pincodeController = TextEditingController();
  
  final _aadhaarController = TextEditingController();
  String? _selectedGender;
  String? _selectedBloodGroup;
  
  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _fatherController.dispose();
    _doorNoController.dispose();
    _streetController.dispose();
    _villageController.dispose();
    _postOfficeController.dispose();
    _talukController.dispose();
    _districtController.dispose();
    _pincodeController.dispose();
    _aadhaarController.dispose();
    super.dispose();
  }



  Future<void> _submitRequest() async {
    if (_nameController.text.isEmpty || 
        _emailController.text.isEmpty || 
        _phoneController.text.isEmpty || 
        _doorNoController.text.isEmpty ||
        _streetController.text.isEmpty ||
        _villageController.text.isEmpty ||
        _talukController.text.isEmpty ||
        _districtController.text.isEmpty ||
        _pincodeController.text.isEmpty ||
        _aadhaarController.text.isEmpty ||
        _selectedGender == null ||
        _selectedBloodGroup == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields (including Aadhaar #)')),
      );
      return;
    }

    if (_phoneController.text.trim().length != 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Phone Number must be exactly 10 digits')),
      );
      return;
    }

    if (_aadhaarController.text.trim().length != 12) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aadhaar Number must be exactly 12 digits')),
      );
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final service = ref.read(firebaseServiceProvider);
      
      // Construct Standardized Address Format
      // Format: FATHER:Val|DOOR:Val|STREET:Val|VILLAGE:Val|POST:Val|TALUK:Val|DISTRICT:Val|PINCODE:Val
      final addressString = 'FATHER:${_fatherController.text.trim()}|'
          'DOOR:${_doorNoController.text.trim()}|'
          'STREET:${_streetController.text.trim()}|'
          'VILLAGE:${_villageController.text.trim()}|'
          'POST:${_postOfficeController.text.trim()}|'
          'TALUK:${_talukController.text.trim()}|'
          'DISTRICT:${_districtController.text.trim()}|'
          'PINCODE:${_pincodeController.text.trim()}';

      // Upload images logic removed as requested
      final frontUrl = null;
      final backUrl = null;

      await service.submitMembershipRequest({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': addressString,
        'aadhaarNo': _aadhaarController.text.trim(),
        'aadhaarFrontUrl': frontUrl,
        'aadhaarBackUrl': backUrl,
        'gender': _selectedGender,
        'bloodGroup': _selectedBloodGroup,
        'submittedAt': DateTime.now().toIso8601String(),
      });

      if (!mounted) return;
      setState(() => _isLoading = false);
      
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Request Sent! We will contact you shortly.'),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: 400,
        margin: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.3),
              blurRadius: 40,
              offset: const Offset(0, 20),
            ),
          ],
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Membership Request',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                  color: Colors.grey,
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Fill in your details to request a new membership.',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 24),
            
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                prefixIcon: Icon(Icons.person_outline, color: AppTheme.primaryColor),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                labelText: 'Email Address',
                prefixIcon: Icon(Icons.email_outlined, color: AppTheme.primaryColor),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              decoration: InputDecoration(
                labelText: 'Phone Number',
                prefixIcon: Icon(Icons.phone_outlined, color: AppTheme.primaryColor),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
             
              Text(
              'Address Details (Standardized)',
              style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _fatherController,
              decoration: InputDecoration(
                labelText: 'Father/Husband Name',
                prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _doorNoController,
                    decoration: InputDecoration(
                      labelText: 'Door No',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _streetController,
                    decoration: InputDecoration(
                      labelText: 'Street Name',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _villageController,
              decoration: InputDecoration(
                labelText: 'Village / Area',
                prefixIcon: Icon(Icons.home_work_outlined, color: AppTheme.primaryColor),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _postOfficeController,
              decoration: InputDecoration(
                labelText: 'Post Office',
                prefixIcon: Icon(Icons.local_post_office_outlined, color: AppTheme.primaryColor),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _talukController,
                    decoration: InputDecoration(
                      labelText: 'Taluk',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _districtController,
                    decoration: InputDecoration(
                      labelText: 'District',
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            TextField(
              controller: _pincodeController,
              keyboardType: TextInputType.number,
              inputFormatters: [LengthLimitingTextInputFormatter(6), FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Pincode',
                prefixIcon: Icon(Icons.pin_drop_outlined, color: AppTheme.primaryColor),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _aadhaarController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(12),
              ],
              decoration: InputDecoration(
                labelText: 'Aadhaar Number',
                prefixIcon: Icon(Icons.credit_card_outlined, color: AppTheme.primaryColor),
                filled: true,
                fillColor: Colors.grey.shade50,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                    onChanged: (v) => setState(() => _selectedGender = v),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedBloodGroup,
                    decoration: InputDecoration(
                      labelText: 'Blood Group',
                      prefixIcon: Icon(Icons.bloodtype, color: AppTheme.primaryColor),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: _bloodGroups.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (v) => setState(() => _selectedBloodGroup = v),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            const SizedBox(height: 12),
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text(
                      'SUBMIT REQUEST',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
            ),
          ],
        ),
        ),
      ),
    );
  }
}
