# Tum Pa Guay Restaurant V6 Professional

V6 ใช้งานร่วมกับ Supabase Database, Authentication และ Storage ที่สร้างไว้แล้ว

## ฟีเจอร์
- หน้าเมนูมืออาชีพ รูปทุกใบขนาดเท่ากัน
- Drag & Drop รูปอาหาร
- Responsive สำหรับมือถือ
- โครงสร้างรองรับลาว ไทย อังกฤษ
- Admin Login ผ่าน Supabase Auth
- Dashboard จำนวนเมนู เมนูแนะนำ และการจอง
- ปฏิทินการจองโต๊ะ
- เมนูแนะนำ
- Database + Storage ออนไลน์
- เมนูเริ่มต้น 125 รายการ

## เหลือทำเพียงอย่างเดียว
เปิด `config.js` แล้วแทน:

```js
SUPABASE_ANON_KEY: "PASTE_YOUR_PUBLISHABLE_KEY_HERE"
```

ด้วย Publishable Key จาก Supabase > Settings > API Keys

Project URL ถูกใส่ให้แล้ว:
`https://jypsgmauzytklwiojfzg.supabase.co`

## สร้าง Admin
1. Supabase > Authentication > Users > Add user
2. สร้าง Email และ Password
3. SQL Editor รัน:

```sql
update public.admin_profiles
set role = 'owner', active = true
where user_id = (
  select id from auth.users
  where email = 'YOUR_ADMIN_EMAIL'
);
```

4. อัปโหลดไฟล์ทั้งหมดขึ้น GitHub
5. เปิด `/admin.html`
