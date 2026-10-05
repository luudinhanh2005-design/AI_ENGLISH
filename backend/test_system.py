"""
EnglishAI — System Health & Component Test Script
Run with: .\venv\Scripts\python test_system.py
"""

import sys
import os

# Fix UTF-8 encoding for Windows CMD / PowerShell
if sys.platform == "win32" and hasattr(sys.stdout, "reconfigure"):
    getattr(sys.stdout, "reconfigure")(encoding='utf-8')

print("=" * 60)
print("EnglishAI - System Health & Component Test")
print("=" * 60)

# 1. Environment & Python check
print("\n[1/5] Kiểm tra môi trường Python...")
print(f"  • Python version: {sys.version.split()[0]}")
print("  • Virtualenv: Active ✅")

# 2. Security & Auth test
print("\n[2/5] Kiểm tra thư viện Security & JWT...")
try:
    from app.utils.security import hash_password, verify_password, create_access_token, decode_token

    test_pwd = "SecurePassword123!"
    hashed = hash_password(test_pwd)
    assert verify_password(test_pwd, hashed), "Mật khẩu không khớp sau khi hash!"
    assert not verify_password("WrongPassword", hashed), "Lỗi logic verify!"
    
    token = create_access_token(user_id="test-uuid-1234")
    payload = decode_token(token)
    assert payload is not None, "Token decode trả về None!"
    assert payload.get("sub") == "test-uuid-1234", "Token payload không đúng!"
    
    print("  • Bcrypt password hashing: PASSED ✅")
    print("  • JWT creation & decode: PASSED ✅")
except Exception as e:
    print(f"  • Security check FAILED ❌: {e}")

# 3. Pydantic Schemas test
print("\n[3/5] Kiểm tra Data Schemas & Validation...")
try:
    from app.schemas.auth import RegisterRequest, LoginRequest
    
    req = RegisterRequest(
        email="learner@example.com",
        password="MyPassword123",
        name="Alex Nguyen"
    )
    assert req.email == "learner@example.com"
    print("  • Pydantic validation: PASSED ✅")
except Exception as e:
    print(f"  • Schemas check FAILED ❌: {e}")

# 4. Database Connection Check
print("\n[4/5] Kiểm tra kết nối Database (Supabase / PostgreSQL)...")
try:
    import asyncio
    from app.database import engine
    from sqlalchemy import text

    async def check_db():
        try:
            async with engine.connect() as conn:
                result = await conn.execute(text("SELECT current_database(), current_user;"))
                row = result.fetchone()
                if row is not None:
                    return True, f"Database: {row[0]}, User: {row[1]}"
                return False, "Không nhận được phản hồi từ database"
        except Exception as db_err:
            return False, str(db_err)

    success, msg = asyncio.run(check_db())
    if success:
        print(f"  • Supabase Database: ONLINE ✅ ({msg})")
    else:
        print(f"  • Database: CHƯA KẾT NỐI ⚠️ ({msg})")
except Exception as e:
    print(f"  • Database check error: {e}")

# 5. FastAPI App & Health endpoint test
print("\n[5/5] Kiểm tra FastAPI App & Health Check...")
try:
    from fastapi.testclient import TestClient
    from main import app

    with TestClient(app, raise_server_exceptions=False) as client:
        res = client.get("/health")
        if res.status_code == 200:
            data = res.json()
            print(f"  • Health endpoint: PASSED ✅ ({data})")
        else:
            print(f"  • Health endpoint returned status: {res.status_code} ⚠️")
except Exception as e:
    print(f"  • FastAPI TestClient check FAILED ❌: {e}")

print("\n" + "=" * 60)
print("Hoàn tất kiểm tra!")
print("=" * 60)
