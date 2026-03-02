import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../orders/data/repositories/order_repository.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';
import '../../../returns/data/repositories/return_repository.dart';
import '../../../returns/presentation/screens/return_detail_screen.dart';
import '../../data/repositories/support_repository.dart';
import '../providers/support_provider.dart';


class TicketChatScreen extends StatefulWidget {
  final int ticketId;

  const TicketChatScreen({super.key, required this.ticketId});

  @override
  State<TicketChatScreen> createState() => _TicketChatScreenState();
}

class _TicketChatScreenState extends State<TicketChatScreen> {
  final _controller = TextEditingController();
  final _picker = ImagePicker();
  final List<String> _imagePaths = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SupportProvider>().openTicket(widget.ticketId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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

  Future<void> _openLinkedOrder(int orderId) async {
    try {
      final repo = context.read<OrderRepository>();
      final order = await repo.getOrderDetail(orderId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => OrderDetailScreen(order: order)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _openLinkedReturn(int returnId) async {
    try {
      final repo = context.read<ReturnRepository>();
      final rr = await repo.getReturnDetail(returnId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ReturnDetailScreen(returnRequest: rr)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _ticketActionMenu(String action, {required int ticketId}) async {
    final auth = context.read<AuthProvider>();
    final myId = auth.user?.id;
    final provider = context.read<SupportProvider>();
    final repo = context.read<SupportRepository>();

    try {
      if (action == 'close') {
        await repo.closeTicket(ticketId);
        await provider.openTicket(ticketId);
        return;
      }
      if (action == 'reopen') {
        await repo.reopenTicket(ticketId);
        await provider.openTicket(ticketId);
        return;
      }
      if (action == 'assign_to_me') {
        if (myId == null) throw Exception('Missing user id');
        await repo.assignTicket(ticketId, assignedToId: myId);
        await provider.openTicket(ticketId);
        return;
      }
      if (action == 'set_status') {
        final selected = await showDialog<String>(
          context: context,
          builder: (context) {
            String status = provider.activeTicket?.status ?? 'OPEN';
            return StatefulBuilder(
              builder: (context, setState) => AlertDialog(
                title: const Text('Set ticket status'),
                content: DropdownButtonFormField<String>(
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'OPEN', child: Text('Open')),
                    DropdownMenuItem(value: 'PENDING_CUSTOMER', child: Text('Pending Customer')),
                    DropdownMenuItem(value: 'PENDING_VENDOR', child: Text('Pending Vendor')),
                    DropdownMenuItem(value: 'PENDING_SUPPORT', child: Text('Pending Support')),
                    DropdownMenuItem(value: 'RESOLVED', child: Text('Resolved')),
                    DropdownMenuItem(value: 'CLOSED', child: Text('Closed')),
                  ],
                  onChanged: (v) => setState(() => status = v ?? 'OPEN'),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, status),
                    child: const Text('OK'),
                  ),
                ],
              ),
            );
          },
        );
        if (selected == null || !mounted) return;
        await repo.setTicketStatus(ticketId, status: selected);
        await provider.openTicket(ticketId);
        return;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final myId = auth.user?.id;
    final myType = auth.user?.type;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ticket'),
        actions: [
          Consumer<SupportProvider>(
            builder: (context, provider, _) {
              final t = provider.activeTicket;
              if (t == null) return const SizedBox.shrink();
              return PopupMenuButton<String>(
                onSelected: (v) => _ticketActionMenu(v, ticketId: t.id),
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String>>[];

                  if (myType == 'ADMIN') {
                    items.add(
                      const PopupMenuItem(
                        value: 'assign_to_me',
                        child: Text('Assign to me'),
                      ),
                    );
                    items.add(
                      const PopupMenuItem(
                        value: 'set_status',
                        child: Text('Set status…'),
                      ),
                    );
                  }

                  if (t.status == 'CLOSED') {
                    items.add(
                      const PopupMenuItem(
                        value: 'reopen',
                        child: Text('Reopen'),
                      ),
                    );
                  } else {
                    items.add(
                      const PopupMenuItem(
                        value: 'close',
                        child: Text('Close'),
                      ),
                    );
                  }
                  return items;
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<SupportProvider>(
        builder: (context, provider, _) {
          final ticket = provider.activeTicket;
          if (provider.isLoading && ticket == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ticket == null) {
            return Center(
              child: Text(provider.error ?? 'Ticket not found'),
            );
          }

          final headerOrder = ticket.orderId != null ? '#${ticket.orderId}' : '—';
          final headerReturn = ticket.returnRequestId != null ? '#${ticket.returnRequestId}' : '—';

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withAlpha((0.15 * 255).round()),
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ticket.ticketNumber,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      ticket.subject,
                      style: const TextStyle(
                        color: AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      children: [
                        _ContextChip(
                          label: 'Order',
                          value: headerOrder,
                          onTap: ticket.orderId == null
                              ? null
                              : () => _openLinkedOrder(ticket.orderId!),
                        ),
                        _ContextChip(
                          label: 'Return',
                          value: headerReturn,
                          onTap: ticket.returnRequestId == null
                              ? null
                              : () => _openLinkedReturn(ticket.returnRequestId!),
                        ),
                        _ContextChip(label: 'Status', value: ticket.status),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.openTicket(ticket.id),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: ticket.messages.length,
                    itemBuilder: (context, index) {
                      final msg = ticket.messages[index];
                      final isMine = myId != null && msg.senderId == myId;
                      final isSystem = msg.kind == 'SYSTEM_EVENT';
                      final bubbleColor = isMine
                          ? Theme.of(context).primaryColor.withAlpha((0.12 * 255).round())
                          : Theme.of(context).cardColor;
                      final align =
                          isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
                      final radius = BorderRadius.only(
                        topLeft: const Radius.circular(AppRadius.md),
                        topRight: const Radius.circular(AppRadius.md),
                        bottomLeft: Radius.circular(isMine ? AppRadius.md : 4),
                        bottomRight: Radius.circular(isMine ? 4 : AppRadius.md),
                      );

                      if (isSystem) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.withAlpha((0.12 * 255).round()),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                msg.text,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.lightTextSecondary,
                                ),
                              ),
                            ),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: align,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: bubbleColor,
                              borderRadius: radius,
                              border: Border.all(
                                color: Colors.grey.withAlpha((0.10 * 255).round()),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (msg.text.trim().isNotEmpty)
                                  Text(
                                    msg.text,
                                    style: const TextStyle(height: 1.3),
                                  ),
                                if (msg.attachments.isNotEmpty) ...[
                                  if (msg.text.trim().isNotEmpty)
                                    const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: msg.attachments.map((a) {
                                      return GestureDetector(
                                        onTap: () {
                                          showDialog<void>(
                                            context: context,
                                            builder: (context) => Dialog(
                                              child: InteractiveViewer(
                                                child: Image.network(a.fileUrl),
                                              ),
                                            ),
                                          );
                                        },
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(10),
                                          child: Image.network(
                                            a.fileUrl,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) =>
                                                const SizedBox.shrink(),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              if (_imagePaths.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    0,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: SizedBox(
                    height: 74,
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
                                width: 74,
                                height: 74,
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
                                    size: 14,
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
                ),
              Padding(
                padding: EdgeInsets.only(
                  left: AppSpacing.md,
                  right: AppSpacing.md,
                  bottom: MediaQuery.of(context).padding.bottom + AppSpacing.md,
                  top: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Attach photo',
                      onPressed: _pickImages,
                      icon: const Icon(Icons.attach_file),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: 'Type a message…',
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send),
                      onPressed: () async {
                        final text = _controller.text;
                        final images = List<String>.from(_imagePaths);
                        _controller.clear();
                        setState(() => _imagePaths.clear());

                        final ok = await provider.sendMessageWithImages(
                          text: text,
                          imagePaths: images,
                        );
                        if (!ok && context.mounted && provider.error != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(provider.error!)),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}


class _ContextChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onTap;

  const _ContextChip({required this.label, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withAlpha((0.08 * 255).round()),
        borderRadius: BorderRadius.circular(999),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
          child: Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              decoration: onTap != null ? TextDecoration.underline : null,
            ),
          ),
        ),
      ),
    );
  }
}
