import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/typography.dart';
import '../../../../core/widgets/primary_button.dart';
import '../../data/models/order_model.dart';
import '../../data/repositories/order_repository.dart';
import 'package:url_launcher/url_launcher.dart';

/// Premium animated order confirmation screen with 3 payment states:
/// - COD: success animation
/// - Online — Pending: "Proceed to Payment" with polling
/// - Online — Paid: success animation
/// - Online — Failed: retry button
class OrderConfirmationScreen extends StatefulWidget {
  final OrderModel order;
  final String paymentMethod;
  final OrderRepository orderRepository;
  final VoidCallback? onViewOrders;

  const OrderConfirmationScreen({
    super.key,
    required this.order,
    required this.paymentMethod,
    required this.orderRepository,
    this.onViewOrders,
  });

  @override
  State<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState extends State<OrderConfirmationScreen> {
  late OrderModel _order;
  Timer? _pollingTimer;
  bool _isInitiatingPayment = false;

  @override
  void initState() {
    super.initState();
    _order = widget.order;

    // Start polling for online payments
    if (widget.paymentMethod == 'ONLINE' && _order.paymentStatus != 'PAID') {
      _startPolling();
    }
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  void _startPolling() {
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (!mounted) return;
      try {
        final updated = await widget.orderRepository.getOrderDetail(_order.id);
        if (mounted) {
          setState(() => _order = updated);
          if (updated.paymentStatus == 'PAID' ||
              updated.paymentStatus == 'REFUNDED') {
            _pollingTimer?.cancel();
          }
        }
      } catch (_) {
        // Silent retry
      }
    });
  }

  Future<void> _launchPayment() async {
    setState(() => _isInitiatingPayment = true);
    try {
      final url = await widget.orderRepository.initiatePayment(_order.id);
      if (mounted) {
        setState(() => _isInitiatingPayment = false);
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        // Restart polling when returning
        _startPolling();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitiatingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to launch payment: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isCOD = widget.paymentMethod == 'COD';
    final isPaid = _order.paymentStatus == 'PAID';
    final isSuccess = isCOD || isPaid;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.lightBg,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xxl),

                // Animated status icon
                _StatusIcon(isSuccess: isSuccess)
                    .animate()
                    .scale(
                      begin: const Offset(0.3, 0.3),
                      end: const Offset(1, 1),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    )
                    .fade(duration: 400.ms),

                const SizedBox(height: AppSpacing.lg),

                // Title
                Text(
                      isSuccess ? 'Order Confirmed!' : 'Payment Pending',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.lightTextPrimary,
                      ),
                    )
                    .animate()
                    .fade(delay: 200.ms, duration: 400.ms)
                    .slideY(begin: 0.2, end: 0),

                const SizedBox(height: AppSpacing.xs),

                Text(
                  'Order #${_order.id}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ).animate().fade(delay: 300.ms, duration: 400.ms),

                const SizedBox(height: AppSpacing.xl),

                // Order details card
                _OrderDetailsCard(order: _order, primaryColor: primaryColor)
                    .animate()
                    .fade(delay: 400.ms, duration: 400.ms)
                    .slideY(begin: 0.1, end: 0),

                const SizedBox(height: AppSpacing.md),

                // Payment status for online
                if (!isCOD) ...[
                  _PaymentStatusCard(
                        paymentStatus: _order.paymentStatus,
                        primaryColor: primaryColor,
                      )
                      .animate()
                      .fade(delay: 500.ms, duration: 400.ms)
                      .slideY(begin: 0.1, end: 0),
                  const SizedBox(height: AppSpacing.md),
                ],

                const SizedBox(height: AppSpacing.lg),

                // Action buttons
                if (!isCOD && !isPaid) ...[
                  PrimaryButton(
                        text: 'Proceed to Payment',
                        isLoading: _isInitiatingPayment,
                        onPressed: _launchPayment,
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .shimmer(
                        duration: 2000.ms,
                        color: Colors.white.withAlpha(50),
                      ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                PrimaryButton(
                  text: 'View Orders',
                  outlined: !isSuccess,
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    widget.onViewOrders?.call();
                  },
                ).animate().fade(delay: 600.ms, duration: 400.ms),

                const SizedBox(height: AppSpacing.sm),

                TextButton(
                  onPressed: () {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: Text(
                    'Continue Shopping',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: primaryColor,
                    ),
                  ),
                ).animate().fade(delay: 700.ms, duration: 400.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusIcon extends StatelessWidget {
  final bool isSuccess;

  const _StatusIcon({required this.isSuccess});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isSuccess
            ? const LinearGradient(
                colors: [AppColors.success, Color(0xFF34D399)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [AppColors.warning, Color(0xFFFBBF24)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: (isSuccess ? AppColors.success : AppColors.warning)
                .withAlpha(64),
            blurRadius: 24,
            spreadRadius: 4,
          ),
        ],
      ),
      child: Icon(
        isSuccess ? Icons.check_rounded : Icons.schedule_rounded,
        color: Colors.white,
        size: 48,
      ),
    );
  }
}

class _OrderDetailsCard extends StatelessWidget {
  final OrderModel order;
  final Color primaryColor;

  const _OrderDetailsCard({required this.order, required this.primaryColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.lightSurface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.lightOutline, width: 0.5),
      ),
      child: Column(
        children: [
          _DetailRow('Order ID', '#${order.id}'),
          _DetailRow(
            'Payment',
            order.paymentMethod == 'COD' ? 'Cash on Delivery' : 'Online',
          ),
          _DetailRow(
            'Subtotal',
            '\$${order.subtotalAmount.toStringAsFixed(2)}',
          ),
          if (order.discountAmount > 0)
            _DetailRow(
              'Discount',
              '-\$${order.discountAmount.toStringAsFixed(2)}',
              valueColor: AppColors.success,
            ),
          const Divider(height: 16),
          _DetailRow(
            'Total',
            '\$${order.totalAmount.toStringAsFixed(2)}',
            isBold: true,
            valueColor: primaryColor,
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _DetailRow(
    this.label,
    this.value, {
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: isBold
                ? AppTextStyles.labelLarge.copyWith(
                    color: AppColors.lightTextPrimary,
                  )
                : AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
          ),
          Text(
            value,
            style: isBold
                ? AppTextStyles.titleMedium.copyWith(
                    color: valueColor ?? AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w700,
                  )
                : AppTextStyles.bodyMedium.copyWith(
                    color: valueColor ?? AppColors.lightTextPrimary,
                    fontWeight: FontWeight.w500,
                  ),
          ),
        ],
      ),
    );
  }
}

class _PaymentStatusCard extends StatelessWidget {
  final String paymentStatus;
  final Color primaryColor;

  const _PaymentStatusCard({
    required this.paymentStatus,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;
    final String statusText;

    switch (paymentStatus) {
      case 'PAID':
        statusColor = AppColors.success;
        statusIcon = Icons.check_circle;
        statusText = 'Payment Successful';
        break;
      case 'REFUNDED':
        statusColor = AppColors.info;
        statusIcon = Icons.replay;
        statusText = 'Payment Refunded';
        break;
      default:
        statusColor = AppColors.warning;
        statusIcon = Icons.schedule;
        statusText = 'Awaiting Payment';
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(15),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: statusColor.withAlpha(64)),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                statusText,
                style: AppTextStyles.labelLarge.copyWith(color: statusColor),
              ),
              if (paymentStatus == 'UNPAID')
                Text(
                  'Complete your payment to confirm the order',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.lightTextSecondary,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
