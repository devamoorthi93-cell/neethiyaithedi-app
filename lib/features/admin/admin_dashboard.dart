import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_theme.dart';
import '../../core/providers.dart';
import '../../models/user_model.dart';
import '../../models/membership_request_model.dart';
import '../../models/fee_model.dart';
import '../../core/export_service.dart';
import '../../services/fee_service.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import '../../features/legal/petition_screen.dart';
import '../../features/legal/petition_type_selection_screen.dart';
import '../../models/petition_record_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/donation_model.dart';
import '../../services/doc_service.dart';
import 'package:url_launcher/url_launcher.dart';

class AdminDashboard extends ConsumerStatefulWidget {
  const AdminDashboard({super.key});

  @override
  ConsumerState<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<AdminDashboard> {
  String _searchQuery = '';
  MembershipStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(firebaseServiceProvider).getAllMembers();

    return DefaultTabController(
      length: 8,
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('ADMIN CONSOLE'),
        elevation: 0,
        bottom: TabBar(
          isScrollable: true,
          tabs: const [
            Tab(text: 'MEMBERS'),
            Tab(text: 'FEES'),
            Tab(text: 'PETITIONS'),
            Tab(text: 'REQUESTS'),
            Tab(text: 'NOTIFICATIONS'),
            Tab(text: 'DONATIONS'),
            Tab(text: 'CONFIG'),
            Tab(text: 'ADMINS'),
          ],
            indicatorColor: AppTheme.accentColor,
            indicatorWeight: 4,
            indicatorSize: TabBarIndicatorSize.label,
            indicator: UnderlineTabIndicator(
              borderSide: BorderSide(width: 4, color: AppTheme.accentColor),
              insets: const EdgeInsets.symmetric(horizontal: 16),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withOpacity(0.5),
            labelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
              fontSize: 14,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              letterSpacing: 1.2,
              fontSize: 14,
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.gavel), // Changed to filled icon
              tooltip: 'Legal Petition',
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => const PetitionTypeSelectionScreen()));
              },
            ),
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              tooltip: 'Export PDF',
              onPressed: () => _exportToPdf(ref),
            ),
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Export Excel',
              onPressed: () => _exportToExcel(ref),
            ),
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Logout',
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
        body: TabBarView(
          children: [
            // Members Tab
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(membersAsync),
                ),
                SliverToBoxAdapter(
                  child: _buildFilters(),
                ),
                SliverToBoxAdapter(
                  child: _buildPetitionsButton(context),
                ),
                StreamBuilder<List<UserModel>>(
                  stream: membersAsync,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SliverToBoxAdapter(child: _buildShimmerList());
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return const SliverFillRemaining(
                        child: Center(child: Text('No members found')),
                      );
                    }

                    final filteredMembers = snapshot.data!.where((m) {
                      final matchesSearch = m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                          (m.membershipId?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
                      final matchesStatus = _filterStatus == null || m.status == _filterStatus;
                      return matchesSearch && matchesStatus;
                    }).toList();

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final member = filteredMembers[index];
                          return _buildMemberTile(member)
                              .animate()
                              .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                              .moveX(begin: 20, end: 0);
                        },
                        childCount: filteredMembers.length,
                      ),
                    );
                  },
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),

            // Fees Tab - Unpaid Members
            _buildFeesTab(),

            // Petitions Tab - Global History
            _buildPetitionsHistoryTab(),

            // Requests Tab
            CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Membership Requests',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                  ),
                ),
                StreamBuilder<List<MembershipRequestModel>>(
                  stream: ref.read(firebaseServiceProvider).getAllMembershipRequests(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SliverToBoxAdapter(child: _buildShimmerList());
                    }
                    
                    if (snapshot.hasError) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_add_disabled_outlined, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No pending requests',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'New membership requests will appear here',
                                style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final requests = snapshot.data!;

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final request = requests[index];
                          return _buildRequestTile(request)
                              .animate()
                              .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                              .moveX(begin: 20, end: 0);
                        },
                        childCount: requests.length,
                      ),
                    );
                  },
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),

            // Notifications Tab
            _buildNotificationsTab(),

            // Donations Tab
            _buildDonationsTab(),

            // Config Tab
            _buildConfigTab(),

            // Admins Tab
            CustomScrollView(
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Administrators',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                    ),
                  ),
                ),
                StreamBuilder<List<UserModel>>(
                  stream: ref.read(firebaseServiceProvider).getAllAdmins(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SliverToBoxAdapter(child: _buildShimmerList());
                    }
                    
                    if (snapshot.hasError) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline, size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                      );
                    }
                    
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.admin_panel_settings_outlined, size: 64, color: Colors.grey[300]),
                              const SizedBox(height: 16),
                              Text(
                                'No administrators found',
                                style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                      );
                    }

                    final admins = snapshot.data!;

                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final admin = admins[index];
                          return _buildMemberTile(admin)
                              .animate()
                              .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                              .moveX(begin: 20, end: 0);
                        },
                        childCount: admins.length,
                      ),
                    );
                  },
                ),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          ],
        ),
        floatingActionButton: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.primaryColor,
                AppTheme.primaryColor.withOpacity(0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: FloatingActionButton.extended(
            onPressed: () => _showAddMemberDialog(context),
            backgroundColor: Colors.transparent,
            elevation: 0,
            highlightElevation: 0,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.person_add_rounded),
            label: const Text(
              'Add Member',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Stream<List<UserModel>> stream) {
    return StreamBuilder<List<UserModel>>(
      stream: stream,
      builder: (context, snapshot) {
        final total = snapshot.data?.length ?? 0;
        final active = snapshot.data?.where((m) => m.status == MembershipStatus.active).length ?? 0;
        final inactive = total - active;

        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _buildStatCard('TOTAL', total.toString(), Icons.people_outline)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildStatCard('ACTIVE', active.toString(), Icons.check_circle_outline)),
                ],
              ),
              const SizedBox(height: 24),
              _buildChartSection(active, inactive),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 10, letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _buildChartSection(int active, int inactive) {
    return SizedBox(
      height: 120,
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: PieChart(
              PieChartData(
                sectionsSpace: 0,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(
                    value: active.toDouble(),
                    title: '',
                    color: AppTheme.accentColor,
                    radius: 12,
                  ),
                  PieChartSectionData(
                    value: inactive.toDouble(),
                    title: '',
                    color: Colors.white.withOpacity(0.2),
                    radius: 10,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),
          Expanded(
            flex: 3,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildChartLegend('Active Members', AppTheme.accentColor),
                const SizedBox(height: 8),
                _buildChartLegend('Inactive Members', Colors.white.withOpacity(0.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    );
  }

  Widget _buildPetitionsButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
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
              Navigator.push(context, MaterialPageRoute(builder: (_) => const PetitionTypeSelectionScreen()));
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
                          'Generate legal PDF documents',
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
      ),
    );
  }

  Widget _buildShimmerList() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: 5,
        itemBuilder: (_, __) => ListTile(
          leading: const CircleAvatar(),
          title: Container(height: 12, width: 100, color: Colors.white),
          subtitle: Container(height: 10, width: 60, color: Colors.white),
        ),
      ),
    );
  }

  // Fees Tab - Shows unpaid members for current month
  Widget _buildFeesTab() {
    final feeService = FeeService();
    final currentMonth = DateFormat('MMMM yyyy').format(DateTime.now());
    final currentMonthKey = DateFormat('yyyy-MM').format(DateTime.now());
    final feeConfig = FeeService.defaultFee;
    final isOverdueDay = DateTime.now().day > feeConfig.dueDay;

    return CustomScrollView(
      slivers: [
        // Header with fee stats
        SliverToBoxAdapter(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  isOverdueDay ? Colors.red.shade700 : Colors.orange.shade700,
                  isOverdueDay ? Colors.red.shade500 : Colors.orange.shade500,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isOverdueDay ? Icons.warning_rounded : Icons.payments_outlined,
                      color: Colors.white,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      isOverdueDay ? 'OVERDUE FEES' : 'PENDING FEES',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  currentMonth,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildFeeStatCard('Monthly Fee', '₹${feeConfig.monthlyAmount.toInt()}'),
                    const SizedBox(width: 12),
                    _buildFeeStatCard('Due Date', '${feeConfig.dueDay}th'),
                    const SizedBox(width: 12),
                    StreamBuilder<List<UserModel>>(
                      stream: feeService.getUnpaidMembers(),
                      builder: (context, snapshot) {
                        final count = snapshot.data?.length ?? 0;
                        return Expanded(
                          child: InkWell(
                            onTap: count > 0 ? () => _showUnpaidMembersDialog(context, snapshot.data!) : null,
                            child: _buildFeeStatCard(
                              'Unpaid', 
                              '$count Members',
                              subtitle: count > 0 ? 'Click to view' : null,
                              color: count > 0 ? Colors.white : Colors.white.withOpacity(0.5),
                            ),
                          ),
                        );
                      }
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Section title
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 12),
            child: Text(
              'MEMBERS WITH UNPAID FEES',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
        ),

        // Unpaid members list
        StreamBuilder<List<UserModel>>(
          stream: feeService.getUnpaidMembers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SliverToBoxAdapter(child: _buildShimmerList());
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, size: 64, color: Colors.green.shade300),
                      const SizedBox(height: 16),
                      const Text(
                        'All members have paid!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'No pending fees for $currentMonth',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            }

            final unpaidMembers = snapshot.data!;

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final member = unpaidMembers[index];
                  final feeStatus = feeService.getMemberFeeStatus(member, feeConfig);
                  
                  return _buildUnpaidMemberTile(member, feeStatus, feeConfig)
                      .animate()
                      .fadeIn(duration: 300.ms, delay: (index * 50).ms)
                      .moveX(begin: 20, end: 0);
                },
                childCount: unpaidMembers.length,
              ),
            );
          },
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  void _showUnpaidMembersDialog(BuildContext context, List<UserModel> unpaidMembers) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('UNPAID MEMBERS', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '${DateFormat('MMMM yyyy').format(DateTime.now())}',
              style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.normal),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: unpaidMembers.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final member = unpaidMembers[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
                  child: Text(member.name[0].toUpperCase(), style: const TextStyle(color: AppTheme.primaryColor)),
                ),
                title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.membershipId ?? 'No ID', style: const TextStyle(fontSize: 12)),
                    Text(member.phone, style: const TextStyle(fontSize: 12)),
                  ],
                ),
                trailing: TextButton(
                  onPressed: () {
                    // Possible future action: Send reminder
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reminder feature coming soon for ${member.name}'))
                    );
                  },
                  child: const Text('REMIND'),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildFeeStatCard(String title, String value, {String? subtitle, Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: (color ?? Colors.white).withOpacity(0.7),
              fontSize: 10,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color ?? Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: (color ?? Colors.white).withOpacity(0.5),
                fontSize: 9,
              ),
            ),
          ],
        ],
      ),
    );
  }


  Widget _buildPetitionsHistoryTab() {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Petition History',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
                Text(
                  'All petitions generated by members',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        StreamBuilder<List<PetitionRecord>>(
          stream: ref.read(firebaseServiceProvider).getPetitionHistory(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SliverToBoxAdapter(child: _buildShimmerList());
            }
            
            if (snapshot.hasError) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.description_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No petitions found',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Generated petitions will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              );
            }

            final records = snapshot.data!;

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final record = records[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showPetitionDetails(record),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            onTap: () => _showPetitionDetails(record), // Double insurance
                            title: Text(record.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('By: ${record.userName}', style: const TextStyle(fontSize: 12)),
                                Text('Type: ${record.petitionType}', style: const TextStyle(fontSize: 12)),
                                Text(DateFormat('dd MMM yyyy, hh:mm a').format(record.timestamp), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                            trailing: const Icon(Icons.picture_as_pdf, color: Colors.red),
                          ),
                        ),
                      ),
                    ),
                  ).animate().fadeIn(duration: 300.ms, delay: (index * 50).ms);
                },
                childCount: records.length,
              ),
            );
          },
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }

  Widget _buildConfigTab() {
    final TextEditingController meetController = TextEditingController();
    final TextEditingController broadcastTitleController = TextEditingController();
    final TextEditingController broadcastBodyController = TextEditingController();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'App Configuration',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 24),
          
          // Google Meet Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.video_call, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Weekly Google Meet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Members will see this link on their dashboard. They can join but cannot copy the link.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                StreamBuilder<Map<String, dynamic>?>(
                  stream: ref.read(firebaseServiceProvider).streamMeetConfig(),
                  builder: (context, snapshot) {
                    final data = snapshot.data ?? {};
                    final currentLink = data['url'] as String? ?? '';
                    final isActive = data['active'] as bool? ?? false;
                    
                    // Only update text controller if user hasn't typed anything yet
                    if (meetController.text.isEmpty && currentLink.isNotEmpty) {
                      meetController.text = currentLink;
                    }
                    
                    // Local state for switch (we need a stateful widget or use a ValueNotifier, but here we can just rely on stream updates 
                    // or better, use a StatefulBuilder inside if we want immediate feedback, 
                    // BUT since we have a SAVE button, the switch should probably just control a variable?
                    // actually, the user might expect the switch to save immediately or be part of the form.
                    // Given the existing "POST MEETING LINK" button, let's make the switch part of the form.
                    // We need a boolean variable to hold the switch state. 
                    // Since this is a builder, we can't easily maintain state here without a parent state variable.
                    // Let's assume we add `bool _isMeetingActive = true;` to the class state 
                    // OR we can just use a StatefulBuilder here.
                    
                    return StatefulBuilder(
                      builder: (context, setState) {
                        // Initialize local state from stream if not set (this is tricky in builder)
                        // A better approach: Read stream, set initial value in a variable defined in the PARENT State class.
                        // However, to avoid refactoring the whole class, let's use a simpler approach:
                        // Just show the current database state in the switch, and when toggled, update local var?
                        // No, let's just make the "POST" button save meaningful state.
                        
                        return Column(
                      children: [
                        TextField(
                          controller: meetController,
                          decoration: InputDecoration(
                            labelText: 'Meet URL',
                            hintText: 'https://meet.google.com/xxx-xxxx-xxx',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.link),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Show Link to Members'),
                          subtitle: Text(isActive ? 'Currently Visible' : 'Currently Hidden'),
                          value: isActive,
                          onChanged: (val) async {
                             // Auto-save toggle for immediate effect?
                             // User asked for "Manual control". Immediate toggle is best for "Enable/Disable".
                             if (meetController.text.isNotEmpty) {
                               await ref.read(firebaseServiceProvider).setMeetConfig(meetController.text, val);
                             }
                          },
                          secondary: Icon(isActive ? Icons.visibility : Icons.visibility_off, color: isActive ? Colors.green : Colors.grey),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (meetController.text.isNotEmpty) {
                                    String url = meetController.text.trim();
                                    if (!url.startsWith('http')) {
                                      url = 'https://$url';
                                    }
                                    final uri = Uri.tryParse(url);
                                    if (uri != null && await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid URL')));
                                    }
                                  }
                                },
                                icon: const Icon(Icons.video_call),
                                label: const Text('JOIN NOW'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: Colors.blue,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  side: const BorderSide(color: Colors.blue),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  if (meetController.text.isNotEmpty) {
                                    // Keep current active state or set to true? 
                                    // Let's assume saving always updates date, but we should probably keep existing active state or default to true?
                                    // Let's just use the current 'isActive' from stream (snapshot) as the value, 
                                    // effectively only updating the URL and timestamp.
                                    await ref.read(firebaseServiceProvider).setMeetConfig(meetController.text, isActive);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Meeting Link Updated'), backgroundColor: Colors.green)
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryColor,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('UPDATE LINK'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                      }
                    );
                  }
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Global Broadcast Section
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.campaign, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('Global Broadcast', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Send a push notification to all members. Use this for urgent and important announcements.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: broadcastTitleController,
                  decoration: InputDecoration(
                    labelText: 'Announcement Title',
                    hintText: 'e.g., Important Membership Update',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.title),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: broadcastBodyController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Announcement Message',
                    hintText: 'Enter your message here...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.message_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      if (broadcastTitleController.text.isEmpty || broadcastBodyController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter both title and message'), backgroundColor: Colors.red)
                        );
                        return;
                      }

                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Confirm Broadcast'),
                          content: const Text('This will send a push notification to ALL members. Are you sure?'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('SEND')),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await ref.read(firebaseServiceProvider).sendBroadcastNotification(
                            broadcastTitleController.text,
                            broadcastBodyController.text,
                          );
                          broadcastTitleController.clear();
                          broadcastBodyController.clear();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Broadcast sent successfully!'), backgroundColor: Colors.green)
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.send_rounded),
                    label: const Text('SEND TO ALL MEMBERS'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 100),
        ],
      ),
    );
  }
  void _showPetitionDetails(PetitionRecord record) {
    debugPrint('Opening petition details for: ${record.title}');
    debugPrint('Record ID: ${record.id}');
    debugPrint('Content length: ${record.content.length}');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(record.petitionType.toUpperCase(), style: const TextStyle(fontSize: 12, color: AppTheme.primaryColor, fontWeight: FontWeight.bold)),
            Text(record.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('User', record.userName),
                _buildDetailRow('Date', DateFormat('dd MMM yyyy, hh:mm a').format(record.timestamp)),
                const Divider(),
                if (record.subject.isNotEmpty) ...[
                  const Text('Subject (பார்வை):', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(record.subject, style: const TextStyle(fontSize: 13)),
                  const SizedBox(height: 12),
                ],
                const Text('Content Details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: Text(
                    record.content.isEmpty ? '(No content saved for this record)' : record.content,
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text('$label:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildUnpaidMemberTile(UserModel member, MemberFeeStatus feeStatus, FeeConfiguration config) {
    final bool isOverdue = feeStatus.isOverdue;
    final currentMonthKey = DateFormat('yyyy-MM').format(DateTime.now());
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverdue ? Colors.red.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: (isOverdue ? Colors.red : Colors.orange).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
      children: [
        InkWell(
          onTap: () => _showMemberProfile(context, member),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: (isOverdue ? Colors.red : Colors.orange).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      member.name[0].toUpperCase(),
                      style: TextStyle(
                        color: isOverdue ? Colors.red : Colors.orange,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Member info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        member.membershipId ?? 'No ID',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '${member.petitionCount} Petitions',
                              style: const TextStyle(fontSize: 10, color: AppTheme.primaryColor, fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.phone, size: 12, color: Colors.grey.shade500),
                          const SizedBox(width: 4),
                          Text(
                            member.phone,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Status badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: (isOverdue ? Colors.red : Colors.orange).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        feeStatus.statusText.toUpperCase(),
                        style: TextStyle(
                          color: isOverdue ? Colors.red : Colors.orange,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
          const Divider(height: 24),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    await ref.read(firebaseServiceProvider).sendManualReminder(member.uid);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reminder trigger sent!'), backgroundColor: Colors.orange)
                    );
                  } catch (e) {
                     ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red)
                    );
                  }
                },
                icon: const Icon(Icons.notifications_active_outlined, size: 18),
                label: const Text('REMIND'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final phone = member.phone;
                  final cleanPhone = phone.replaceAll(RegExp(r'[^0-9]'), '');
                  final tamilMonth = [
                    'ஜனவரி', 'பிப்ரவரி', 'மார்ச்', 'ஏப்ரல்', 'மே', 'ஜூன்',
                    'ஜூலை', 'ஆகஸ்ட்', 'செப்டம்பர்', 'அக்டோபர்', 'நவம்பர்', 'டிசம்பர்'
                  ][DateTime.now().month - 1];
                  
                  final message = Uri.encodeComponent(
                    "*நீதியைத் தேடி (Neethiyai Thedi)*\n\n" +
                    "வணக்கம், ${member.name}. ${tamilMonth} மாதத்திற்கான உங்கள் சந்தா (₹100) இன்னும் செலுத்தப்படவில்லை. தயவுசெய்து விரைந்து செலுத்தவும்.\n\n" +
                    "Greetings. Your monthly subscription for ${DateFormat('MMMM').format(DateTime.now())} is pending. Please pay at your earliest convenience."
                  );
                  
                  final url = "https://wa.me/91$cleanPhone?text=$message";
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  } else {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Could not launch WhatsApp'))
                      );
                    }
                  }
                },
                icon: const Icon(Icons.chat_outlined, size: 18),
                label: const Text('WHATSAPP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Confirm Payment'),
                      content: Text('Mark ₹${config.monthlyAmount.toInt()} as PAID for ${member.name}?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
                        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('CONFIRM')),
                      ],
                    ),
                  );
                  
                  if (confirm == true) {
                    await ref.read(firebaseServiceProvider).recordOfflinePayment(
                      member.uid, 
                      config.monthlyAmount, 
                      currentMonthKey,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Payment recorded for ${member.name}'), backgroundColor: Colors.green)
                    );
                  }
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('MARK PAID'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsTab() {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification Logs',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
                Text(
                  'Track reminders sent to unpaid members',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: ref.read(firebaseServiceProvider).streamNotificationLogs(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SliverToBoxAdapter(child: _buildShimmerList());
            }
            
            if (snapshot.hasError) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No notification history',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Logs of sent reminders will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              );
            }

            final logs = snapshot.data!;

            return SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final log = logs[index];
                  final status = log['status'] as String?;
                  final sentAt = log['sentAt'] as Timestamp?;
                  
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: status == 'sent' ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1),
                        child: Icon(
                          status == 'sent' ? Icons.check_circle_outline : Icons.error_outline,
                          color: status == 'sent' ? Colors.green : Colors.red,
                        ),
                      ),
                      title: Text(log['userName'] ?? 'Unknown User', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Type: ${log['type']}', style: const TextStyle(fontSize: 12)),
                          if (log['error'] != null)
                            Text('Error: ${log['error']}', style: const TextStyle(fontSize: 11, color: Colors.red)),
                          if (sentAt != null)
                            Text(DateFormat('dd MMM yyyy, hh:mm a').format(sentAt.toDate()), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                        ],
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: (status == 'sent' ? Colors.green : Colors.red).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          status?.toUpperCase() ?? 'UNKNOWN',
                          style: TextStyle(
                            color: status == 'sent' ? Colors.green : Colors.red,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  );
                },
                childCount: logs.length,
              ),
            );
          },
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }


  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(
                  hintText: 'Search members...',
                  prefixIcon: Icon(Icons.search, color: AppTheme.primaryColor),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(16),
            ),
            child: PopupMenuButton<MembershipStatus?>(
              icon: const Icon(Icons.filter_list, color: AppTheme.primaryColor),
              onSelected: (s) => setState(() => _filterStatus = s),
              itemBuilder: (context) => [
                const PopupMenuItem(value: null, child: Text('All')),
                const PopupMenuItem(value: MembershipStatus.active, child: Text('Active')),
                const PopupMenuItem(value: MembershipStatus.inactive, child: Text('Inactive')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberTile(UserModel member) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => _showMemberProfile(context, member),
      leading: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            member.name[0].toUpperCase(),
            style: const TextStyle(color: AppTheme.primaryColor, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
      ),
      title: Text(member.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(member.membershipId ?? 'PENDING ID', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
          const SizedBox(height: 4),
          Text(member.phone, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
        ],
      ),
      trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: (member.status == MembershipStatus.active ? Colors.green : Colors.red).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            member.status.name.toUpperCase(),
            style: TextStyle(
              color: member.status == MembershipStatus.active ? Colors.green : Colors.red,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(width: 8),
        PopupMenuButton<String>(
          icon: Icon(Icons.more_vert, color: Colors.grey[400]),
          onSelected: (value) {
            if (value == 'edit') {
              _showEditMemberDialog(context, member);
            } else if (value == 'delete') {
              _deleteMember(context, member);
            } else if (value == 'promote') {
              _updateUserRole(context, member, UserRole.admin);
            } else if (value == 'demote') {
              _updateUserRole(context, member, UserRole.member);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'edit',
              child: Row(
                children: [
                  Icon(Icons.edit, size: 20, color: Colors.blue),
                  SizedBox(width: 12),
                  Text('Edit'),
                ],
              ),
            ),
            if (member.role == UserRole.member)
              const PopupMenuItem<String>(
                value: 'promote',
                child: Row(
                  children: [
                    Icon(Icons.security, size: 20, color: Colors.orange),
                    SizedBox(width: 12),
                    Text('Promote to Admin'),
                  ],
                ),
              ),
            if (member.role == UserRole.admin)
              const PopupMenuItem<String>(
                value: 'demote',
                child: Row(
                  children: [
                    Icon(Icons.person_outline, size: 20, color: Colors.blueGrey),
                    SizedBox(width: 12),
                    Text('Demote to Member'),
                  ],
                ),
              ),
            const PopupMenuItem<String>(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 12),
                  Text('Delete'),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  ),
);
}

void _showMemberProfile(BuildContext context, UserModel member) {
  showDialog(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        member.name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      member.name,
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      member.membershipId ?? 'PENDING ID',
                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 16),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: (member.status == MembershipStatus.active ? Colors.green : Colors.red).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: member.status == MembershipStatus.active ? Colors.green : Colors.red),
                      ),
                      child: Text(
                        member.status.name.toUpperCase(),
                        style: TextStyle(
                          color: member.status == MembershipStatus.active ? Colors.greenAccent : Colors.redAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileSection('Contact Information', [
                      _buildProfileItem(Icons.phone, 'Phone', member.phone),
                      _buildProfileItem(Icons.email, 'Email', member.email),
                      _buildProfileItem(Icons.location_on, 'Address', member.address ?? 'Not provided'),
                    ]),
                    const Divider(height: 32),
                    _buildProfileSection('Activity & Stats', [
                      _buildProfileItem(Icons.payments, 'Total Paid', '₹${member.totalPaid.toInt()}'),
                      _buildProfileItem(Icons.description, 'Petitions Generated', member.petitionCount.toString()),
                      _buildProfileItem(Icons.calendar_today, 'Joined', DateFormat('dd MMM yyyy').format(member.joinDate)),
                    ]),
                    const Divider(height: 32),
                    _buildProfileSection('Identity Verification', [
                      _buildProfileItem(Icons.badge, 'Aadhaar Number', member.aadhaarNo ?? 'Not provided'),
                      if (member.aadhaarFrontUrl != null || member.aadhaarBackUrl != null) ...[
                        const SizedBox(height: 12),
                        const Text('Aadhaar Photos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            if (member.aadhaarFrontUrl != null)
                              Expanded(
                                child: _buildDocPreview('Front', member.aadhaarFrontUrl!),
                              ),
                            if (member.aadhaarBackUrl != null) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildDocPreview('Back', member.aadhaarBackUrl!),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
              
              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: const BorderSide(color: AppTheme.primaryColor),
                        ),
                        child: const Text('CLOSE'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _showEditMemberDialog(context, member);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('EDIT'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildProfileSection(String title, List<Widget> children) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
      const SizedBox(height: 12),
      ...children,
    ],
  );
}

Widget _buildProfileItem(IconData icon, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppTheme.primaryColor.withOpacity(0.7)),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildDocPreview(String label, String url) {
  return Column(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          url,
          height: 80,
          width: double.infinity,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            height: 80,
            color: Colors.grey[200],
            child: const Icon(Icons.error_outline, color: Colors.grey),
          ),
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              height: 80,
              color: Colors.grey[100],
              child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            );
          },
        ),
      ),
      const SizedBox(height: 4),
      Text(label, style: const TextStyle(fontSize: 9, color: Colors.grey)),
    ],
  );
}

  Future<void> _updateUserRole(BuildContext context, UserModel member, UserRole newRole) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newRole == UserRole.admin ? 'Promote to Admin' : 'Demote to Member'),
        content: Text('Are you sure you want to change ${member.name}\'s role to ${newRole.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('CONFIRM', style: TextStyle(color: newRole == UserRole.admin ? Colors.orange : Colors.blueGrey)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(firebaseServiceProvider).updateUserRole(member.uid, newRole);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${member.name} is now a ${newRole.name}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Widget _buildRequestTile(MembershipRequestModel request) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(Icons.person_outline, color: AppTheme.primaryColor, size: 20),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(request.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(DateFormat('MMM dd, yyyy • hh:mm a').format(request.requestedAt), 
                        style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.status.name.toUpperCase(),
                  style: const TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(Icons.email_outlined, request.email),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.phone_outlined, request.phone),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.location_on_outlined, request.address),
          const SizedBox(height: 8),
          _buildInfoRow(Icons.credit_card_outlined, 'Aadhaar: ${request.aadhaarNo}'),
          const SizedBox(height: 16),
          Row(
            children: [
              if (request.aadhaarFrontUrl != null)
                Expanded(
                  child: _buildDocPreviewButton(
                    context, 
                    'Aadhaar Front', 
                    request.aadhaarFrontUrl!,
                  ),
                ),
              if (request.aadhaarFrontUrl != null && request.aadhaarBackUrl != null)
                const SizedBox(width: 8),
              if (request.aadhaarBackUrl != null)
                Expanded(
                  child: _buildDocPreviewButton(
                    context, 
                    'Aadhaar Back', 
                    request.aadhaarBackUrl!,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _updateRequestStatus(request.id, RequestStatus.rejected),
                  icon: const Icon(Icons.close, size: 18),
                  label: const Text('REJECT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _showApproveDialog(request),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('APPROVE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[400]),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey[700], fontSize: 13),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Future<void> _updateRequestStatus(String requestId, RequestStatus status) async {
    final bool isRjected = status == RequestStatus.rejected;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(status == RequestStatus.approved ? 'Approve Request' : 'Delete Request'),
        content: Text(isRjected 
          ? 'Are you sure you want to permanently delete this membership request?'
          : 'Are you sure you want to approve this membership request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(isRjected ? 'DELETE' : 'APPROVE', 
                style: TextStyle(color: isRjected ? Colors.red : Colors.green)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final service = ref.read(firebaseServiceProvider);
        if (isRjected) {
          await service.deleteMembershipRequest(requestId);
        } else {
          await service.updateRequestStatus(requestId, status);
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(isRjected ? 'Request deleted permanently' : 'Request approved successfully'),
              backgroundColor: isRjected ? Colors.red.shade600 : Colors.green.shade600,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _showApproveDialog(MembershipRequestModel request) async {
    await _showAddMemberDialog(context, request: request);
  }


  Future<void> _exportToPdf(WidgetRef ref) async {
    final members = await ref.read(firebaseServiceProvider).getAllMembers().first;
    final activeMembers = members.where((m) => m.status == MembershipStatus.active).toList();
    await ExportService.exportMembersToPdf(activeMembers);
  }

  Future<void> _exportToExcel(WidgetRef ref) async {
    final members = await ref.read(firebaseServiceProvider).getAllMembers().first;
    await ExportService.exportCollectionToExcel(members);
  }

  Future<void> _showAddMemberDialog(BuildContext context, {MembershipRequestModel? request}) async {
    final nameController = TextEditingController(text: request?.name);
    final emailController = TextEditingController(text: request?.email);
    final phoneController = TextEditingController(text: request?.phone);
    final passwordController = TextEditingController();
    final addressController = TextEditingController(text: request?.address);
    String? selectedGender = request?.gender;
    String? selectedBloodGroup = request?.bloodGroup;
    UserRole selectedRole = UserRole.member;
    
    final List<String> genders = ['Male', 'Female', 'Other'];
    final List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    bool isLoading = false;
    bool showPassword = false;

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: StatefulBuilder(
            builder: (context, setDialogState) => Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 420,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.95),
                      AppTheme.primaryColor.withOpacity(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1,
                              color: Colors.white,
                              size: 40,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Add New Member',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Fill in the details to register a new member',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Form
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildStyledTextField(
                            controller: nameController,
                            label: 'Full Name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),
                          _buildStyledTextField(
                            controller: emailController,
                            label: 'Email Address',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _buildStyledTextField(
                            controller: phoneController,
                            label: 'Phone Number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: passwordController,
                            obscureText: !showPassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              helperText: 'Minimum 6 characters',
                              prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showPassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setDialogState(() => showPassword = !showPassword),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedGender,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Gender',
                              prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (v) => setDialogState(() => selectedGender = v),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedBloodGroup,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Blood Group',
                              prefixIcon: Icon(Icons.bloodtype, color: AppTheme.primaryColor),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: bloodGroups.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                            onChanged: (v) => setDialogState(() => selectedBloodGroup = v),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<UserRole>(
                            value: selectedRole,
                            dropdownColor: Colors.white,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Account Role',
                              prefixIcon: Icon(Icons.security_outlined, color: AppTheme.primaryColor),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                            ),
                            items: UserRole.values.map((role) {
                              return DropdownMenuItem(
                                value: role,
                                child: Text(role.name.toUpperCase()),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setDialogState(() => selectedRole = value);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    
                    // Actions
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: isLoading ? null : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.white.withOpacity(0.5)),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      if (nameController.text.isEmpty || emailController.text.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('Name and Email are required'),
                                            backgroundColor: Colors.red.shade400,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }

                                      if (passwordController.text.length < 6) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('Password must be at least 6 characters'),
                                            backgroundColor: Colors.red.shade400,
                                            behavior: SnackBarBehavior.floating,
                                          ),
                                        );
                                        return;
                                      }

                                      setDialogState(() => isLoading = true);

                                      try {
                                        final service = ref.read(firebaseServiceProvider);
                                        final membershipId = await service.generateMembershipId();
                                        
                                        await service.createAccount(
                                          email: emailController.text.trim(),
                                          password: passwordController.text.trim(),
                                          name: nameController.text.trim(),
                                          phone: phoneController.text.trim(),
                                          membershipId: membershipId,
                                          role: selectedRole,
                                          aadhaarNo: request?.aadhaarNo,
                                          aadhaarFrontUrl: request?.aadhaarFrontUrl,
                                          aadhaarBackUrl: request?.aadhaarBackUrl,
                                          gender: selectedGender,
                                          bloodGroup: selectedBloodGroup,
                                          address: addressController.text.trim(),
                                        );

                                        // If this was from a request, delete the request
                                        if (request != null) {
                                          await service.deleteMembershipRequest(request.id);
                                        }

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Row(
                                                children: [
                                                  const Icon(Icons.check_circle, color: Colors.white),
                                                  const SizedBox(width: 12),
                                                  Text('Member added: $membershipId'),
                                                ],
                                              ),
                                              backgroundColor: Colors.green.shade600,
                                              behavior: SnackBarBehavior.floating,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setDialogState(() => isLoading = false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: Text('Error: $e'),
                                              backgroundColor: Colors.red.shade400,
                                            ),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add),
                                        SizedBox(width: 8),
                                        Text(
                                          'Add Member',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showEditMemberDialog(BuildContext context, UserModel member) async {
    final nameController = TextEditingController(text: member.name);
    final emailController = TextEditingController(text: member.email);
    final phoneController = TextEditingController(text: member.phone);
    final passwordController = TextEditingController(text: member.password);
    String? selectedGender = member.gender;
    String? selectedBloodGroup = member.bloodGroup;
    
    final List<String> genders = ['Male', 'Female', 'Other'];
    final List<String> bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
    bool isLoading = false;
    bool showPassword = false;
    String selectedFeeCategory = member.feeCategory;
    final Map<String, String> feeCategoryLabels = {
      'all_free': 'முழு இலவசம் (All Free)',
      'petition_free': 'மனு இலவசம் (Petition Free)',
      'membership_free': 'உறுப்பினர் இலவசம் (Membership Free)',
      'paid': 'கட்டணம் (Paid)',
    };

    await showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (context, anim1, anim2) => Container(),
      transitionBuilder: (context, anim1, anim2, child) {
        return ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeOutBack),
          child: StatefulBuilder(
            builder: (context, setDialogState) => Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                width: 420,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppTheme.primaryColor.withOpacity(0.95),
                      AppTheme.primaryColor.withOpacity(0.85),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryColor.withOpacity(0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.edit_outlined,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Edit Member',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            member.membershipId ?? 'No ID',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.7),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Form
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          _buildStyledTextField(
                            controller: nameController,
                            label: 'Full Name',
                            icon: Icons.person_outline,
                          ),
                          const SizedBox(height: 16),
                          _buildStyledTextField(
                            controller: emailController,
                            label: 'Email Address',
                            icon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 16),
                          _buildStyledTextField(
                            controller: phoneController,
                            label: 'Phone Number',
                            icon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: passwordController,
                            obscureText: !showPassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: Icon(Icons.lock_outline, color: AppTheme.primaryColor),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  showPassword ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey,
                                ),
                                onPressed: () => setDialogState(() => showPassword = !showPassword),
                              ),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedGender,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Gender',
                              prefixIcon: Icon(Icons.person, color: AppTheme.primaryColor),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: genders.map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                            onChanged: (v) => setDialogState(() => selectedGender = v),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedBloodGroup,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Blood Group',
                              prefixIcon: Icon(Icons.bloodtype, color: AppTheme.primaryColor),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: bloodGroups.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                            onChanged: (v) => setDialogState(() => selectedBloodGroup = v),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            value: selectedFeeCategory,
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: 'Fee Category',
                              prefixIcon: Icon(Icons.monetization_on_outlined, color: AppTheme.primaryColor),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            items: feeCategoryLabels.entries.map((e) => DropdownMenuItem(
                              value: e.key,
                              child: Text(e.value, style: TextStyle(
                                color: e.key == 'all_free' ? Colors.green.shade700 : 
                                       e.key == 'petition_free' ? Colors.orange.shade700 : Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              )),
                            )).toList(),
                            onChanged: (v) => setDialogState(() => selectedFeeCategory = v ?? 'paid'),
                          ),
                        ],
                      ),
                    ),
                    
                    // Actions
                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: isLoading ? null : () => Navigator.pop(context),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(color: Colors.white.withValues(alpha: 0.5)),
                                ),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(color: Colors.white, fontSize: 16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: isLoading
                                  ? null
                                  : () async {
                                      if (nameController.text.isEmpty || emailController.text.isEmpty) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: const Text('Name and Email are required'),
                                            backgroundColor: Colors.red.shade400,
                                          ),
                                        );
                                        return;
                                      }

                                      setDialogState(() => isLoading = true);

                                      try {
                                        final updatedMember = member.copyWith(
                                          name: nameController.text.trim(),
                                          email: emailController.text.trim(),
                                          phone: phoneController.text.trim(),
                                          password: passwordController.text.trim(),
                                          gender: selectedGender,
                                          bloodGroup: selectedBloodGroup,
                                          feeCategory: selectedFeeCategory,
                                        );

                                        await ref.read(firebaseServiceProvider).saveUserData(updatedMember);

                                        if (context.mounted) {
                                          Navigator.pop(context);
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              content: const Text('Member Updated Successfully'),
                                              backgroundColor: Colors.green.shade600,
                                            ),
                                          );
                                        }
                                      } catch (e) {
                                        setDialogState(() => isLoading = false);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Error: $e')),
                                          );
                                        }
                                      }
                                    },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppTheme.primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 24,
                                      height: 24,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Text(
                                      'Save Changes',
                                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _deleteMember(BuildContext context, UserModel member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Member?'),
        content: Text('Are you sure you want to delete ${member.name}? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCEL')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('DELETE'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        await ref.read(firebaseServiceProvider).deleteUser(member.uid);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.name} deleted successfully'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Widget _buildStyledTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppTheme.primaryColor),
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
      ),
    );
  }

  Widget _buildDocPreviewButton(BuildContext context, String label, String url) {
    return OutlinedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            child: InteractiveViewer(
              child: Image.network(
                url,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 48),
                      SizedBox(height: 16),
                      Text('Error loading image'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      icon: const Icon(Icons.remove_red_eye_outlined, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryColor,
        side: BorderSide(color: AppTheme.primaryColor.withOpacity(0.3)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildDonationsTab() {
    return CustomScrollView(
      slivers: [
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Membership Donations',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
                ),
                Text(
                  'Total contributions received from members',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        StreamBuilder<List<DonationRecord>>(
          stream: ref.read(firebaseServiceProvider).streamAllDonations(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return SliverToBoxAdapter(child: _buildShimmerList());
            }
            
            if (snapshot.hasError) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              );
            }
            
            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return SliverFillRemaining(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.volunteer_activism_outlined, size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'No donations recorded yet',
                        style: TextStyle(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Global contributions will appear here',
                        style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              );
            }

            final donations = snapshot.data!;
            final totalDonations = donations.fold<double>(0, (prev, element) => prev + element.amount);

            return SliverMainAxisGroup(
              slivers: [
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.accentColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.accentColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Contributions', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          '₹${totalDonations.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryColor),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final donation = donations[index];
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.pink.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.favorite, color: Colors.pink),
                          ),
                          title: Text(donation.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: ${donation.paymentId}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              Text(
                                DateFormat('dd MMM yyyy, hh:mm a').format(donation.timestamp),
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: Text(
                            '₹${donation.amount.toInt()}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                          ),
                        ),
                      );
                    },
                    childCount: donations.length,
                  ),
                ),
              ],
            );
          },
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
      ],
    );
  }
}

