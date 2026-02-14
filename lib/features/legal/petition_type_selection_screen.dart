import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import 'petition_screen.dart';

class PetitionTypeSelectionScreen extends ConsumerWidget {
  final UserModel? currentUser;

  const PetitionTypeSelectionScreen({super.key, this.currentUser});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncUser = ref.watch(currentUserProvider);
    final user = asyncUser.value ?? currentUser;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Petition Type'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSelectionCard(
                context,
                title: 'Court Petition',
                icon: Icons.gavel,
                color: Colors.blue.shade700,
                onTap: () {
                  Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => PetitionFormScreen(
                        currentUser: user, 
                        petitionType: 'Court Petition', // Will need to update Form to accept this
                      )
                    )
                  );
                },
              ).animate().fadeIn(duration: 400.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 20),
              
              _buildSelectionCard(
                context,
                title: 'Evidence Act Petition',
                subtitle: '(Bharatiya Sakshya Adhiniyam)',
                icon: Icons.menu_book_rounded,
                color: Colors.teal.shade700,
                onTap: () {
                   Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => PetitionFormScreen(
                        currentUser: user, 
                        petitionType: 'Evidence Act Petition',
                      )
                    )
                  );
                },
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 20),
              
              _buildSelectionCard(
                context,
                title: 'Other Petition',
                icon: Icons.description_outlined,
                color: Colors.orange.shade700,
                onTap: () {
                   Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => PetitionFormScreen(
                        currentUser: user, 
                        petitionType: 'General Petition',
                      )
                    )
                  );
                },
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms).moveY(begin: 20, end: 0),

              const SizedBox(height: 20),
              
              _buildSelectionCard(
                context,
                title: 'Reminder Petition',
                subtitle: '(நினைவூட்டல் மனு)',
                icon: Icons.history,
                color: Colors.deepPurple,
                onTap: () {
                   Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => PetitionFormScreen(
                        currentUser: user, 
                        petitionType: 'Reminder Petition',
                      )
                    )
                  );
                },
              ).animate().fadeIn(delay: 600.ms, duration: 400.ms).moveY(begin: 20, end: 0),

              const SizedBox(height: 20),
              
              _buildSelectionCard(
                context,
                title: 'Legal Notice',
                subtitle: '(சட்டப்பூர்வ அறிவிப்பு)',
                icon: Icons.gavel_rounded,
                color: Colors.red.shade800,
                onTap: () {
                   Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => PetitionFormScreen(
                        currentUser: user, 
                        petitionType: 'Legal Notice',
                      )
                    )
                  );
                },
              ).animate().fadeIn(delay: 800.ms, duration: 400.ms).moveY(begin: 20, end: 0),

              const SizedBox(height: 20),
              
              _buildSelectionCard(
                context,
                title: 'Police Complaint',
                subtitle: '(காவல் நிலைய புகார்)',
                icon: Icons.local_police_outlined,
                color: Colors.blueGrey.shade800,
                onTap: () {
                   Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => PetitionFormScreen(
                        currentUser: user, 
                        petitionType: 'Police Complaint', // Pass the type
                      )
                    )
                  );
                },
              ).animate().fadeIn(delay: 1000.ms, duration: 400.ms).moveY(begin: 20, end: 0),
              
              const SizedBox(height: 20),
              
              _buildSelectionCard(
                context,
                title: 'SP Appeal Petition',
                subtitle: '(காவல் கண்காணிப்பாளர் மேல்முறையீடு)',
                icon: Icons.security,
                color: Colors.brown.shade700,
                onTap: () {
                   Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => PetitionFormScreen(
                        currentUser: user, 
                        petitionType: 'SP Appeal Petition',
                      )
                    )
                  );
                },
              ).animate().fadeIn(delay: 1100.ms, duration: 400.ms).moveY(begin: 20, end: 0),

              const SizedBox(height: 20),

              _buildSelectionCard(
                context,
                title: 'BNSS 218 Permission Petition',
                subtitle: '(அரசு ஊழியர் மீது வழக்கு தொடர அனுமதி)',
                icon: Icons.person_search_outlined,
                color: Colors.indigo.shade900,
                onTap: () {
                   Navigator.push(
                    context, 
                    MaterialPageRoute(
                      builder: (_) => PetitionFormScreen(
                        currentUser: user, 
                        petitionType: 'BNSS 218 Permission Petition',
                      )
                    )
                  );
                },
              ).animate().fadeIn(delay: 1200.ms, duration: 400.ms).moveY(begin: 20, end: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionCard(BuildContext context, {
    required String title, 
    String? subtitle,
    required IconData icon, 
    required Color color, 
    required VoidCallback onTap
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12, 
                          color: Colors.grey.shade600
                        ),
                      ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}
