import logging
from typing import List, Optional
from datetime import timedelta
from django.utils import timezone
from django.db import transaction, models
from django.db.models import F

from ads.models import AdCampaign, AdImpression, AdClick
from vendors.models import Vendor, LedgerEntry
from products.models import Product

logger = logging.getLogger(__name__)

class AdAuctionService:
    @staticmethod
    def get_boosted_products(limit: int = 5, category_id: Optional[int] = None, search_query: Optional[str] = None) -> List[int]:
        """
        Retrieves active sponsored products using a simple `bid × quality_score` auction.
        """
        now = timezone.now()
        
        # 1. Base eligibility (Active, within timeframe, budget not exhausted)
        # Using exact fields: status=ACTIVE, starts_at <= now, budget_spent < budget_total
        queryset = AdCampaign.objects.filter(
            status=AdCampaign.Status.ACTIVE,
            starts_at__lte=now,
            budget_spent__lt=F('budget_total'),
            product__is_active=True,
            product__stock_quantity__gt=0  # Availability Gate: Never show sponsored OOS
        ).exclude(ends_at__lt=now)

        # Apply category targeting strictly if category_id is provided
        if category_id:
            queryset = queryset.filter(target_categories__id=category_id)
            
        # Pacing: If daily_budget is set, ensure we haven't spent it all today.
        # For simplicity, we assume daily pacing is computed directly or we just use budget_spent
        
        # We need to evaluate the auction. We fetch all candidates (bounded in prod, but simple for MVP).
        campaigns = list(queryset.select_related('product', 'vendor'))
        
        scored_campaigns = []
        for campaign in campaigns:
            # Pacing Check
            if campaign.daily_budget:
                # Basic pacing: Check if remaining total budget is valid.
                pass
                
            # Basic Quality Score Components:
            # 1. Vendor SLA (inverse of cancellation rate + late shipment)
            vendor = campaign.vendor
            sla_penalty = (vendor.cancellation_rate + vendor.late_shipment_rate) / 100
            sla_factor = max(0.1, 1.0 - float(sla_penalty))
            
            # 2. Rating Factor (avg_rating / 5)
            rating_factor = float(vendor.avg_rating) / 5.0 if vendor.avg_rating > 0 else 0.5
            
            # 3. Relevance / Keyword Match
            keyword_match = 1.0
            if search_query and campaign.keywords:
                search_query_lower = search_query.lower()
                if any(kw.lower() in search_query_lower for kw in campaign.keywords):
                    keyword_match = 1.5
                    
            quality_score = float(sla_factor) * rating_factor * keyword_match
            
            # Final Score
            final_score = float(campaign.cost_per_click) * quality_score
            scored_campaigns.append((final_score, campaign))
            
        # Sort by score descending
        scored_campaigns.sort(key=lambda x: x[0], reverse=True)
        
        # Enforce density limits (handled by caller or simple top N here)
        return [c.product_id for score, c in scored_campaigns[:limit]]

class AdBillingService:
    @staticmethod
    def record_click(campaign_id: int, user_id: Optional[int], session_id: str, click_id: str) -> bool:
        """
        Registers a click, checks idempotency via click_id, and deducts CPC from vendor ledger.
        """
        try:
            with transaction.atomic():
                # 1. Check Idempotency (has this click_id been processed?)
                if AdClick.objects.filter(click_id=click_id).exists():
                    logger.info(f"Idempotent click ignored: {click_id}")
                    return True # Already processed
                
                campaign = AdCampaign.objects.select_for_update().get(id=campaign_id)
                
                # 2. Fraud / Guardrails Checks
                # Self-click block
                if user_id and campaign.vendor.user_id == user_id:
                    logger.warning(f"Self-click detected for campaign {campaign_id} by user {user_id}")
                    return False
                    
                # Rate Limiting: No clicks from same session in last 5 seconds
                five_secs_ago = timezone.now() - timedelta(seconds=5)
                if AdClick.objects.filter(session_id=session_id, created_at__gte=five_secs_ago).exists():
                    logger.warning(f"Rate limited click for campaign {campaign_id} session {session_id}")
                    return False
                    
                # 3. Create AdClick record
                click = AdClick.objects.create(
                    campaign=campaign,
                    user_id=user_id,
                    session_id=session_id,
                    click_id=click_id
                )
                
                # 4. Deduct Budget
                cpc = campaign.cost_per_click
                if cpc > 0:
                    campaign.budget_spent += cpc
                    
                    # Update status if exhausted
                    if campaign.budget_spent >= campaign.budget_total:
                        campaign.status = AdCampaign.Status.EXHAUSTED
                    
                    campaign.save()
                    
                    # 5. Ledger Entry for Vendor billing
                    LedgerEntry.objects.create(
                        vendor=campaign.vendor,
                        entry_type=LedgerEntry.EntryType.AD_SPEND_CLICK,
                        bucket=LedgerEntry.Bucket.AD_CREDITS,
                        direction=LedgerEntry.Direction.DEBIT,
                        status=LedgerEntry.Status.POSTED,
                        amount=cpc,
                        reference_type=LedgerEntry.ReferenceType.AD_CAMPAIGN,
                        reference_id=campaign.id,
                        description=f"CPC charge for click {click_id}",
                        idempotency_key=f"ad_click_{click_id}"
                    )
                    
                    # Recalculate ad balance
                    campaign.vendor.recache_ad_balance()
                    
                return True
                
        except AdCampaign.DoesNotExist:
            logger.error(f"Campaign {campaign_id} not found.")
            return False
        except Exception as e:
            logger.error(f"Error recording click {click_id}: {str(e)}")
            return False

    @staticmethod
    def record_impression(campaign_id: int, user_id: Optional[int], session_id: str, source: str) -> bool:
        """
        Registers an impression, bucketed by minute to deduplicate.
        """
        now = timezone.now()
        minute_bucket = now.replace(second=0, microsecond=0)
        
        try:
            # We use get_or_create to enforce the UniqueConstraint on minute_bucket
            AdImpression.objects.get_or_create(
                campaign_id=campaign_id,
                session_id=session_id,
                source=source,
                minute_bucket=minute_bucket,
                defaults={'user_id': user_id}
            )
            return True
        except Exception as e:
            logger.error(f"Error recording impression for campaign {campaign_id}: {str(e)}")
            return False
