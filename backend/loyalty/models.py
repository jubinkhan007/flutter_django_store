from __future__ import annotations

from decimal import Decimal
from django.conf import settings
from django.db import models
from django.utils import timezone


class LoyaltyAccount(models.Model):
    class Tier(models.TextChoices):
        BRONZE = 'BRONZE', 'Bronze'
        SILVER = 'SILVER', 'Silver'
        GOLD = 'GOLD', 'Gold'
        PLATINUM = 'PLATINUM', 'Platinum'

    # Conversion rate: 10 points = 1.00 BDT
    POINTS_PER_BDT = 10

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='loyalty_account',
    )
    points_balance = models.PositiveIntegerField(default=0)
    lifetime_points_earned = models.PositiveIntegerField(default=0)
    lifetime_points_redeemed = models.PositiveIntegerField(default=0)
    tier = models.CharField(
        max_length=20,
        choices=Tier.choices,
        default=Tier.BRONZE,
    )

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-updated_at']

    def __str__(self) -> str:
        return f"{self.user} - {self.tier} ({self.points_balance} pts)"

    @property
    def points_value_bdt(self) -> Decimal:
        """Equivalent fiat store value of available points in BDT."""
        return (Decimal(self.points_balance) / Decimal(self.POINTS_PER_BDT)).quantize(Decimal('0.01'))

    @property
    def tier_multiplier(self) -> float:
        if self.tier == self.Tier.PLATINUM:
            return 2.0
        if self.tier == self.Tier.GOLD:
            return 1.5
        if self.tier == self.Tier.SILVER:
            return 1.2
        return 1.0

    @property
    def next_tier_info(self) -> dict:
        earned = self.lifetime_points_earned
        if earned < 500:
            return {
                'current_tier': self.Tier.BRONZE,
                'next_tier': self.Tier.SILVER,
                'target_points': 500,
                'points_needed': 500 - earned,
                'progress_ratio': round(earned / 500.0, 2),
            }
        elif earned < 2000:
            return {
                'current_tier': self.Tier.SILVER,
                'next_tier': self.Tier.GOLD,
                'target_points': 2000,
                'points_needed': 2000 - earned,
                'progress_ratio': round((earned - 500) / 1500.0, 2),
            }
        elif earned < 5000:
            return {
                'current_tier': self.Tier.GOLD,
                'next_tier': self.Tier.PLATINUM,
                'target_points': 5000,
                'points_needed': 5000 - earned,
                'progress_ratio': round((earned - 2000) / 3000.0, 2),
            }
        else:
            return {
                'current_tier': self.Tier.PLATINUM,
                'next_tier': None,
                'target_points': 5000,
                'points_needed': 0,
                'progress_ratio': 1.0,
            }

    def update_tier(self) -> str:
        earned = self.lifetime_points_earned
        if earned >= 5000:
            new_tier = self.Tier.PLATINUM
        elif earned >= 2000:
            new_tier = self.Tier.GOLD
        elif earned >= 500:
            new_tier = self.Tier.SILVER
        else:
            new_tier = self.Tier.BRONZE

        if self.tier != new_tier:
            self.tier = new_tier
            self.save(update_fields=['tier', 'updated_at'])
        return self.tier

    def earn_points_for_purchase(self, amount: Decimal, order=None, description: str = '') -> int:
        """
        Calculates and credits points for a purchase amount:
        Base: 1 pt per 10 BDT * tier multiplier.
        """
        if amount <= 0:
            return 0

        base_points = float(amount) / 10.0
        points_to_award = max(1, int(round(base_points * self.tier_multiplier)))

        self.points_balance += points_to_award
        self.lifetime_points_earned += points_to_award
        self.save(update_fields=['points_balance', 'lifetime_points_earned', 'updated_at'])
        self.update_tier()

        desc = description or f"Earned {points_to_award} points for order purchase"
        if order:
            desc = f"Earned {points_to_award} points for Order #{order.id}"

        LoyaltyTransaction.objects.create(
            account=self,
            transaction_type=LoyaltyTransaction.Type.EARN,
            points=points_to_award,
            balance_after=self.points_balance,
            order=order,
            description=desc,
        )
        return points_to_award

    def redeem_points(self, points: int, order=None, description: str = '') -> Decimal:
        """
        Redeems points and returns the equivalent BDT discount amount.
        """
        if points <= 0:
            return Decimal('0.00')

        if points > self.points_balance:
            raise ValueError(f"Insufficient points. Available: {self.points_balance}, requested: {points}")

        self.points_balance -= points
        self.lifetime_points_redeemed += points
        self.save(update_fields=['points_balance', 'lifetime_points_redeemed', 'updated_at'])

        discount_amount = (Decimal(points) / Decimal(self.POINTS_PER_BDT)).quantize(Decimal('0.01'))

        desc = description or f"Redeemed {points} points for ৳{discount_amount} discount"
        if order:
            desc = f"Redeemed {points} points for Order #{order.id} (৳{discount_amount} off)"

        LoyaltyTransaction.objects.create(
            account=self,
            transaction_type=LoyaltyTransaction.Type.REDEEM,
            points=-points,
            balance_after=self.points_balance,
            order=order,
            description=desc,
        )
        return discount_amount


class LoyaltyTransaction(models.Model):
    class Type(models.TextChoices):
        EARN = 'EARN', 'Earned Points'
        REDEEM = 'REDEEM', 'Redeemed Points'
        ADJUST = 'ADJUST', 'Admin Adjustment'
        REFUND = 'REFUND', 'Refund Reversal'

    account = models.ForeignKey(
        LoyaltyAccount,
        on_delete=models.CASCADE,
        related_name='transactions',
    )
    transaction_type = models.CharField(
        max_length=20,
        choices=Type.choices,
        default=Type.EARN,
    )
    points = models.IntegerField()
    balance_after = models.PositiveIntegerField()
    order = models.ForeignKey(
        'orders.Order',
        null=True,
        blank=True,
        on_delete=models.SET_NULL,
        related_name='loyalty_transactions',
    )
    description = models.CharField(max_length=255, blank=True, default='')
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ['-created_at', '-id']
        indexes = [
            models.Index(fields=['account', '-created_at']),
        ]

    def __str__(self) -> str:
        sign = '+' if self.points > 0 else ''
        return f"{self.account.user}: {sign}{self.points} pts ({self.transaction_type})"
