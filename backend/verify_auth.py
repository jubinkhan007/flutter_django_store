import requests

BASE_URL = "http://127.0.0.1:8000/api/auth"

def test_register():
    print("Testing Registration...")
    data = {
        "email": "test@example.com",
        "username": "testuser",
        "password": "securepassword123",
        "type": "CUSTOMER"
    }
    response = requests.post(f"{BASE_URL}/register/", data=data)
    if response.status_code == 201:
        print("✅ Registration Successful!")
        print(response.json())
        return True
    else:
        print("❌ Registration Failed")
        print(response.text)
        return False

def test_login():
    print("\nTesting Login...")
    data = {
        "email": "test@example.com",
        "password": "securepassword123"
    }
    response = requests.post(f"{BASE_URL}/login/", data=data)
    if response.status_code == 200:
        print("✅ Login Successful!")
        tokens = response.json()
        print(f"Access Token: {tokens['access'][:20]}...")
        return tokens['access']
    else:
        print("❌ Login Failed")
        print(response.text)
        return None

if __name__ == "__main__":
    if test_register():
        test_login()
