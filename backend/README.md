# Backend API for Google Sheets (Node.js/Express)

## วิธีใช้งาน

1. ติดตั้ง dependencies:
   ```bash
   cd backend
   npm install
   ```
2. ตั้งค่า Spreadsheet ID ใน `index.js` (แทนที่ 'YOUR_SPREADSHEET_ID')
3. รัน backend:
   ```bash
   node index.js
   ```
4. ทดสอบ API:
   - GET http://localhost:3000/sheet/a2

## หมายเหตุ
- ใช้ Service Account credentials จาก assets/
- รองรับเฉพาะอ่านค่า A2 จากชีต AppStorage (แก้ไข SHEET_NAME ได้)
- สามารถขยาย endpoint เพิ่มเติมได้
