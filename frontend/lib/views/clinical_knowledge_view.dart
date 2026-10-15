import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/api_models.dart';
import '../services/api_service.dart';

class ClinicalKnowledgeView extends StatefulWidget {
  final ApiService apiService;

  const ClinicalKnowledgeView({super.key, required this.apiService});

  @override
  State<ClinicalKnowledgeView> createState() => _ClinicalKnowledgeViewState();
}

class _ClinicalKnowledgeViewState extends State<ClinicalKnowledgeView> {
  final TextEditingController _searchController = TextEditingController();
  List<KnowledgeReference> _references = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchKnowledge();
  }

  Future<void> _fetchKnowledge([String? query]) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final results = await widget.apiService.getKnowledge(query);
      if (mounted) {
        setState(() {
          _references = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load clinical knowledge: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Clinical Knowledge Base',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.charcoal, letterSpacing: -0.3),
          ),
          const SizedBox(height: 6),
          const Text(
            'Reviewed clinical guidance grounded in international medical guidelines (Rotterdam Consensus, Monash University 2023 Guidelines, ACOG, and NIH).',
            style: TextStyle(fontSize: 13.5, color: AppColors.charcoalMuted),
          ),

          const SizedBox(height: 20),

          // Search Field
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppColors.forestGreen, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search topics, symptoms, or vernacular terms (e.g. "late period", "hair growth", "rotterdam")...',
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                      ),
                      onSubmitted: (val) => _fetchKnowledge(val),
                    ),
                  ),
                  if (_searchController.text.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        _fetchKnowledge();
                      },
                    ),
                  ElevatedButton(
                    onPressed: () => _fetchKnowledge(_searchController.text),
                    child: const Text('Search'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: AppColors.sageGreen)),
            )
          else if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.emergencyRedLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.emergencyRed.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.emergencyRed),
                  const SizedBox(width: 12),
                  Expanded(child: Text(_errorMessage!, style: const TextStyle(color: AppColors.emergencyRed, fontSize: 13))),
                  TextButton(onPressed: () => _fetchKnowledge(), child: const Text('Retry')),
                ],
              ),
            )
          else if (_references.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              alignment: Alignment.center,
              child: const Column(
                children: [
                  Icon(Icons.menu_book_outlined, size: 40, color: AppColors.charcoalLight),
                  SizedBox(height: 12),
                  Text('No clinical entries found matching your search.', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.charcoal)),
                  SizedBox(height: 4),
                  Text('Try broader search terms like "period", "acne", or "insulin".', style: TextStyle(fontSize: 12, color: AppColors.charcoalMuted)),
                ],
              ),
            )
          else
            ..._references.map((ref) => _buildKnowledgeCard(ref)),
        ],
      ),
    );
  }

  Widget _buildKnowledgeCard(KnowledgeReference ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.sageGreenLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                ref.topic,
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.forestGreen),
                              ),
                            ),
                            if (ref.isDemo) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: AppColors.warningOrangeLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'DEMO REFERENCE — Pending Clinical Review',
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.warningOrange),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ref.title,
                          style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: AppColors.charcoal),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => ApiService.openWebUrl(ref.sourceUrl),
                    icon: const Icon(Icons.open_in_new, size: 13),
                    label: const Text('Source Citation', style: TextStyle(fontSize: 11.5)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                ref.plainExplanation,
                style: const TextStyle(fontSize: 13.5, color: AppColors.charcoal, height: 1.5),
              ),
              const SizedBox(height: 14),

              // Clinical Concept / Verifiable Evidence Excerpt
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.ivoryBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.verified_outlined, size: 15, color: AppColors.forestGreen),
                        const SizedBox(width: 6),
                        Text(
                          'Source Authority: ${ref.sourceOrg}',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.forestGreen),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Evidence Excerpt: "${ref.evidenceExcerpt}"',
                      style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: AppColors.charcoalMuted, height: 1.35),
                    ),
                  ],
                ),
              ),

              if (ref.vernacularTerms.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    const Text('Supported vernacular expressions: ', style: TextStyle(fontSize: 11, color: AppColors.charcoalMuted)),
                    ...ref.vernacularTerms.map(
                      (vt) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.lavenderLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(vt, style: const TextStyle(fontSize: 10.5, color: AppColors.lavenderAccent, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
