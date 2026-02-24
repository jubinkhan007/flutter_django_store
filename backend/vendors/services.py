import csv
import threading
from decimal import Decimal
from django.db import transaction
from django.core.files.storage import default_storage

def process_bulk_job_async(job_id):
    thread = threading.Thread(target=_process_bulk_job, args=(job_id,))
    thread.daemon = True
    thread.start()

def _process_bulk_job(job_id):
    from .models import BulkJob, AuditLog
    from products.models import Product, ProductVariant

    try:
        job = BulkJob.objects.get(id=job_id)
    except BulkJob.DoesNotExist:
        return

    job.status = BulkJob.Status.PROCESSING
    job.save(update_fields=['status'])

    report = {"processed": 0, "success": 0, "errors": []}
    
    try:
        with default_storage.open(job.file.name, 'r') as f:
            reader = csv.DictReader(f)
            
            for row_index, row in enumerate(reader, start=2): # Row 1 is header
                report["processed"] += 1
                try:
                    sku = row.get('sku')
                    if not sku:
                        raise ValueError("SKU is required")
                        
                    if job.job_type == BulkJob.JobType.PRICE_UPDATE:
                        price = row.get('price')
                        if price is None:
                            raise ValueError("price column missing")
                        
                        price = Decimal(price)
                        with transaction.atomic():
                            variant = ProductVariant.objects.get(sku=sku, product__vendor=job.vendor)
                            old_price = variant.price_override
                            variant.price_override = price
                            variant.save()
                            
                            AuditLog.objects.create(
                                vendor=job.vendor,
                                action='BULK_PRICE_UPDATE',
                                details=f"Variant {sku} price changed from {old_price} to {price}"
                            )
                            
                    elif job.job_type == BulkJob.JobType.STOCK_UPDATE:
                        stock = row.get('stock')
                        if stock is None:
                            raise ValueError("stock column missing")
                            
                        stock = int(stock)
                        with transaction.atomic():
                            variant = ProductVariant.objects.get(sku=sku, product__vendor=job.vendor)
                            old_stock = variant.stock_on_hand
                            variant.stock_on_hand = stock
                            variant.save()
                            
                            AuditLog.objects.create(
                                vendor=job.vendor,
                                action='BULK_STOCK_UPDATE',
                                details=f"Variant {sku} stock changed from {old_stock} to {stock}"
                            )
                            
                    elif job.job_type == BulkJob.JobType.PRODUCT_UPLOAD:
                        # Basic stub for product upload
                        name = row.get('name')
                        if not name:
                            raise ValueError("name is required for product upload")
                        # This would be more complex in reality.
                        
                    report["success"] += 1

                except ProductVariant.DoesNotExist:
                    report["errors"].append({"row": row_index, "error": f"Variant with SKU {sku} not found."})
                except Exception as e:
                    report["errors"].append({"row": row_index, "error": str(e)})

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
