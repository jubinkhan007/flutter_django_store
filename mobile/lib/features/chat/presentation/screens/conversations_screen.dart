import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

class ConversationsScreen extends StatefulWidget {
  final bool isVendorView;

  const ConversationsScreen({super.key, this.isVendorView = false});

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadConversations();
    });
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) {
      final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
      final minute = dt.minute.toString().padLeft(2, '0');
      final period = dt.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return days[dt.weekday - 1];
    } else {
      return '${dt.day}/${dt.month}/${dt.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isVendorView ? 'Customer Messages' : 'Messages'),
        elevation: 0,
      ),
      body: Consumer<ChatProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.conversations.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.errorMessage != null && provider.conversations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.lightTextSecondary),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    ElevatedButton(
                      onPressed: () => provider.loadConversations(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          if (provider.conversations.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => provider.loadConversations(),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 40,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          widget.isVendorView
                              ? 'No customer messages yet'
                              : 'No conversations yet',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.lightTextPrimary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                          child: Text(
                            widget.isVendorView
                              ? 'Inquiries and questions from customers will appear here.'
                              : 'Reach out to sellers from any product page or order details to ask questions.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.lightTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadConversations(),
            child: ListView.separated(
              itemCount: provider.conversations.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
              itemBuilder: (context, index) {
                final conv = provider.conversations[index];
                final displayName = widget.isVendorView ? conv.customerName : conv.vendorName;
                final avatarUrl = widget.isVendorView ? null : conv.vendorLogo;
                final hasUnread = conv.unreadCount > 0;

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.xs,
                  ),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                        backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null
                            ? Text(
                                displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Theme.of(context).primaryColor,
                                ),
                              )
                            : null,
                      ),
                      if (hasUnread)
                        Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppColors.error,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                          ),
                        ),
                    ],
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          displayName,
                          style: TextStyle(
                            fontWeight: hasUnread ? FontWeight.bold : FontWeight.w600,
                            fontSize: 16,
                            color: AppColors.lightTextPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        _formatTimestamp(conv.lastMessageAt),
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread
                              ? Theme.of(context).primaryColor
                              : AppColors.lightTextSecondary,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conv.lastMessagePreview.isNotEmpty
                                  ? conv.lastMessagePreview
                                  : 'Conversation started',
                              style: TextStyle(
                                fontSize: 14,
                                color: hasUnread
                                    ? AppColors.lightTextPrimary
                                    : AppColors.lightTextSecondary,
                                fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasUnread)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(AppRadius.full),
                              ),
                              child: Text(
                                '${conv.unreadCount}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (conv.product != null || conv.order != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.lightSurface,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                conv.product != null
                                    ? Icons.inventory_2_outlined
                                    : Icons.receipt_long_outlined,
                                size: 13,
                                color: AppColors.lightTextSecondary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  conv.product != null
                                      ? conv.product!.name
                                      : 'Order #${conv.order!.orderNumber}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.lightTextSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(conversationId: conv.id),
                      ),
                    );
                  },
                );
              },
            ),
          );
        },
      ),
    );
  }
}
