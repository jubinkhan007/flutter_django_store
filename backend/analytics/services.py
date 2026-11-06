from __future__ import annotations

from datetime import timedelta
from decimal import Decimal
from typing import Any, Dict, List

from django.db.models import Avg, Count, F, Q, Sum
from django.utils import timezone


class MarketplaceAnalyticsService:
    """
    Centralized analytics and operational metrics service for the marketplace admin console.
    Computes GMV, platform commission, top vendors, refund rates, loyalty liabilities,
    and Chart.js time-series structures.
    """

    @classmethod
    def get_marketplace_kpis(cls, days: int = 30) -> Dict[str, Any]:
        from orders.models import Order, SubOrder, OrderItem
        from vendors.models import Vendor, SettlementRecord, PayoutRequest
        from returns.models import ReturnRequest
        from loyalty.models import LoyaltyAccount, LoyaltyTransaction
        from users.models import User

        now = timezone.now()
        today = now.date()
        period_start = now - timedelta(days=days)
        prev_period_start = period_start - timedelta(days=days)

        valid_statuses = [Order.Status.PAID, Order.Status.SHIPPED, Order.Status.DELIVERED]

        # -------------------------------------------------------------
        # 1. GMV & Orders Volume
        # -------------------------------------------------------------
        period_orders = Order.objects.filter(
            created_at__gte=period_start,
            status__in=valid_statuses,
        )
        period_gmv = period_orders.aggregate(total=Sum('total_amount'))['total'] or Decimal('0.00')
        period_order_count = period_orders.count()

        prev_orders = Order.objects.filter(
            created_at__gte=prev_period_start,
            created_at__lt=period_start,
            status__in=valid_statuses,
        )
        prev_gmv = prev_orders.aggregate(total=Sum('total_amount'))['total'] or Decimal('0.00')

        if prev_gmv > Decimal('0.00'):
            gmv_growth_pct = float(round(((period_gmv - prev_gmv) / prev_gmv) * 100, 1))
        elif period_gmv > Decimal('0.00'):
            gmv_growth_pct = 100.0
        else:
            gmv_growth_pct = 0.0

        today_orders = Order.objects.filter(created_at__date=today)
        today_gmv = today_orders.filter(status__in=valid_statuses).aggregate(
            total=Sum('total_amount')
        )['total'] or Decimal('0.00')
        today_order_count = today_orders.count()

        all_time_gmv = Order.objects.filter(
            status__in=valid_statuses
        ).aggregate(total=Sum('total_amount'))['total'] or Decimal('0.00')

        aov = (
            float(round(period_gmv / period_order_count, 2))
            if period_order_count > 0
            else 0.0
        )

        # -------------------------------------------------------------
        # 2. Marketplace Platform Commission Revenue
        # -------------------------------------------------------------
        settlements_period = SettlementRecord.objects.filter(created_at__gte=period_start)
        commission_period = (
            settlements_period.aggregate(total=Sum('platform_fee'))['total'] or Decimal('0.00')
        )
        commission_released = (
            settlements_period.filter(status=SettlementRecord.Status.RELEASED).aggregate(
                total=Sum('platform_fee')
            )['total']
            or Decimal('0.00')
        )
        commission_pending = (
            settlements_period.filter(status=SettlementRecord.Status.PENDING).aggregate(
                total=Sum('platform_fee')
            )['total']
            or Decimal('0.00')
        )
        commission_all_time = (
            SettlementRecord.objects.aggregate(total=Sum('platform_fee'))['total']
            or Decimal('0.00')
        )

        # Fallback if no settlements recorded yet: estimate 10% platform commission on GMV
        if commission_all_time == Decimal('0.00') and all_time_gmv > Decimal('0.00'):
            estimated_commission_period = (period_gmv * Decimal('0.10')).quantize(Decimal('0.01'))
            commission_period = estimated_commission_period

        # -------------------------------------------------------------
        # 3. Top Performing Vendors
        # -------------------------------------------------------------
        top_vendors = cls._compute_top_vendors(period_start=period_start, limit=5)

        # -------------------------------------------------------------
        # 4. Refund & Return Rates (RMA)
        # -------------------------------------------------------------
        total_all_orders_period = Order.objects.filter(created_at__gte=period_start).count()
        refunded_orders_count = Order.objects.filter(
            created_at__gte=period_start,
            payment_status=Order.PaymentStatus.REFUNDED,
        ).count()
        canceled_orders_count = Order.objects.filter(
            created_at__gte=period_start,
            status=Order.Status.CANCELED,
        ).count()

        total_returns_period = ReturnRequest.objects.filter(created_at__gte=period_start)
        rma_count = total_returns_period.count()
        rma_refunded_count = total_returns_period.filter(
            status=ReturnRequest.Status.REFUNDED
        ).count()
        rma_pending_count = total_returns_period.filter(
            status__in=[ReturnRequest.Status.SUBMITTED, ReturnRequest.Status.VENDOR_APPROVED, ReturnRequest.Status.REFUND_PENDING]
        ).count()

        refund_rate_pct = (
            float(round((refunded_orders_count / total_all_orders_period) * 100, 2))
            if total_all_orders_period > 0
            else 0.0
        )
        rma_rate_pct = (
            float(round((rma_count / total_all_orders_period) * 100, 2))
            if total_all_orders_period > 0
            else 0.0
        )

        # Total refunded monetary amount in period
        refunded_order_sum = Order.objects.filter(
            created_at__gte=period_start,
            payment_status=Order.PaymentStatus.REFUNDED,
        ).aggregate(total=Sum('total_amount'))['total'] or Decimal('0.00')

        # Return reasons breakdown
        reason_counts = (
            total_returns_period.values('reason')
            .annotate(count=Count('id'))
            .order_by('-count')
        )
        reason_breakdown = {item['reason']: item['count'] for item in reason_counts}

        # -------------------------------------------------------------
        # 5. Customer Loyalty Points Liability & Wallet Exposure
        # -------------------------------------------------------------
        loyalty_accounts = LoyaltyAccount.objects.all()
        total_points_balance = loyalty_accounts.aggregate(
            total=Sum('points_balance')
        )['total'] or 0
        lifetime_points_earned = loyalty_accounts.aggregate(
            total=Sum('lifetime_points_earned')
        )['total'] or 0
        lifetime_points_redeemed = loyalty_accounts.aggregate(
            total=Sum('lifetime_points_redeemed')
        )['total'] or 0

        # Points conversion: 10 points = 1.00 BDT
        points_liability_bdt = (Decimal(total_points_balance) / Decimal(10)).quantize(Decimal('0.01'))
        points_redeemed_bdt = (Decimal(lifetime_points_redeemed) / Decimal(10)).quantize(Decimal('0.01'))

        # Customer wallet liabilities
        customer_wallet_liability = (
            User.objects.filter(type=User.Types.CUSTOMER).aggregate(
                total=Sum('wallet_balance')
            )['total']
            or Decimal('0.00')
        )
        total_customer_liability = points_liability_bdt + customer_wallet_liability

        # -------------------------------------------------------------
        # 6. Time-Series Trends (Daily GMV, Orders & Commission)
        # -------------------------------------------------------------
        trends = cls._compute_daily_trends(days=min(days, 30))

        # -------------------------------------------------------------
        # 7. Chart Datasets for Chart.js
        # -------------------------------------------------------------
        # Chart 1: Daily GMV & Commission Trends
        chart_gmv_trends = {
            'labels': trends['labels'],
            'datasets': [
                {
                    'label': 'GMV (৳)',
                    'data': trends['gmv'],
                    'borderColor': '#0284c7',
                    'backgroundColor': 'rgba(2, 132, 199, 0.1)',
                    'fill': True,
                    'tension': 0.3,
                },
                {
                    'label': 'Platform Commission (৳)',
                    'data': trends['commission'],
                    'borderColor': '#10b981',
                    'backgroundColor': 'rgba(16, 185, 129, 0.1)',
                    'fill': True,
                    'tension': 0.3,
                },
            ],
        }

        # Chart 2: Top Vendors by GMV
        vendor_chart_labels = [v['store_name'] for v in top_vendors]
        vendor_chart_data = [float(v['gmv']) for v in top_vendors]
        chart_top_vendors = {
            'labels': vendor_chart_labels if vendor_chart_labels else ['No vendor data'],
            'datasets': [
                {
                    'label': 'Vendor GMV (৳)',
                    'data': vendor_chart_data if vendor_chart_data else [0],
                    'backgroundColor': ['#0ea5e9', '#6366f1', '#8b5cf6', '#ec4899', '#f59e0b'],
                    'borderRadius': 4,
                }
            ],
        }

        # Chart 3: Order Status Distribution
        order_status_counts = (
            Order.objects.filter(created_at__gte=period_start)
            .values('status')
            .annotate(count=Count('id'))
        )
        status_map = {item['status']: item['count'] for item in order_status_counts}
        chart_order_status = {
            'labels': ['PENDING', 'PAID', 'SHIPPED', 'DELIVERED', 'CANCELED'],
            'datasets': [
                {
                    'data': [
                        status_map.get('PENDING', 0),
                        status_map.get('PAID', 0),
                        status_map.get('SHIPPED', 0),
                        status_map.get('DELIVERED', 0),
                        status_map.get('CANCELED', 0),
                    ],
                    'backgroundColor': ['#f59e0b', '#3b82f6', '#8b5cf6', '#10b981', '#ef4444'],
                }
            ],
        }

        # Chart 4: Return Reasons Breakdown
        reason_labels = list(reason_breakdown.keys()) if reason_breakdown else ['No returns']
        reason_values = list(reason_breakdown.values()) if reason_breakdown else [0]
        chart_return_reasons = {
            'labels': reason_labels,
            'datasets': [
                {
                    'label': 'RMA Requests by Reason',
                    'data': reason_values,
                    'backgroundColor': ['#ef4444', '#f97316', '#f59e0b', '#eab308', '#84cc16', '#64748b'],
                }
            ],
        }

        return {
            'days': days,
            'gmv': {
                'period_total': float(period_gmv),
                'period_total_display': f"৳{float(period_gmv):,.2f}",
                'today': float(today_gmv),
                'today_display': f"৳{float(today_gmv):,.2f}",
                'all_time': float(all_time_gmv),
                'all_time_display': f"৳{float(all_time_gmv):,.2f}",
                'growth_pct': gmv_growth_pct,
                'aov': aov,
                'aov_display': f"৳{aov:,.2f}",
                'orders_count': period_order_count,
                'orders_today': today_order_count,
            },
            'commission': {
                'period_total': float(commission_period),
                'period_total_display': f"৳{float(commission_period):,.2f}",
                'released': float(commission_released),
                'pending': float(commission_pending),
                'all_time': float(commission_all_time),
                'all_time_display': f"৳{float(commission_all_time):,.2f}",
            },
            'top_vendors': top_vendors,
            'refunds': {
                'total_orders': total_all_orders_period,
                'refunded_orders_count': refunded_orders_count,
                'canceled_orders_count': canceled_orders_count,
                'refund_rate_pct': refund_rate_pct,
                'rma_count': rma_count,
                'rma_refunded_count': rma_refunded_count,
                'rma_pending_count': rma_pending_count,
                'rma_rate_pct': rma_rate_pct,
                'refunded_amount': float(refunded_order_sum),
                'refunded_amount_display': f"৳{float(refunded_order_sum):,.2f}",
                'reasons': reason_breakdown,
            },
            'loyalty_liabilities': {
                'total_points_balance': total_points_balance,
                'points_liability_bdt': float(points_liability_bdt),
                'points_liability_display': f"৳{float(points_liability_bdt):,.2f}",
                'lifetime_earned': lifetime_points_earned,
                'lifetime_redeemed': lifetime_points_redeemed,
                'lifetime_discount_bdt': float(points_redeemed_bdt),
                'wallet_liability_bdt': float(customer_wallet_liability),
                'wallet_liability_display': f"৳{float(customer_wallet_liability):,.2f}",
                'total_liability_bdt': float(total_customer_liability),
                'total_liability_display': f"৳{float(total_customer_liability):,.2f}",
            },
            'charts': {
                'gmv_trends': chart_gmv_trends,
                'top_vendors': chart_top_vendors,
                'order_status': chart_order_status,
                'return_reasons': chart_return_reasons,
            },
        }

    @classmethod
    def _compute_top_vendors(cls, period_start, limit: int = 5) -> List[Dict[str, Any]]:
        from vendors.models import Vendor, SettlementRecord
        from orders.models import SubOrder, Order

        valid_statuses = [Order.Status.PAID, Order.Status.SHIPPED, Order.Status.DELIVERED]
        vendors = Vendor.objects.filter(is_approved=True)
        results = []

        for vendor in vendors:
            suborders = SubOrder.objects.filter(
                vendor=vendor,
                created_at__gte=period_start,
                status__in=valid_statuses,
            )
            suborder_count = suborders.count()

            settlements = SettlementRecord.objects.filter(
                vendor=vendor,
                created_at__gte=period_start,
            )
            gmv = settlements.aggregate(total=Sum('gross_amount'))['total'] or Decimal('0.00')
            commission = settlements.aggregate(total=Sum('platform_fee'))['total'] or Decimal('0.00')

            # Fallback if no settlements recorded yet: compute from suborder items
            if gmv == Decimal('0.00') and suborder_count > 0:
                from orders.models import OrderItem
                items_total = (
                    OrderItem.objects.filter(sub_order__in=suborders)
                    .annotate(line_total=F('unit_price') * F('quantity') + F('tax') - F('discount'))
                    .aggregate(total=Sum('line_total'))['total']
                    or Decimal('0.00')
                )
                gmv = items_total
                commission = (gmv * Decimal('0.10')).quantize(Decimal('0.01'))

            if suborder_count > 0 or gmv > Decimal('0.00'):
                results.append({
                    'id': vendor.id,
                    'store_name': vendor.store_name,
                    'orders_count': suborder_count,
                    'gmv': float(gmv),
                    'gmv_display': f"৳{float(gmv):,.2f}",
                    'commission': float(commission),
                    'commission_display': f"৳{float(commission):,.2f}",
                    'available_balance': float(vendor.available_balance),
                    'rating': float(vendor.avg_rating),
                })

        # Sort descending by GMV
        results.sort(key=lambda x: x['gmv'], reverse=True)
        return results[:limit]

    @classmethod
    def _compute_daily_trends(cls, days: int = 14) -> Dict[str, List[Any]]:
        from orders.models import Order
        from vendors.models import SettlementRecord

        now = timezone.now()
        today = now.date()
        valid_statuses = [Order.Status.PAID, Order.Status.SHIPPED, Order.Status.DELIVERED]

        labels = []
        gmv_data = []
        orders_data = []
        commission_data = []

        for i in range(days - 1, -1, -1):
            d = today - timedelta(days=i)
            labels.append(d.strftime('%b %d'))

            day_orders = Order.objects.filter(created_at__date=d)
            day_gmv = day_orders.filter(status__in=valid_statuses).aggregate(
                total=Sum('total_amount')
            )['total'] or Decimal('0.00')
            day_count = day_orders.filter(status__in=valid_statuses).count()

            day_commission = SettlementRecord.objects.filter(
                created_at__date=d
            ).aggregate(total=Sum('platform_fee'))['total'] or Decimal('0.00')

            if day_commission == Decimal('0.00') and day_gmv > Decimal('0.00'):
                day_commission = (day_gmv * Decimal('0.10')).quantize(Decimal('0.01'))

            gmv_data.append(float(day_gmv))
            orders_data.append(day_count)
            commission_data.append(float(day_commission))

        return {
            'labels': labels,
            'gmv': gmv_data,
            'orders': orders_data,
            'commission': commission_data,
        }
