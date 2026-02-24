import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/custom_button.dart';
import '../../../orders/data/models/order_model.dart';
import '../providers/return_provider.dart';


class ReturnCreateScreen extends StatefulWidget {
  final OrderModel order;

  const ReturnCreateScreen({super.key, required this.order});

  @override
  State<ReturnCreateScreen> createState() => _ReturnCreateScreenState();
}

class _ReturnCreateScreenState extends State<ReturnCreateScreen> {
  final _detailsController = TextEditingController();
  final _noteController = TextEditingController();
  final _picker = ImagePicker();

  String _requestType = 'RETURN';
  String _reason = 'DEFECTIVE';
  String _fulfillment = 'PICKUP';
  String _refundMethod = 'ORIGINAL';

  final Map<int, bool> _selected = {};
  final Map<int, int> _qty = {};
  final List<String> _imagePaths = [];

  @override
  void initState() {
    super.initState();
    for (final item in widget.order.items) {
      _selected[item.id] = false;
      _qty[item.id] = 1;
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final images = await _picker.pickMultiImage(imageQuality: 80);
    if (!mounted) return;
    if (images.isEmpty) return;
    setState(() {
      _imagePaths.addAll(images.map((e) => e.path));
    });
  }

  List<Map<String, dynamic>> _buildItemsPayload() {
    final payload = <Map<String, dynamic>>[];
    for (final item in widget.order.items) {
      final selected = _selected[item.id] == true;
      if (!selected) continue;
      final q = (_qty[item.id] ?? 1).clamp(1, item.quantity);
      payload.add({
        'order_item_id': item.id,
        'quantity': q,
        'condition': 'UNOPENED',
      });
    }
    return payload;
  }

  Future<void> _submit() async {
    final items = _buildItemsPayload();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one item to return.')),
      );
      return;
    }

    final provider = context.read<ReturnProvider>();
    final created = await provider.createReturn(
      orderId: widget.order.id,
      requestType: _requestType,
      reason: _reason,
      fulfillment: _fulfillment,
      refundMethodPreference: _refundMethod,
      items: items,
      reasonDetails: _detailsController.text.trim(),
      customerNote: _noteController.text.trim(),
      imagePaths: _imagePaths,
    );

    if (!mounted) return;

    if (created != null && created.isNotEmpty) {
      final label = created.length == 1
          ? 'Return request submitted (${created.first.rmaNumber})'
          : 'Submitted ${created.length} return requests';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(label),
          backgroundColor: AppTheme.success,
        ),
      );

      if (created.length > 1) {
        await showDialog<void>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Return requests created'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: created
                    .map((r) => Text('• ${r.rmaNumber}'))
                    .toList(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      }

      final warning = provider.error;
      if (warning != null && warning.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(warning),
            backgroundColor: AppTheme.warning,
          ),
        );
      }
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Failed to submit return'),
          backgroundColor: AppTheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Return Order #${widget.order.id}')),
      body: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingMd),
        child: ListView(
          children: [
            DropdownButtonFormField<String>(
              value: _requestType,
              decoration: const InputDecoration(labelText: 'Request type'),
              items: const [
                DropdownMenuItem(value: 'RETURN', child: Text('Return')),
                DropdownMenuItem(value: 'REPLACE', child: Text('Replace')),
              ],
              onChanged: (v) => setState(() => _requestType = v ?? 'RETURN'),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            DropdownButtonFormField<String>(
              value: _reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: const [
                DropdownMenuItem(value: 'DEFECTIVE', child: Text('Defective')),
                DropdownMenuItem(value: 'WRONG_ITEM', child: Text('Wrong item')),
                DropdownMenuItem(value: 'NOT_AS_DESCRIBED', child: Text('Not as described')),
                DropdownMenuItem(value: 'DAMAGED', child: Text('Damaged')),
                DropdownMenuItem(value: 'CHANGED_MIND', child: Text('Changed my mind')),
                DropdownMenuItem(value: 'OTHER', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _reason = v ?? 'DEFECTIVE'),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            TextField(
              controller: _detailsController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Details (optional)',
                hintText: 'Tell us what happened...',
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note to vendor (optional)',
                hintText: 'Pickup/drop-off constraints, etc.',
              ),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            DropdownButtonFormField<String>(
              value: _fulfillment,
              decoration: const InputDecoration(labelText: 'Pickup / Drop-off'),
              items: const [
                DropdownMenuItem(value: 'PICKUP', child: Text('Pickup')),
                DropdownMenuItem(value: 'DROPOFF', child: Text('Drop-off')),
              ],
              onChanged: (v) => setState(() => _fulfillment = v ?? 'PICKUP'),
            ),
            const SizedBox(height: AppTheme.spacingMd),
            DropdownButtonFormField<String>(
              value: _refundMethod,
              decoration: const InputDecoration(labelText: 'Refund method'),
              items: const [
                DropdownMenuItem(value: 'ORIGINAL', child: Text('Original method')),
                DropdownMenuItem(value: 'WALLET', child: Text('Wallet credit')),
              ],
              onChanged: (v) => setState(() => _refundMethod = v ?? 'ORIGINAL'),
            ),
            const SizedBox(height: AppTheme.spacingLg),
            const Text(
              'Select items',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'If your order contains items from multiple shops, multiple return requests will be created automatically.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            ...widget.order.items.map((item) {
              final selected = _selected[item.id] == true;
              final q = _qty[item.id] ?? 1;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: selected,
                      onChanged: (v) => setState(() => _selected[item.id] = v ?? false),
                      activeColor: AppTheme.primary,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName ?? 'Product',
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Qty purchased: ${item.quantity}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Row(
                        children: [
                          IconButton(
                            onPressed: q <= 1
                                ? null
                                : () => setState(() => _qty[item.id] = q - 1),
                            icon: const Icon(Icons.remove, size: 18),
                          ),
                          Text('$q'),
                          IconButton(
                            onPressed: q >= item.quantity
                                ? null
                                : () => setState(() => _qty[item.id] = q + 1),
                            icon: const Icon(Icons.add, size: 18),
                          ),
                        ],
                      ),
                  ],
                ),
              );
            }),
            const SizedBox(height: AppTheme.spacingMd),
            OutlinedButton.icon(
              onPressed: _pickImages,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(
                _imagePaths.isEmpty ? 'Add photos' : 'Photos (${_imagePaths.length})',
              ),
            ),
            if (_imagePaths.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: SizedBox(
                  height: 72,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _imagePaths.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final path = _imagePaths[index];
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.file(
                              File(path),
                              width: 72,
                              height: 72,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: InkWell(
                              onTap: () => setState(() => _imagePaths.removeAt(index)),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close, size: 14, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            const SizedBox(height: AppTheme.spacingLg),
            Consumer<ReturnProvider>(
              builder: (context, provider, _) {
                return CustomButton(
                  text: 'Submit',
                  isLoading: provider.isLoading,
                  onPressed: _submit,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
