import 'package:flutter/material.dart';

import '../models/admin_client_request.dart';
import '../services/client_request_service.dart';

class AdminClientRequestsPage extends StatefulWidget {
  const AdminClientRequestsPage({super.key});

  @override
  State<AdminClientRequestsPage> createState() =>
      _AdminClientRequestsPageState();
}

class _AdminClientRequestsPageState extends State<AdminClientRequestsPage> {
  final ClientRequestService _service = ClientRequestService();
  final TextEditingController _searchController = TextEditingController();

  List<AdminClientRequest> _requests = [];

  bool _isLoading = true;
  String? _error;

  String _selectedSource = 'all';
  String _selectedStatus = 'all';

  static const Color _background = Color(0xFF171717);
  static const Color _surface = Color(0xFF222222);
  static const Color _ivory = Color(0xFFF4EFE6);
  static const Color _bronze = Color(0xFFB6A080);
  static const Color _muted = Color(0xFFAAA69F);
  static const Color _border = Color(0xFF38332D);

  final List<String> _statuses = const [
    'new',
    'contacted',
    'in_progress',
    'completed',
    'cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // Data
  // --------------------------------------------------

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final result = await _service.getRequests();

      if (!mounted) return;

      setState(() {
        _requests = result;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(AdminClientRequest request, String status) async {
    try {
      await _service.updateStatus(id: request.id, status: status);

      if (!mounted) return;

      setState(() {
        _requests = _requests.map((item) {
          if (item.id != request.id) return item;

          return _copyRequest(item, status: status, updatedAt: DateTime.now());
        }).toList();
      });

      _showMessage('Request status updated successfully.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Could not update status: $e', isError: true);
    }
  }

  Future<void> _saveAdminNotes(AdminClientRequest request, String notes) async {
    try {
      await _service.updateAdminNotes(id: request.id, notes: notes);

      if (!mounted) return;

      setState(() {
        _requests = _requests.map((item) {
          if (item.id != request.id) return item;

          return _copyRequest(
            item,
            adminNotes: notes,
            updatedAt: DateTime.now(),
          );
        }).toList();
      });

      Navigator.of(context).pop();
      _showMessage('Admin notes saved successfully.');
    } catch (e) {
      if (!mounted) return;
      _showMessage('Could not save notes: $e', isError: true);
    }
  }

  AdminClientRequest _copyRequest(
    AdminClientRequest item, {
    String? status,
    String? adminNotes,
    DateTime? updatedAt,
  }) {
    return AdminClientRequest(
      id: item.id,
      source: item.source,
      name: item.name,
      email: item.email,
      phone: item.phone,
      projectType: item.projectType,
      projectStage: item.projectStage,
      area: item.area,
      location: item.location,
      budget: item.budget,
      services: item.services,
      details: item.details,
      pageUrl: item.pageUrl,
      status: status ?? item.status,
      adminNotes: adminNotes ?? item.adminNotes,
      createdAt: item.createdAt,
      updatedAt: updatedAt ?? item.updatedAt,
      company: item.company,
      country: item.country,
      budgetCurrency: item.budgetCurrency,
      estimatedBudget: item.estimatedBudget,
      preferredContact: item.preferredContact,
      timeline: item.timeline,
      designStyles: item.designStyles,
      overallMood: item.overallMood,
      referenceLinks: item.referenceLinks,
      additionalNotes: item.additionalNotes,
      projectArea: item.projectArea,
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? Colors.redAccent.shade700
            : const Color(0xFF51483D),
      ),
    );
  }

  // --------------------------------------------------
  // Search and filters
  // --------------------------------------------------

  List<AdminClientRequest> get _filteredRequests {
    final query = _searchController.text.trim().toLowerCase();

    return _requests.where((request) {
      final searchableText = [
        request.name,
        request.email,
        request.phone,
        request.company,
        request.location,
        request.country,
        request.projectType,
      ].whereType<String>().join(' ').toLowerCase();

      final matchesSearch = query.isEmpty || searchableText.contains(query);

      final matchesSource =
          _selectedSource == 'all' || request.source == _selectedSource;

      final matchesStatus =
          _selectedStatus == 'all' || request.status == _selectedStatus;

      return matchesSearch && matchesSource && matchesStatus;
    }).toList();
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _selectedSource = 'all';
      _selectedStatus = 'all';
    });
  }

  // --------------------------------------------------
  // Labels and formatting
  // --------------------------------------------------

  String _sourceLabel(String source) {
    switch (source) {
      case 'whatsapp':
        return 'WhatsApp Inquiry';
      case 'form':
        return 'Website Form';
      default:
        return source;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'contacted':
        return 'Contacted';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'New';
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'contacted':
        return const Color(0xFF70A9D1);
      case 'in_progress':
        return const Color(0xFFD6AD65);
      case 'completed':
        return const Color(0xFF76B58A);
      case 'cancelled':
        return const Color(0xFFCC7777);
      default:
        return _bronze;
    }
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}  '
        '${local.hour.toString().padLeft(2, '0')}:'
        '${local.minute.toString().padLeft(2, '0')}';
  }

  // --------------------------------------------------
  // Statistics
  // --------------------------------------------------

  Widget _buildStatistics() {
    final total = _requests.length;
    final newRequests = _requests.where((r) => r.status == 'new').length;
    final inProgress = _requests.where((r) => r.status == 'in_progress').length;
    final completed = _requests.where((r) => r.status == 'completed').length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 650 ? 2 : 4;

        return GridView.count(
          crossAxisCount: columns,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: columns == 2 ? 2.5 : 2.1,
          children: [
            _statCard('Total Requests', total, Icons.inbox_outlined),
            _statCard('New Requests', newRequests, Icons.fiber_new),
            _statCard('In Progress', inProgress, Icons.pending_actions),
            _statCard('Completed', completed, Icons.check_circle_outline),
          ],
        );
      },
    );
  }

  Widget _statCard(String title, int count, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Icon(icon, color: _bronze, size: 25),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count.toString(),
                  style: const TextStyle(
                    color: _ivory,
                    fontSize: 21,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: _muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // Filters UI
  // --------------------------------------------------

  InputDecoration _filterDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: _muted),
      filled: true,
      fillColor: _surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _bronze),
      ),
    );
  }

  Widget _buildFilters() {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(color: _ivory),
          decoration: InputDecoration(
            hintText: 'Search by name, email, phone, company...',
            hintStyle: const TextStyle(color: Color(0xFF77736D)),
            prefixIcon: const Icon(Icons.search, color: _bronze),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.close, color: _muted),
                  )
                : null,
            filled: true,
            fillColor: _surface,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: _bronze),
            ),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final sourceDropdown = DropdownButtonFormField<String>(
              initialValue: _selectedSource,
              isExpanded: true,
              dropdownColor: _surface,
              style: const TextStyle(color: _ivory, fontSize: 13),
              decoration: _filterDecoration('Request Source'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Sources')),
                DropdownMenuItem(value: 'form', child: Text('Website Form')),
                DropdownMenuItem(value: 'whatsapp', child: Text('WhatsApp')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedSource = value);
              },
            );

            final statusDropdown = DropdownButtonFormField<String>(
              initialValue: _selectedStatus,
              isExpanded: true,
              dropdownColor: _surface,
              style: const TextStyle(color: _ivory, fontSize: 13),
              decoration: _filterDecoration('Request Status'),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                DropdownMenuItem(value: 'new', child: Text('New')),
                DropdownMenuItem(value: 'contacted', child: Text('Contacted')),
                DropdownMenuItem(
                  value: 'in_progress',
                  child: Text('In Progress'),
                ),
                DropdownMenuItem(value: 'completed', child: Text('Completed')),
                DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedStatus = value);
              },
            );

            if (constraints.maxWidth < 550) {
              return Column(
                children: [
                  sourceDropdown,
                  const SizedBox(height: 10),
                  statusDropdown,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: sourceDropdown),
                const SizedBox(width: 12),
                Expanded(child: statusDropdown),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '${_filteredRequests.length} request(s) found',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ),
            TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.filter_alt_off, size: 16),
              label: const Text('Reset Filters'),
              style: TextButton.styleFrom(foregroundColor: _bronze),
            ),
          ],
        ),
      ],
    );
  }

  // --------------------------------------------------
  // Request card
  // --------------------------------------------------

  Widget _requestCard(AdminClientRequest request) {
    return Card(
      color: _surface,
      margin: const EdgeInsets.only(bottom: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    (request.name?.trim().isNotEmpty ?? false)
                        ? request.name!
                        : 'Unnamed Inquiry',
                    style: const TextStyle(
                      color: _ivory,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _statusBadge(request.status),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _smallInfo(Icons.source_outlined, _sourceLabel(request.source)),
                _smallInfo(
                  Icons.calendar_today_outlined,
                  _formatDate(request.createdAt),
                ),
              ],
            ),
            const Divider(color: _border, height: 24),
            _info('Phone', request.phone),
            _info('Email', request.email),
            _info('Company', request.company),
            _info('Project Type', request.projectType),
            _info('Project Stage', request.projectStage),
            _info('Area', request.projectArea ?? request.area),
            _info('Location', request.location),
            _info('Budget', _budgetText(request)),
            _info(
              'Services',
              request.services.isEmpty ? null : request.services.join(', '),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 180,
                  child: DropdownButtonFormField<String>(
                    initialValue: _statuses.contains(request.status)
                        ? request.status
                        : 'new',
                    isExpanded: true,
                    dropdownColor: _surface,
                    style: const TextStyle(color: _ivory, fontSize: 12),
                    decoration: const InputDecoration(
                      labelText: 'Change Status',
                      labelStyle: TextStyle(color: _muted, fontSize: 12),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: _bronze),
                      ),
                    ),
                    items: _statuses.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(_statusLabel(status)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null && value != request.status) {
                        _updateStatus(request, value);
                      }
                    },
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showRequestDetails(request),
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  label: const Text('View Details'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _bronze,
                    side: const BorderSide(color: _bronze),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _budgetText(AdminClientRequest request) {
    final amount = request.estimatedBudget ?? request.budget;
    final currency = request.budgetCurrency;

    if (amount == null || amount.trim().isEmpty) return null;
    if (currency == null || currency.trim().isEmpty) return amount;

    return '$amount $currency';
  }

  Widget _statusBadge(String status) {
    final color = _statusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Text(
        _statusLabel(status),
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _smallInfo(IconData icon, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: _bronze),
        const SizedBox(width: 5),
        Text(value, style: const TextStyle(color: _muted, fontSize: 11)),
      ],
    );
  }

  Widget _info(String label, String? value) {
    if (value == null || value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(color: _muted, fontSize: 13),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(
                color: _bronze,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: value),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------
  // Request details dialog
  // --------------------------------------------------

  Future<void> _showRequestDetails(AdminClientRequest request) async {
    final notesController = TextEditingController(
      text: request.adminNotes ?? '',
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: _border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 650),
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Request Details',
                              style: TextStyle(
                                color: _ivory,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            icon: const Icon(Icons.close, color: _muted),
                          ),
                        ],
                      ),
                      const Divider(color: _border),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _detailSection('Contact Information', [
                                _detailRow('Name', request.name),
                                _detailRow('Company', request.company),
                                _detailRow('Email', request.email),
                                _detailRow('Phone', request.phone),
                                _detailRow('Country', request.country),
                                _detailRow(
                                  'Preferred Contact',
                                  request.preferredContact,
                                ),
                              ]),
                              _detailSection('Project Information', [
                                _detailRow('Project Type', request.projectType),
                                _detailRow(
                                  'Project Stage',
                                  request.projectStage,
                                ),
                                _detailRow(
                                  'Project Area',
                                  request.projectArea ?? request.area,
                                ),
                                _detailRow('Location', request.location),
                                _detailRow('Budget', _budgetText(request)),
                                _detailRow(
                                  'Estimated Budget',
                                  request.estimatedBudget,
                                ),
                                _detailRow(
                                  'Budget Currency',
                                  request.budgetCurrency,
                                ),
                                _detailRow('Timeline', request.timeline),
                              ]),
                              _detailSection('Design Preferences', [
                                _detailRow(
                                  'Services',
                                  request.services.isEmpty
                                      ? null
                                      : request.services.join(', '),
                                ),
                                _detailRow(
                                  'Design Styles',
                                  request.designStyles,
                                ),
                                _detailRow('Overall Mood', request.overallMood),
                              ]),
                              _detailSection('Project Description', [
                                _detailRow('Details', request.details),
                                _detailRow(
                                  'Additional Notes',
                                  request.additionalNotes,
                                ),
                              ]),
                              _detailSection('References', [
                                _detailRow(
                                  'Reference Links',
                                  request.referenceLinks,
                                ),
                                _detailRow('Page URL', request.pageUrl),
                              ]),
                              _detailSection('Request Metadata', [
                                _detailRow('Request ID', request.id),
                                _detailRow(
                                  'Source',
                                  _sourceLabel(request.source),
                                ),
                                _detailRow(
                                  'Status',
                                  _statusLabel(request.status),
                                ),
                                _detailRow(
                                  'Created At',
                                  _formatDate(request.createdAt),
                                ),
                                _detailRow(
                                  'Updated At',
                                  _formatDate(request.updatedAt),
                                ),
                              ]),
                              const SizedBox(height: 18),
                              const Text(
                                'Internal Admin Notes',
                                style: TextStyle(
                                  color: _bronze,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: notesController,
                                maxLines: 4,
                                style: const TextStyle(color: _ivory),
                                decoration: InputDecoration(
                                  hintText: 'Write internal notes about this client...',
                                  hintStyle: const TextStyle(
                                    color: Color(0xFF77736D),
                                  ),
                                  filled: true,
                                  fillColor: _background,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: _border,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    borderSide: const BorderSide(
                                      color: _bronze,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text(
                              'Close',
                              style: TextStyle(color: _muted),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () async {
                              setDialogState(() {});
                              await _saveAdminNotes(
                                request,
                                notesController.text.trim(),
                              );
                            },
                            icon: const Icon(Icons.save_outlined),
                            label: const Text('Save Notes'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _bronze,
                              foregroundColor: _background,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );

    notesController.dispose();
  }

  Widget _detailSection(String title, List<Widget> children) {
    final visibleChildren = children
        .where((child) => child is! SizedBox)
        .toList();

    if (visibleChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _bronze,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 8),
          ...visibleChildren,
          const Divider(color: _border, height: 20),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String? value) {
    if (value == null || value.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
          const SizedBox(height: 3),
          SelectableText(
            value,
            style: const TextStyle(color: _ivory, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // Main page
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final filteredRequests = _filteredRequests;

    return Scaffold(
      backgroundColor: _background,
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Client Requests',
                        style: TextStyle(
                          color: _ivory,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        'Manage and track inquiries received from your website.',
                        style: TextStyle(color: _muted, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _loadRequests,
                  tooltip: 'Refresh',
                  icon: const Icon(Icons.refresh, color: _bronze),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (!_isLoading && _error == null) ...[
              _buildStatistics(),
              const SizedBox(height: 20),
              _buildFilters(),
              const SizedBox(height: 12),
            ],
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: _bronze),
                    )
                  : _error != null
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.redAccent,
                            size: 38,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: const TextStyle(color: _muted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton(
                            onPressed: _loadRequests,
                            child: const Text('Try Again'),
                          ),
                        ],
                      ),
                    )
                  : filteredRequests.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.inbox_outlined,
                            color: _bronze,
                            size: 42,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _requests.isEmpty
                                ? 'No client requests yet.'
                                : 'No requests match your filters.',
                            style: const TextStyle(color: _muted, fontSize: 15),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      color: _bronze,
                      onRefresh: _loadRequests,
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: filteredRequests.length,
                        itemBuilder: (context, index) {
                          return _requestCard(filteredRequests[index]);
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
