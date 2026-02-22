"""
═══════════════════════════════════════════════════════════════════
VENDOR ONBOARDING TEST SCRIPT
═══════════════════════════════════════════════════════════════════

This script tests the complete flow:
1. Register a new user
2. Login to get a JWT token
3. Use that token to create a vendor profile (become a seller)
4. View the vendor dashboard
5. Try creating a second vendor profile (should fail)
"""
import requests

BASE_URL = "http://127.0.0.1:8000/api"

# ─── Step 1: Register a new user ─────────────────────────────────
print("=" * 50)
print("STEP 1: Registering a new user...")
print("=" * 50)
register_data = {
    "email": "vendor@example.com",
    "username": "vendoruser",
    "password": "securepassword123",
    "type": "CUSTOMER"  # Starts as CUSTOMER, becomes VENDOR after onboarding
}
response = requests.post(f"{BASE_URL}/auth/register/", data=register_data)
if response.status_code == 201:
    print(f"✅ Registered: {response.json()}")
else:
    print(f"ℹ️  Already exists or error: {response.text}")

# ─── Step 2: Login to get tokens ─────────────────────────────────
print("\n" + "=" * 50)
print("STEP 2: Logging in...")
print("=" * 50)
login_data = {
    "email": "vendor@example.com",
    "password": "securepassword123"
}
response = requests.post(f"{BASE_URL}/auth/login/", data=login_data)
tokens = response.json()
access_token = tokens['access']
print(f"✅ Got access token: {access_token[:30]}...")

# ─── Step 3: Create a vendor profile ─────────────────────────────
# IMPORTANT: Notice the 'Authorization' header. This is how JWT works!
# Every protected endpoint needs this header.
print("\n" + "=" * 50)
print("STEP 3: Creating vendor profile (onboarding)...")
print("=" * 50)
headers = {"Authorization": f"Bearer {access_token}"}
vendor_data = {
    "store_name": "Tech Paradise",
    "description": "We sell the best electronics at great prices!"
}
response = requests.post(f"{BASE_URL}/vendors/onboarding/", data=vendor_data, headers=headers)
if response.status_code == 201:
    print(f"✅ Vendor created: {response.json()}")
else:
    print(f"❌ Error: {response.text}")

# ─── Step 4: View vendor dashboard ───────────────────────────────
print("\n" + "=" * 50)
print("STEP 4: Viewing vendor dashboard...")
print("=" * 50)
response = requests.get(f"{BASE_URL}/vendors/me/", headers=headers)
if response.status_code == 200:
    print(f"✅ Dashboard: {response.json()}")
else:
    print(f"❌ Error: {response.text}")

# ─── Step 5: Try creating ANOTHER vendor profile (should fail) ───
print("\n" + "=" * 50)
print("STEP 5: Trying duplicate vendor creation (should fail)...")
print("=" * 50)
response = requests.post(f"{BASE_URL}/vendors/onboarding/", data={"store_name": "Another Store"}, headers=headers)
if response.status_code == 400:
    print(f"✅ Correctly rejected: {response.json()}")
else:
    print(f"❌ Unexpected: {response.status_code} {response.text}")
