from decimal import Decimal
import uuid
from django.utils import timezone
from rest_framework.test import APITestCase

from users.models import User
from vendors.models import Vendor, LedgerEntry
from products.models import Product, Category
from ads.models import AdCampaign, AdImpression, AdClick

class VendorAdsTest(APITestCase):
    def setUp(self):
        # Vendor 1 User & Vendor
        self.vendor_user = User.objects.create_user(
            email="ad_vendor@example.com",
            username="ad_vendor",
            password="Str0ngPassw0rd!",
            type=User.Types.VENDOR,
        )
        self.vendor = Vendor.objects.create(
            user=self.vendor_user,
            store_name="Ad Store",
            description="Test Ad Store",
            is_approved=True,
            is_live=True,
            available_balance=Decimal("500.00"),
            ad_balance=Decimal("100.00"),
        )
        LedgerEntry.objects.create(
            vendor=self.vendor,
            entry_type=LedgerEntry.EntryType.AD_CREDIT_TOPUP,
            bucket=LedgerEntry.Bucket.AD_CREDITS,
            direction=LedgerEntry.Direction.CREDIT,
            status=LedgerEntry.Status.POSTED,
            amount=Decimal("100.00"),
            reference_type=LedgerEntry.ReferenceType.AD_CAMPAIGN,
            reference_id=self.vendor.id,
            description="Initial Ad Balance",
        )
        self.product = Product.objects.create(
            vendor=self.vendor,
            name="Sponsored Shoes",
            description="High quality running shoes",
            price=Decimal("120.00"),
            stock_quantity=50,
            is_available=True,
        )

        # Vendor 2 User & Vendor
        self.vendor2_user = User.objects.create_user(
            email="vendor2@example.com",
            username="vendor2",
            password="Str0ngPassw0rd!",
            type=User.Types.VENDOR,
        )
        self.vendor2 = Vendor.objects.create(
            user=self.vendor2_user,
            store_name="Other Store",
            is_approved=True,
        )
        self.product2 = Product.objects.create(
            vendor=self.vendor2,
            name="Other Product",
            description="Other product description",
            price=Decimal("50.00"),
            stock_quantity=10,
            is_available=True,
        )

    def test_vendor_create_ad_campaign(self):
        self.client.force_authenticate(user=self.vendor_user)
        resp = self.client.post(
            "/api/vendors/ads/campaigns/",
            data={
                "product_id": self.product.id,
                "budget_total": "100.00",
                "daily_budget": "20.00",
                "cost_per_click": "2.00",
                "keywords": ["shoes", "running"],
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 201, resp.data)
        self.assertEqual(resp.data["status"], "ACTIVE")
        self.assertEqual(Decimal(str(resp.data["budget_total"])), Decimal("100.00"))
        self.assertEqual(Decimal(str(resp.data["cost_per_click"])), Decimal("2.00"))
        self.assertEqual(resp.data["product"], self.product.id)

    def test_vendor_cannot_campaign_other_vendor_product(self):
        self.client.force_authenticate(user=self.vendor_user)
        resp = self.client.post(
            "/api/vendors/ads/campaigns/",
            data={
                "product_id": self.product2.id,
                "budget_total": "100.00",
                "cost_per_click": "2.00",
            },
            format="json",
        )
        self.assertEqual(resp.status_code, 400, resp.data)
        self.assertIn("product_id", resp.data)

    def test_vendor_ad_topup(self):
        self.client.force_authenticate(user=self.vendor_user)
        resp = self.client.post(
            "/api/vendors/ads/topup/",
            data={"amount": "150.00"},
            format="json",
        )
        self.assertEqual(resp.status_code, 200, resp.data)
        self.vendor.refresh_from_db()
        # 500.00 - 150.00 = 350.00 available
        self.assertEqual(self.vendor.available_balance, Decimal("350.00"))
        # 100.00 + 150.00 = 250.00 ad_balance
        self.assertEqual(self.vendor.ad_balance, Decimal("250.00"))

    def test_vendor_ad_campaign_pause_and_update(self):
        campaign = AdCampaign.objects.create(
            vendor=self.vendor,
            product=self.product,
            budget_total=Decimal("100.00"),
            cost_per_click=Decimal("2.00"),
            status=AdCampaign.Status.ACTIVE,
        )
        self.client.force_authenticate(user=self.vendor_user)
        resp = self.client.patch(
            f"/api/vendors/ads/campaigns/{campaign.id}/",
            data={"status": "PAUSED", "cost_per_click": "3.50"},
            format="json",
        )
        self.assertEqual(resp.status_code, 200, resp.data)
        campaign.refresh_from_db()
        self.assertEqual(campaign.status, AdCampaign.Status.PAUSED)
        self.assertEqual(campaign.cost_per_click, Decimal("3.50"))

    def test_vendor_ad_stats(self):
        AdCampaign.objects.create(
            vendor=self.vendor,
            product=self.product,
            budget_total=Decimal("100.00"),
            cost_per_click=Decimal("2.00"),
            status=AdCampaign.Status.ACTIVE,
        )
        self.client.force_authenticate(user=self.vendor_user)
        resp = self.client.get("/api/vendors/ads/stats/")
        self.assertEqual(resp.status_code, 200, resp.data)
        self.assertEqual(resp.data["total_campaigns"], 1)
        self.assertEqual(resp.data["active_campaigns"], 1)

    def test_ad_record_impression_and_click(self):
        campaign = AdCampaign.objects.create(
            vendor=self.vendor,
            product=self.product,
            budget_total=Decimal("10.00"),
            budget_spent=Decimal("0.00"),
            cost_per_click=Decimal("2.50"),
            status=AdCampaign.Status.ACTIVE,
        )
        session_id = str(uuid.uuid4())
        click_id = str(uuid.uuid4())

        # 1. Record Impression
        imp_resp = self.client.post(
            "/api/ads/impressions/",
            data={
                "campaign_id": campaign.id,
                "session_id": session_id,
                "source": "SEARCH",
            },
            format="json",
        )
        self.assertEqual(imp_resp.status_code, 200, imp_resp.data)
        self.assertTrue(imp_resp.data["recorded"])
        self.assertEqual(campaign.impressions.count(), 1)

        # 2. Record Click
        click_resp = self.client.post(
            "/api/ads/clicks/",
            data={
                "campaign_id": campaign.id,
                "session_id": session_id,
                "click_id": click_id,
            },
            format="json",
        )
        self.assertEqual(click_resp.status_code, 200, click_resp.data)
        self.assertTrue(click_resp.data["recorded"])
        campaign.refresh_from_db()
        self.assertEqual(campaign.budget_spent, Decimal("2.50"))

        # 3. Idempotent Click
        dup_resp = self.client.post(
            "/api/ads/clicks/",
            data={
                "campaign_id": campaign.id,
                "session_id": session_id,
                "click_id": click_id,
            },
            format="json",
        )
        self.assertEqual(dup_resp.status_code, 200)
        campaign.refresh_from_db()
        # Budget spent should NOT be charged again
        self.assertEqual(campaign.budget_spent, Decimal("2.50"))

    def test_public_product_list_includes_sponsored_product(self):
        campaign = AdCampaign.objects.create(
            vendor=self.vendor,
            product=self.product,
            budget_total=Decimal("50.00"),
            cost_per_click=Decimal("2.00"),
            status=AdCampaign.Status.ACTIVE,
        )

        resp = self.client.get("/api/products/")
        self.assertEqual(resp.status_code, 200, resp.data)
        results = resp.data if isinstance(resp.data, list) else resp.data.get("results", [])
        self.assertTrue(len(results) > 0)
        # First item should be the sponsored product
        first = results[0]
        self.assertEqual(first["id"], self.product.id)
        self.assertTrue(first["is_sponsored"])
        self.assertEqual(first["campaign_id"], campaign.id)
