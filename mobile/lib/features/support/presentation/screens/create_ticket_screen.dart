import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/data/models/order_model.dart';
import '../../../orders/data/repositories/order_repository.dart';
import '../../data/repositories/support_repository.dart';
import 'ticket_chat_screen.dart';


class CreateTicketScreen extends StatefulWidget {
  final String? prefillCategory;
  final String? prefillSubject;
  final int? prefillOrderId;
  final int? prefillSubOrderId;
  final int? prefillReturnRequestId;

  const CreateTicketScreen({
    super.key,
    this.prefillCategory,
    this.prefillSubject,
    this.prefillOrderId,
    this.prefillSubOrderId,
    this.prefillReturnRequestId,
  });

  @override
  State<CreateTicketScreen> createState() => _CreateTicketScreenState();
}

class _CreateTicketScreenState extends State<CreateTicketScreen> {
  final _messageController = TextEditingController();
  final _customSubjectController = TextEditingController();
  final _picker = ImagePicker();

  bool _isSubmitting = false;
  bool _isLoadingOrders = false;

  String _category = 'OTHER';
  String _subjectTemplate = 'Custom';

  int? _orderId;
  int? _subOrderId;

  final List<String> _imagePaths = [];

  static const _categories = <String, String>{
    'ORDER': 'Order',
    'PAYMENT': 'Payment',
    'ACCOUNT': 'Account',
    'TECH': 'Tech',
    'OTHER': 'Other',
  };

  static const _subjectTemplates = <String>[
    'Custom',
    'Issue with an order',
    'Payment problem',
    'Account help',
    'Technical issue',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _category = (widget.prefillCategory ?? 'OTHER').toUpperCase();
    if (!_categories.keys.contains(_category)) _category = 'OTHER';

    _orderId = widget.prefillOrderId;
    _subOrderId = widget.prefillSubOrderId;

    final prefillSubject = widget.prefillSubject?.trim();
    if (prefillSubject != null && prefillSubject.isNotEmpty) {
      _customSubjectController.text = prefillSubject;
      _subjectTemplate = 'Custom';
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _customSubjectController.dispose();
    super.dispose();
  }

  String _resolvedSubject() {
    if (_subjectTemplate != 'Custom') return _subjectTemplate;
    final raw = _customSubjectController.text.trim();
    if (raw.isNotEmpty) return raw;

    if (_orderId != null) return 'Issue with Order #$_orderId';
    return 'Support request';
  }

  Future<void> _pickImages() async {
    final picked = await _picker.pickMultiImage(imageQuality: 80);
    if (!mounted) return;
    if (picked.isEmpty) return;

    setState(() {
      for (final p in picked) {
        if (_imagePaths.length >= 5) break;
        _imagePaths.add(p.path);
      }
    });

    if (_imagePaths.length >= 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Max 5 images.')),
      );
    }
  }

  Future<void> _selectOrder() async {
    final auth = context.read<AuthProvider>();
    if (auth.user?.type != 'CUSTOMER') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order picker is available for customers.')),
      );
      return;
    }

    final repo = context.read<OrderRepository>();
    setState(() => _isLoadingOrders = true);
    List<OrderModel> orders = const [];
    try {
      orders = await repo.getOrderHistory();
    } catch (_) {
      // ignore; handled below
    } finally {
      if (mounted) setState(() => _isLoadingOrders = false);
    }

    if (!mounted) return;
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders found to link.')),
      );
      return;
    }

    final selected = await showModalBottomSheet<_OrderSelection>(
      context: context,
      showDragHandle: true,
      builder: (context) => _OrderPickerSheet(orders: orders),
    );
    if (selected == null || !mounted) return;

    setState(() {
      _orderId = selected.orderId;
      _subOrderId = selected.subOrderId;
    });
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;

    final message = _messageController.text.trim();
    if (message.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Message is required.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final repo = context.read<SupportRepository>();
      final ticket = await repo.createTicket(
        category: _category,
        subject: _resolvedSubject(),
        orderId: _orderId,
        subOrderId: _subOrderId,
        returnRequestId: widget.prefillReturnRequestId,
        message: message,
        imagePaths: _imagePaths,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => TicketChatScreen(ticketId: ticket.id)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final linkedOrderLabel = _orderId == null
        ? 'None'
        : (_subOrderId == null ? '#$_orderId' : '#$_orderId / SubOrder #$_subOrderId');
    final busy = _isSubmitting || _isLoadingOrders;

    return Scaffold(
      appBar: AppBar(title: const Text('New Ticket')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          DropdownButtonFormField<String>(
            value: _category,
            decoration: const InputDecoration(labelText: 'Category'),
            items: _categories.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: (v) => setState(() => _category = v ?? 'OTHER'),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            value: _subjectTemplate,
            decoration: const InputDecoration(labelText: 'Subject'),
            items: _subjectTemplates
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => _subjectTemplate = v ?? 'Custom'),
          ),
          if (_subjectTemplate == 'Custom') ...[
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _customSubjectController,
              decoration: const InputDecoration(
                labelText: 'Custom subject (optional)',
                hintText: 'e.g. Issue with my order',
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Linked order (optional)'),
            subtitle: Text(linkedOrderLabel),
            trailing: _isLoadingOrders
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.chevron_right),
            onTap: busy ? null : _selectOrder,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _messageController,
            maxLines: 5,
            decoration: const InputDecoration(
              labelText: 'Message',
              hintText: 'Describe the issue…',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : _pickImages,
                  icon: const Icon(Icons.photo_library_outlined),
                  label: Text(_imagePaths.isEmpty
                      ? 'Attach images'
                      : 'Images (${_imagePaths.length}/5)'),
                ),
              ),
            ],
          ),
          if (_imagePaths.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _imagePaths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final path = _imagePaths[index];
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Image.file(
                          File(path),
                          width: 84,
                          height: 84,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: InkWell(
                          onTap: () => setState(() => _imagePaths.removeAt(index)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withAlpha((0.55 * 255).round()),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            text: _isSubmitting ? 'Submitting…' : 'Submit',
            onPressed: busy ? null : _submit,
          ),
          const SizedBox(height: 6),
          const Text(
            'Tip: include screenshots and order references for faster help.',
            style: TextStyle(color: AppColors.lightTextSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _OrderSelection {
  final int orderId;
  final int? subOrderId;

  const _OrderSelection({required this.orderId, required this.subOrderId});
}

class _OrderPickerSheet extends StatelessWidget {
  final List<OrderModel> orders;

  const _OrderPickerSheet({required this.orders});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        itemCount: orders.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final o = orders[index];
          return ListTile(
            title: Text('Order #${o.id}'),
            subtitle: Text('${o.status} • ${o.paymentMethod}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              if (o.subOrders.isEmpty) {
                Navigator.pop(context, _OrderSelection(orderId: o.id, subOrderId: null));
                return;
              }
              final res = await showModalBottomSheet<_OrderSelection>(
                context: context,
                showDragHandle: true,
                builder: (context) => _SubOrderPickerSheet(order: o),
              );
              if (context.mounted && res != null) {
                Navigator.pop(context, res);
              }
            },
          );
        },
      ),
    );
  }
}

class _SubOrderPickerSheet extends StatelessWidget {
  final OrderModel order;

  const _SubOrderPickerSheet({required this.order});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.md),
        children: [
          ListTile(
            title: Text('Entire Order #${order.id}'),
            leading: const Icon(Icons.receipt_long_outlined),
            onTap: () => Navigator.pop(
              context,
              _OrderSelection(orderId: order.id, subOrderId: null),
            ),
          ),
          const Divider(height: 1),
          ...order.subOrders.map((s) {
            return ListTile(
              title: Text('SubOrder #${s.id}'),
              subtitle: Text('${s.status} • ${s.vendorStoreName}'),
              leading: const Icon(Icons.storefront_outlined),
              onTap: () => Navigator.pop(
                context,
                _OrderSelection(orderId: order.id, subOrderId: s.id),
              ),
            );
          }),
        ],
      ),
    );
  }
}
