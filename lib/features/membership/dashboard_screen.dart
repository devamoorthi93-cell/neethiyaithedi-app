import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../core/payment_config.dart';
import 'package:uuid/uuid.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/user_model.dart';
import '../../models/payment_model.dart';
import '../../models/fee_model.dart';
import '../../services/fee_service.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../features/legal/petition_screen.dart';
import '../../features/legal/petition_type_selection_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/donation_model.dart';
import '../../services/firebase_service.dart';

class MemberDashboard extends ConsumerStatefulWidget {
  const MemberDashboard({super.key});

  @override
  ConsumerState<MemberDashboard> createState() => _MemberDashboardState();
}

class _MemberDashboardState extends ConsumerState<MemberDashboard> {
  late Razorpay _razorpay;
  final FeeService _feeService = FeeService();
  bool _isProcessingPayment = false;
  UserModel? _currentUser;
  bool _isDonation = false;
  double _donationAmount = 0;


  static const String _razorpayKey = PaymentConfig.razorpayKey;

  @override
  void initState() {
    super.initState();
    _initRazorpay();
  }

  void _initRazorpay() {
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    setState(() => _isProcessingPayment = true);

    try {
      final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
      final paymentId = response.paymentId ?? const Uuid().v4();

      if (_isDonation) {
        final donation = DonationRecord(
          id: '', // Firestore will assign
          userId: _currentUser!.uid,
          userName: _currentUser!.name,
          amount: _donationAmount,
          timestamp: DateTime.now(),
          paymentId: paymentId,
          status: 'success',
        );
        await ref.read(firebaseServiceProvider).recordDonation(donation);
      } else {
        final payment = PaymentModel(
          paymentId: paymentId,
          userId: _currentUser!.uid,
          amount: FeeService.defaultFee.monthlyAmount,
          month: currentMonth,
          timestamp: DateTime.now(),
          status: PaymentStatus.success,
          method: 'Razorpay',
          gatewayOrderId: response.orderId,
        );

        await ref.read(firebaseServiceProvider).recordPayment(payment);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Payment successful! Your membership is now active for ${DateFormat('MMMM yyyy').format(DateTime.now())}.'),
                ),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment recorded but error updating status: $e'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      setState(() => _isProcessingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text('Payment failed: ${response.message ?? 'Unknown error'}'),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    if (mounted) {
      setState(() => _isProcessingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('External wallet selected: ${response.walletName}'),
          backgroundColor: Colors.blue,
        ),
      );
    }
  }

  void _openCheckout(UserModel user) {
    _currentUser = user;
    _isDonation = false;
    
    if (PaymentConfig.useMockPayment) {
      _simulateMockPayment(user, 'Monthly Membership Fee');
      return;
    }
    
    var options = {
      'key': _razorpayKey,
      'amount': FeeService.defaultFee.amountInPaise,
      'name': PaymentConfig.merchantName,
      'description': 'Monthly Membership Fee - ${DateFormat('MMMM yyyy').format(DateTime.now())}',
      'prefill': {
        'contact': user.phone,
        'email': user.email,
      },
      'external': {
        'wallets': ['paytm', 'gpay']
      },
      'theme': {
        'color': '#1A1A2E'
      }
    };

    try {
      setState(() => _isProcessingPayment = true);
      _razorpay.open(options);
    } catch (e) {
      debugPrint('Error opening Razorpay: $e');
      if (mounted) setState(() => _isProcessingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening payment gateway: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Logout'),
                  content: const Text('Are you sure you want to logout?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                    TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('LOGOUT')),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(firebaseServiceProvider).signOut();
                ref.read(loggedInUserProvider.notifier).state = null;
              }
            },
          ),

        ],
      ),
      body: Stack(
        children: [
          userAsync.when(
            data: (user) {
              if (user == null) return const Center(child: Text('User not found'));
              
              final bool isOverdue = _feeService.isFeeOverdue(user, FeeService.defaultFee);
              if (isOverdue) {
                return _buildOverdueLock(context, user);
              }
              
              return _buildDashboardContent(context, user);
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error: $e')),
          ),
          
          if (_isProcessingPayment)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: Center(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 24),
                        const Text(
                          'Processing Payment...',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Please do not close the app or refresh.',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: () => setState(() => _isProcessingPayment = false),
                          child: Text(
                            'CANCEL',
                            style: TextStyle(color: Colors.red.shade400, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOverdueLock(BuildContext context, UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(40),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.lock_clock_rounded, size: 80, color: Colors.red.shade700),
          const SizedBox(height: 24),
          Text(
            'PAYMENT REQUIRED',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red.shade900),
          ),
          const SizedBox(height: 16),
          Text(
            'Your monthly membership fee is overdue. Please pay now to continue using the application features.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.red.shade700),
          ),
          const SizedBox(height: 40),
          _buildPaymentButton(context, user),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () async {
              await ref.read(firebaseServiceProvider).signOut();
              ref.read(loggedInUserProvider.notifier).state = null;
            },
            icon: const Icon(Icons.logout),
            label: const Text('LOGOUT'),
            style: TextButton.styleFrom(foregroundColor: Colors.grey.shade700),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildDashboardContent(BuildContext context, UserModel user) {
    final String currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    final bool isPaidThisMonth = user.lastPaymentMonth == DateFormat('yyyy-MM').format(DateTime.now());
    final bool isActive = user.status == MembershipStatus.active;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMemberCard(user)
              .animate()
              .fadeIn(duration: 400.ms)
              .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1)),
          const SizedBox(height: 32),
          _buildMeetingSection(context),
          const SizedBox(height: 16),
          _buildStatusSection(context, isActive, isPaidThisMonth, currentMonth)
              .animate()
              .fadeIn(delay: 200.ms)
              .moveY(begin: 20, end: 0),
          const SizedBox(height: 24),
          _buildPaymentButton(context, user)
              .animate()
              .shake(delay: 1.seconds, duration: 500.ms),
          const SizedBox(height: 24),
          _buildPetitionButton(context, user),
          const SizedBox(height: 16),
          _buildChangePasswordButton(context),
          const SizedBox(height: 24),
          _buildDonationSection(context, user),
          const SizedBox(height: 40),
          Text(
            'PAYMENT HISTORY',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 16),
          _buildPaymentHistory(user),
        ],
      ),
    );
  }

  Widget _buildMemberCard(UserModel user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'நீதியைத்தேடி',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2),
              ),
              const Icon(Icons.verified, color: AppTheme.accentColor, size: 28),
            ],
          ),
          const SizedBox(height: 32),
          Text(
            user.name.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'ID: ${user.membershipId ?? "Processing..."}',
            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16, letterSpacing: 1.2),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('JOINED', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                  Text(
                    DateFormat('MMM yyyy').format(user.joinDate),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('ROLE', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10)),
                  Text(
                    user.role.name.toUpperCase(),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
  void _openDonationCheckout(UserModel user, double amount) {
    _currentUser = user;
    _isDonation = true;
    _donationAmount = amount;
    
    if (PaymentConfig.useMockPayment) {
      _simulateMockPayment(user, 'Donation \u20b9${amount.toInt()}');
      return;
    }
    
    var options = {
      'key': _razorpayKey,
      'amount': (amount * 100).toInt(),
      'name': PaymentConfig.merchantName,
      'description': 'Voluntary Donation',
      'prefill': {
        'contact': user.phone,
        'email': user.email,
      },
      'theme': {'color': '#1A1A2E'}
    };

    try {
      setState(() => _isProcessingPayment = true);
      _razorpay.open(options);
    } catch (e) {
      if (mounted) setState(() => _isProcessingPayment = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  void _simulateMockPayment(UserModel user, String description) {
    setState(() => _isProcessingPayment = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Processing Test Payment...', style: TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Text(description, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('TEST MODE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.amber.shade800)),
            ),
          ],
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.pop(context); // Close processing dialog
      
      // Create a mock PaymentSuccessResponse by calling the handler directly
      final mockPaymentId = 'mock_${DateTime.now().millisecondsSinceEpoch}';
      _handleMockPaymentSuccess(mockPaymentId);
    });
  }

  void _handleMockPaymentSuccess(String mockPaymentId) async {
    try {
      final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());

      if (_isDonation) {
        final donation = DonationRecord(
          id: '',
          userId: _currentUser!.uid,
          userName: _currentUser!.name,
          amount: _donationAmount,
          timestamp: DateTime.now(),
          paymentId: mockPaymentId,
          status: 'success',
        );
        await ref.read(firebaseServiceProvider).recordDonation(donation);
      } else {
        final payment = PaymentModel(
          paymentId: mockPaymentId,
          userId: _currentUser!.uid,
          amount: FeeService.defaultFee.monthlyAmount,
          month: currentMonth,
          timestamp: DateTime.now(),
          status: PaymentStatus.success,
          method: 'Mock Test',
          gatewayOrderId: null,
        );
        await ref.read(firebaseServiceProvider).recordPayment(payment);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('\u2705 Test Payment Successful! (Mock Mode)')),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error recording payment: $e'), backgroundColor: Colors.orange),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessingPayment = false);
    }
  }

  Widget _buildDonationSection(BuildContext context, UserModel user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade800, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.volunteer_activism, color: Colors.white),
              SizedBox(width: 8),
              Text('SUPPORT NEETHIYAITHEDI', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Your contributions help us provide better legal support to everyone. You can donate any amount.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _showDonationDialog(context, user),
              icon: const Icon(Icons.favorite, size: 18),
              label: const Text('DONATE NOW'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDonationDialog(BuildContext context, UserModel user) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Make a Donation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter amount you wish to contribute:'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: '₹ ',
                border: OutlineInputBorder(),
                hintText: 'e.g. 500',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              final amount = double.tryParse(controller.text);
              if (amount != null && amount > 0) {
                Navigator.pop(context);
                _openDonationCheckout(user, amount);
              }
            },
            child: const Text('PROCEED'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection(BuildContext context, bool isActive, bool isPaid, String month) {
    final feeConfig = FeeService.defaultFee;
    
    // Check for Free Membership
    final userAsync = ref.read(currentUserProvider);
    final isFreeMembership = userAsync.value?.isMembershipFree ?? false;

    if (isFreeMembership) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified, color: Colors.green, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Membership Active',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      'Lifetime Free Membership',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    final isOverdue = !isPaid && DateTime.now().day > feeConfig.dueDay;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isPaid ? Colors.green : (isOverdue ? Colors.red : Colors.orange)).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isPaid ? Icons.check_circle : (isOverdue ? Icons.error : Icons.warning),
                color: isPaid ? Colors.green : (isOverdue ? Colors.red : Colors.orange),
                size: 32,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPaid ? 'Fees Paid' : (isOverdue ? 'Fees Overdue!' : 'Fees Pending'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  Text(
                    isPaid 
                        ? 'You are active for $month' 
                        : 'Pay ₹${feeConfig.monthlyAmount.toInt()} for $month to stay active',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  if (isOverdue)
                    Text(
                      'Payment was due on ${feeConfig.dueDay}th of the month',
                      style: TextStyle(color: Colors.red.shade400, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentButton(BuildContext context, UserModel user) {
    if (user.isMembershipFree) return const SizedBox.shrink();
    
    final feeConfig = FeeService.defaultFee;

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isProcessingPayment ? null : () => _openCheckout(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: _isProcessingPayment
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text('Processing...'),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.payment),
                  const SizedBox(width: 12),
                  Text('Pay Monthly Fee (₹${feeConfig.monthlyAmount.toInt()})'),
                ],
              ),
      ),
    );
  }

  Widget _buildPaymentHistory(UserModel user) {
    final historyAsync = ref.watch(firebaseServiceProvider).getUserPaymentHistory(user.uid);
    
    return StreamBuilder<List<PaymentModel>>(
      stream: historyAsync,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Error loading history: ${snapshot.error}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ),
          );
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'Loading payments...',
              style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(Icons.receipt_long, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 12),
                Text(
                  'No payments yet',
                  style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your payment history will appear here',
                  style: TextStyle(color: Colors.grey[500], fontSize: 12),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final payment = snapshot.data![index];
            return Container(
              padding: const EdgeInsets.all(16),
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
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: payment.status == PaymentStatus.success 
                          ? Colors.green.withOpacity(0.1) 
                          : Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      payment.status == PaymentStatus.success ? Icons.check : Icons.hourglass_empty,
                      color: payment.status == PaymentStatus.success ? Colors.green : Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          DateFormat('MMMM yyyy').format(payment.timestamp),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'ID: ${payment.paymentId.substring(0, payment.paymentId.length > 12 ? 12 : payment.paymentId.length)}...',
                          style: TextStyle(color: Colors.grey[600], fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '₹${payment.amount.toInt()}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: payment.status == PaymentStatus.success 
                              ? Colors.green.withOpacity(0.1) 
                              : Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          payment.status.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: payment.status == PaymentStatus.success ? Colors.green : Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  Widget _buildMeetingSection(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ref.read(firebaseServiceProvider).streamMeetConfig(),
      builder: (context, snapshot) {
        final data = snapshot.data ?? {};
        final meetUrl = data['url'] as String?;
        final isActive = data['active'] as bool? ?? false;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: (isActive && meetUrl != null && meetUrl.isNotEmpty)
                  ? [Colors.blue.shade700, Colors.blue.shade900]
                  : [Colors.grey.shade700, Colors.grey.shade900],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.videocam_rounded, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'WEEKLY MEETING',
                    style: GoogleFonts.notoSansTamil(
                      textStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (isActive) ...[
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle, size: 8, color: Colors.white),
                          SizedBox(width: 4),
                          Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10)),
                        ],
                      ),
                    ).animate(onPlay: (controller) => controller.repeat()).shimmer(duration: 2.seconds),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(
                isActive 
                  ? 'Meeting is live. Join now to participate.'
                  : 'Join our weekly meetings for legal updates. Link will be active during meeting time.',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              if (meetUrl == null || meetUrl.isEmpty)
                _buildStatusButton('Link not yet set by Admin')
              else if (!isActive)
                _buildStatusButton('Waiting for host to start...')
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      String url = meetUrl;
                      if (!url.startsWith('http')) {
                        url = 'https://$url';
                      }
                      final uri = Uri.parse(url);
                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error launching: $e'))
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.group_add),
                    label: const Text('JOIN MEETING NOW'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue.shade900,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                  ),
                ),
            ],
          ),
        ).animate().fadeIn(duration: 500.ms).slideY(begin: 0.2, end: 0);
      },
    );
  }

  Widget _buildStatusButton(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _buildPetitionButton(BuildContext context, UserModel user) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: AppTheme.primaryColor.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => PetitionTypeSelectionScreen(currentUser: user)));
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.gavel_rounded, color: AppTheme.primaryColor, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Petitions',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      Text(
                        'Generate compliant legal PDF documents',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildChangePasswordButton(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _showChangePasswordDialog(context),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lock_reset, color: Colors.blue, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Password',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      Text(
                        'Secure your account',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Update Password'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscurePassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscurePassword = !obscurePassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Required';
                    if (value.length < 6) return 'Min 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: obscureConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: const Icon(Icons.check_circle_outline),
                    suffixIcon: IconButton(
                      icon: Icon(obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => obscureConfirmPassword = !obscureConfirmPassword),
                    ),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value != passwordController.text) return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (formKey.currentState!.validate()) {
                        setState(() => isLoading = true);
                        try {
                          await ref.read(firebaseServiceProvider).changePassword(passwordController.text);
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Password updated successfully'),
                                backgroundColor: Colors.green,
                              ),
                            );
                          }
                        } catch (e) {
                          setState(() => isLoading = false);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
              child: isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('UPDATE'),
            ),
          ],
        ),
      ),
    );
  }
}
