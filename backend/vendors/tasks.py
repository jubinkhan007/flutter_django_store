import csv
from decimal import Decimal
import pandas as pd
from celery import shared_task
from django.db import transaction
from django.core.files.storage import default_storage
from .models import BulkJob, AuditLog, VendorPerformanceDaily, Vendor
from products.models import Product, ProductVariant
from orders.models import SubOrder, OrderItem
from django.utils import timezone
from django.db.models import Sum, F, DecimalField, ExpressionWrapper
from datetime import timedelta
from .models import SettlementRecord
from .financial_service import FinancialService

@shared_task
def process_bulk_job_task(job_id):
    try:
        job = BulkJob.objects.get(id=job_id)
    except BulkJob.DoesNotExist:
        return

    job.status = BulkJob.Status.PROCESSING
    job.save(update_fields=['status'])

    report = {"processed": 0, "success": 0, "errors": []}
    
    try:
        file_path = job.file.path
        
        # Read with pandas for better excel/csv support
        if file_path.endswith('.csv'):
            df = pd.read_csv(file_path)
        else:
            df = pd.read_excel(file_path)
            
        # fill nan with empty string
        df = df.fillna('')
            
        for row_index, row in df.iterrows():
            row_dict = row.to_dict()
            report["processed"] += 1
            try:
                sku = row_dict.get('sku')
                if not sku:
                    raise ValueError("SKU is required")
                sku = str(sku).strip()
                    
                if job.job_type == BulkJob.JobType.PRICE_UPDATE:
                    price = row_dict.get('price')
                    if price is None or price == '':
                        raise ValueError("price column missing")
                    
                    price = Decimal(str(price))
                    with transaction.atomic():
                        variant = ProductVariant.objects.select_for_update().get(sku=sku, product__vendor=job.vendor)
                        old_price = variant.price_override
                        variant.price_override = price
                        variant.save()
                        
                        AuditLog.objects.create(
                            vendor=job.vendor,
                            action='BULK_PRICE_UPDATE',
                            details=f"Variant {sku} price changed from {old_price} to {price}"
                        )
                        
                elif job.job_type == BulkJob.JobType.STOCK_UPDATE:
                    stock = row_dict.get('stock')
                    if stock is None or stock == '':
                        raise ValueError("stock column missing")
                        
                    stock = int(float(str(stock)))
                    with transaction.atomic():
                        variant = ProductVariant.objects.select_for_update().get(sku=sku, product__vendor=job.vendor)
                        old_stock = variant.stock_on_hand
                        variant.stock_on_hand = stock
                        variant.save()
                        
                        AuditLog.objects.create(
                            vendor=job.vendor,
                            action='BULK_STOCK_UPDATE',
                            details=f"Variant {sku} stock changed from {old_stock} to {stock}"
                        )
                        
                elif job.job_type == BulkJob.JobType.PRODUCT_UPLOAD:
                    name = row_dict.get('name')
                    description = row_dict.get('description', '')
                    price = row_dict.get('price')
                    category_id = row_dict.get('category_id')
                    
                    if not name:
                        raise ValueError("name is required for product upload")
                    if not price:
                        raise ValueError("price is required")
                    
                    price = Decimal(str(price))
                    stock = int(float(str(row_dict.get('stock', 0) or 0)))
                    
                    with transaction.atomic():
                        product, created = Product.objects.get_or_create(
                            vendor=job.vendor,
                            name=str(name).strip(),
                            defaults={
                                'description': str(description),
                                'price': price,
                                'stock_quantity': stock,
                                'category_id': category_id if category_id else None
                            }
                        )
                        
                        # Create variant if SKU provided
                        if sku:
                            variant, v_created = ProductVariant.objects.get_or_create(
                                product=product,
                                sku=sku,
                                defaults={
                                    'stock_on_hand': stock,
                                    'price_override': price
                                }
                            )
                            if not v_created:
                                variant.stock_on_hand = stock
                                variant.price_override = price
                                variant.save()
                    
                elif job.job_type == BulkJob.JobType.VARIANT_UPLOAD:
                    product_id = row_dict.get('product_id')
                    if not product_id:
                        raise ValueError("product_id is required")
                        
                    price = Decimal(str(row_dict.get('price', 0) or 0))
                    stock = int(float(str(row_dict.get('stock', 0) or 0)))
                    
                    with transaction.atomic():
                        product = Product.objects.get(id=product_id, vendor=job.vendor)
                        
                        variant, v_created = ProductVariant.objects.get_or_create(
                            product=product,
                            sku=sku,
                            defaults={
                                'stock_on_hand': stock,
                                'price_override': price
                            }
                        )
                        if not v_created:
                            variant.stock_on_hand = stock
                            variant.price_override = price
                            variant.save()
                            
                elif job.job_type == BulkJob.JobType.SCHEDULED_PROMOTION:
                    sale_price = Decimal(str(row_dict.get('sale_price', 0) or 0))
                    priority = int(float(str(row_dict.get('priority', 0) or 0)))
                    
                    starts_at_str = str(row_dict.get('starts_at', '')).strip()
                    ends_at_str = str(row_dict.get('ends_at', '')).strip()
                    
                    if not starts_at_str or not ends_at_str or starts_at_str == 'nan' or ends_at_str == 'nan':
                        raise ValueError("starts_at and ends_at are required")
                        
                    from django.utils.dateparse import parse_datetime
                    starts_at = parse_datetime(starts_at_str)
                    ends_at = parse_datetime(ends_at_str)
                    
                    if not starts_at or not ends_at:
                        raise ValueError("Invalid datetime format. Use ISO 8601 (e.g. 2024-01-01T10:00:00Z)")
                        
                    from products.models import ScheduledPriceRule
                    with transaction.atomic():
                        variant = ProductVariant.objects.get(sku=sku, product__vendor=job.vendor)
                        
                        ScheduledPriceRule.objects.create(
                            product=variant.product,
                            variant=variant,
                            sale_price=sale_price,
                            starts_at=starts_at,
                            ends_at=ends_at,
                            priority=priority
                        )
                        
                report["success"] += 1

            except ProductVariant.DoesNotExist:
                report["errors"].append({"row": row_index + 2, "error": f"Variant with SKU {sku} not found."})
            except Exception as e:
                report["errors"].append({"row": row_index + 2, "error": str(e)})

    except Exception as e:
        job.status = BulkJob.Status.FAILED
        report["critical_error"] = str(e)
        job.result_report = report
        job.save()
        return

    if report["errors"]:
        job.status = BulkJob.Status.PARTIAL_SUCCESS if report["success"] > 0 else BulkJob.Status.FAILED
    else:
        job.status = BulkJob.Status.COMPLETED

    job.result_report = report
    job.save()

@shared_task
def compute_daily_vendor_metrics():
    """
    Computes daily performance metrics for all vendors for the PREVIOUS day.
    Runs once a day at midnight.
    """
    yesterday = timezone.now().date() - timedelta(days=1)
    start_of_day = timezone.make_aware(timezone.datetime.combine(yesterday, timezone.datetime.min.time()))
    end_of_day = start_of_day + timedelta(days=1)

    for vendor in Vendor.objects.all():
        suborders = SubOrder.objects.filter(
            vendor=vendor,
            created_at__gte=start_of_day,
            created_at__lt=end_of_day
        )
        
        orders_count = suborders.count()
        if orders_count == 0:
            continue
            
        canceled_count = suborders.filter(status='CANCELED').count()
        shipped_count = suborders.filter(status__in=['SHIPPED', 'DELIVERED']).count()
        
        late_shipments = suborders.filter(
            status__in=['SHIPPED', 'DELIVERED'],
            shipped_at__gt=F('ship_by_date')
        ).count()
        
        # Handling time: accepted_at -> shipped_at
        handling_qs = suborders.exclude(accepted_at__isnull=True).exclude(shipped_at__isnull=True)
        total_handling_seconds = 0
        handling_count = 0
        for so in handling_qs:
            diff = (so.shipped_at - so.accepted_at).total_seconds()
            if diff > 0:
                total_handling_seconds += diff
                handling_count += 1
                
        avg_handling_seconds = total_handling_seconds / handling_count if handling_count > 0 else 0
        
        revenue_expr = ExpressionWrapper(F('unit_price') * F('quantity'), output_field=DecimalField())
        revenue = OrderItem.objects.filter(
            sub_order__vendor=vendor,
            sub_order__created_at__gte=start_of_day,
            sub_order__created_at__lt=end_of_day,
            sub_order__status__in=['PAID', 'SHIPPED', 'DELIVERED', 'PACKED']
        ).aggregate(total=Sum(revenue_expr))['total'] or Decimal('0.00')

        VendorPerformanceDaily.objects.update_or_create(
            vendor=vendor,
            date=yesterday,
            defaults={
                'orders_count': orders_count,
                'shipped_count': shipped_count,
                'canceled_count': canceled_count,
                'late_shipments': late_shipments,
                'avg_handling_seconds': int(avg_handling_seconds),
                'revenue': revenue
            }
        )


@shared_task
def release_due_settlements(batch_size=200):
    """
    Daily task: moves SettlementRecord funds from pending -> available once the
    settlement window is reached (Delivery + N days).
    """
    today = timezone.now().date()
    qs = SettlementRecord.objects.filter(
        status=SettlementRecord.Status.PENDING,
        settlement_date__lte=today,
    ).order_by('id')

    processed = 0
    for record in qs[:batch_size]:
        FinancialService.release_settlement(record)
        processed += 1

    return {'processed': processed}

@shared_task
def aggregate_vendor_product_analytics_daily(date_str=None):
    from analytics.models import UserEvent
    from vendors.models import VendorProductAnalyticsDaily, Vendor
    from django.db.models import Count, Sum, Q, DecimalField
    from datetime import datetime, timedelta
    from django.db.models.functions import Coalesce
    from decimal import Decimal
    
    if date_str:
        target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
    else:
        target_date = timezone.now().date() - timedelta(days=1)
        
    start_dt = timezone.make_aware(datetime.combine(target_date, datetime.min.time()))
    end_dt = timezone.make_aware(datetime.combine(target_date, datetime.max.time()))

    # Process events
    events = UserEvent.objects.filter(
        created_at__gte=start_dt,
        created_at__lte=end_dt,
        product__isnull=False
    ).values('product_id', 'product__vendor_id').annotate(
        impressions=Count('id', filter=Q(event_type=UserEvent.EventType.IMPRESSION)),
        sponsored_impressions=Count('id', filter=Q(event_type=UserEvent.EventType.IMPRESSION, is_sponsored=True)),
        clicks=Count('id', filter=Q(event_type=UserEvent.EventType.CLICK)),
        sponsored_clicks=Count('id', filter=Q(event_type=UserEvent.EventType.CLICK, is_sponsored=True)),
        carts=Count('id', filter=Q(event_type=UserEvent.EventType.ADD_TO_CART)),
        purchases=Count('id', filter=Q(event_type=UserEvent.EventType.PURCHASE))
    )

    revenue_data = OrderItem.objects.filter(
        sub_order__created_at__gte=start_dt,
        sub_order__created_at__lte=end_dt
    ).values('product_variant__product_id').annotate(
        total_revenue=Sum(F('price') * F('quantity'))
    )
    revenue_map = {item['product_variant__product_id']: item['total_revenue'] for item in revenue_data}

    for item in events:
        vendor_id = item['product__vendor_id']
        product_id = item['product_id']
        if not vendor_id:
            continue
            
        revenue = revenue_map.get(product_id, Decimal('0.00'))

        VendorProductAnalyticsDaily.objects.update_or_create(
            vendor_id=vendor_id,
            product_id=product_id,
            date=target_date,
            defaults={
                'impressions': item['impressions'],
                'clicks': item['clicks'],
                'carts': item['carts'],
                'purchases': item['purchases'],
                'sponsored_impressions': item['sponsored_impressions'],
                'sponsored_clicks': item['sponsored_clicks'],
                'revenue': revenue
            }
        )
    return "Analytics Aggregation Complete"
