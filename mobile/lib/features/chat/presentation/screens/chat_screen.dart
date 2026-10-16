import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../providers/chat_provider.dart';
import '../../data/models/chat_message_model.dart';
import '../../../products/domain/repositories/product_repository.dart';
import '../../../products/presentation/screens/product_detail_screen.dart';
import '../../../orders/data/repositories/order_repository.dart';
import '../../../orders/presentation/screens/order_detail_screen.dart';

class ChatScreen extends StatefulWidget {
  final int? conversationId;
  final int? vendorId;
  final String? vendorName;
  final int? productId;
  final int? orderId;
  final String? initialMessage;

  const ChatScreen({
    super.key,
    this.conversationId,
    this.vendorId,
    this.vendorName,
    this.productId,
    this.orderId,
    this.initialMessage,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();
  String? _selectedImagePath;

  @override
  void initState() {
    super.initState();
    if (widget.initialMessage != null && widget.initialMessage!.isNotEmpty) {
      _textController.text = widget.initialMessage!;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ChatProvider>();
      if (widget.conversationId != null) {
        provider.openConversation(widget.conversationId!);
      } else if (widget.vendorId != null) {
        provider.startConversationWithVendor(
          vendorId: widget.vendorId!,
          productId: widget.productId,
          orderId: widget.orderId,
          message: widget.initialMessage,
        );
      }
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    // Stop polling
    context.read<ChatProvider>().closeConversation();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickImage() async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (file != null) {
      setState(() {
        _selectedImagePath = file.path;
      });
    }
  }

  Future<void> _handleSend() async {
    final text = _textController.text.trim();
    final imagePath = _selectedImagePath;

    if (text.isEmpty && imagePath == null) return;

    _textController.clear();
    setState(() {
      _selectedImagePath = null;
    });

    final success = await context.read<ChatProvider>().sendMessage(
      text,
      imagePath: imagePath,
    );

    if (success) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }
  }

  Future<void> _navigateToProduct(int productId) async {
    try {
      final repo = context.read<ProductRepository>();
      final product = await repo.getProductDetail(productId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(product: product),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load product: $e')),
      );
    }
  }

  Future<void> _navigateToOrder(int orderId) async {
    try {
      final repo = context.read<OrderRepository>();
      final order = await repo.getOrderDetail(orderId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OrderDetailScreen(order: order),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not load order: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (context, provider, _) {
        final conv = provider.activeConversation;
        final title = conv != null
            ? conv.vendorName
            : (widget.vendorName ?? 'Chat');
        final logo = conv?.vendorLogo;

        return Scaffold(
          appBar: AppBar(
            elevation: 1,
            titleSpacing: 0,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  backgroundImage: logo != null ? NetworkImage(logo) : null,
                  child: logo == null
                      ? Text(
                          title.isNotEmpty ? title[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Theme.of(context).primaryColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Text(
                        'Typically replies in a few minutes',
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.lightTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          body: Column(
            children: [
              // Pinned Context Header (Product or Order)
              if (conv?.product != null) _buildProductContextBanner(conv!.product!),
              if (conv?.order != null && conv?.product == null)
                _buildOrderContextBanner(conv!.order!),

              // Messages List
              Expanded(
                child: provider.isLoading && (conv == null || conv.messages.isEmpty)
                    ? const Center(child: CircularProgressIndicator())
                    : _buildMessageList(conv?.messages ?? []),
              ),

              // Image Attachment Preview bar (if selected)
              if (_selectedImagePath != null) _buildAttachmentPreviewBar(),

              // Bottom Input Bar
              _buildInputBar(provider.isSending),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductContextBanner(dynamic product) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: product.imageUrl != null
                ? Image.network(
                    product.imageUrl!,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  )
                : Container(
                    width: 44,
                    height: 44,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.image, size: 22, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightTextPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '৳${product.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.lightPrimary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _navigateToProduct(product.id),
            child: const Text('View Item', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderContextBanner(dynamic order) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 24,
              color: Theme.of(context).primaryColor,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order #${order.orderNumber}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.lightTextPrimary,
                  ),
                ),
                Text(
                  'Status: ${order.status} • ৳${order.totalAmount.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _navigateToOrder(order.id),
            child: const Text('View Order', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(List<ChatMessageModel> messages) {
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_outlined,
                size: 48,
                color: Colors.grey.shade300,
              ),
              const SizedBox(height: AppSpacing.sm),
              const Text(
                'Say hello to start the conversation!',
                style: TextStyle(color: AppColors.lightTextSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        return _buildMessageBubble(msg);
      },
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg) {
    final isMe = msg.isMe;
    final timeStr =
        '${msg.createdAt.hour % 12 == 0 ? 12 : msg.createdAt.hour % 12}:${msg.createdAt.minute.toString().padLeft(2, '0')} ${msg.createdAt.hour >= 12 ? 'PM' : 'AM'}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Text(
                msg.senderName.isNotEmpty ? msg.senderName[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? Theme.of(context).primaryColor
                    : AppColors.lightSurface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(AppRadius.md),
                  topRight: const Radius.circular(AppRadius.md),
                  bottomLeft: Radius.circular(isMe ? AppRadius.md : 2),
                  bottomRight: Radius.circular(isMe ? 2 : AppRadius.md),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment:
                    isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe && msg.senderType == 'VENDOR')
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        msg.senderName,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  if (msg.imageUrl != null) ...[
                    GestureDetector(
                      onTap: () => _showImageDialog(msg.imageUrl!),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: Image.network(
                          msg.imageUrl!,
                          width: 200,
                          fit: BoxFit.cover,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              width: 200,
                              height: 140,
                              color: Colors.grey.shade200,
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    if (msg.text.isNotEmpty) const SizedBox(height: 6),
                  ],
                  if (msg.text.isNotEmpty)
                    Text(
                      msg.text,
                      style: TextStyle(
                        fontSize: 14,
                        color: isMe ? Colors.white : AppColors.lightTextPrimary,
                        height: 1.3,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 10,
                          color: isMe
                              ? Colors.white.withValues(alpha: 0.7)
                              : AppColors.lightTextSecondary,
                        ),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        Icon(
                          msg.isRead ? Icons.done_all : Icons.done,
                          size: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Image.network(url, fit: BoxFit.contain),
            ),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreviewBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.file(
              File(_selectedImagePath!),
              width: 50,
              height: 50,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Image attached',
              style: TextStyle(fontSize: 13, color: AppColors.lightTextSecondary),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.grey, size: 20),
            onPressed: () => setState(() => _selectedImagePath = null),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(bool isSending) {
    return Container(
      padding: EdgeInsets.only(
        left: 8,
        right: 8,
        top: 8,
        bottom: MediaQuery.of(context).padding.bottom + 8,
      ),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, -1),
            blurRadius: 4,
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            color: Theme.of(context).primaryColor,
            onPressed: isSending ? null : _pickImage,
          ),
          Expanded(
            child: TextField(
              controller: _textController,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Type a message...',
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 6),
          isSending
              ? const SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              : IconButton(
                  icon: const Icon(Icons.send_rounded),
                  color: Theme.of(context).primaryColor,
                  onPressed: _handleSend,
                ),
        ],
      ),
    );
  }
}
