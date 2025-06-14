import express from 'express';
import cors from 'cors';
import { google } from 'googleapis';
import fs from 'fs';

const app = express();
app.use(cors());
app.use(express.json());

// TODO: Replace with your actual spreadsheet ID and sheet name
const SPREADSHEET_ID = '1zUpKFFtgpmP-8Xq8anweb6BK2DOT8Sy-8VSfzlJ27eU';
const SHEET_NAME = 'AppStorage';

// Load service account credentials (ใช้ไฟล์ใหม่)
const credentials = JSON.parse(fs.readFileSync('../assets/sheetsubmit-34dhh-cd8c05690415.json'));

const auth = new google.auth.GoogleAuth({
  credentials,
  scopes: ['https://www.googleapis.com/auth/spreadsheets'], // เปลี่ยนเป็น full access
});

app.get('/sheet/a2', async (req, res) => {
  try {
    const client = await auth.getClient();
    const sheets = google.sheets({ version: 'v4', auth: client });
    const range = `${SHEET_NAME}!A2`;
    const response = await sheets.spreadsheets.values.get({
      spreadsheetId: SPREADSHEET_ID,
      range,
    });
    const value = response.data.values?.[0]?.[0] || '';
    res.json({ value });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

app.get('/sheet/names', async (req, res) => {
  try {
    const client = await auth.getClient();
    const sheetsApi = google.sheets({ version: 'v4', auth: client });
    const meta = await sheetsApi.spreadsheets.get({ spreadsheetId: SPREADSHEET_ID });
    const allSheets = meta.data.sheets?.map(s => s.properties.title) || [];
    // กรองชื่อชีตที่ไม่ใช่ AppStorage และไม่ขึ้นต้นด้วย TotalExpense
    const filtered = allSheets.filter(name => name !== SHEET_NAME && !name.startsWith('TotalExpense'));
    res.json({ sheets: filtered });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Endpoint ดึง category และ paymenttype โดยวิเคราะห์จาก header row
app.get('/sheet/meta', async (req, res) => {
  try {
    const client = await auth.getClient();
    const sheets = google.sheets({ version: 'v4', auth: client });
    // อ่านข้อมูลตั้งแต่แถว 1 (header) ถึง D (หรือมากกว่า)
    const range = `${SHEET_NAME}!A1:Z`;
    const response = await sheets.spreadsheets.values.get({
      spreadsheetId: SPREADSHEET_ID,
      range,
    });
    const rows = response.data.values || [];
    if (rows.length < 2) return res.json({ categories: [], paymenttypes: [] });
    const header = rows[0];
    const dataRows = rows.slice(1);
    // รองรับ header ภาษาอังกฤษและไทย
    const catIdx = header.findIndex(h => ['category', 'หมวดหมู่'].includes(h.trim().toLowerCase()));
    const payIdx = header.findIndex(h => ['paymenttype', 'ชนิดการจ่ายเงิน'].includes(h.trim().toLowerCase()));
    const categories = catIdx === -1 ? [] : [...new Set(dataRows.map(r => r[catIdx]).filter(v => v && v.trim() !== ''))];
    const paymenttypes = payIdx === -1 ? [] : [...new Set(dataRows.map(r => r[payIdx]).filter(v => v && v.trim() !== ''))];
    res.json({ categories, paymenttypes });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// Endpoint สำหรับเพิ่มแถวข้อมูลในชีตเป้าหมาย (ตามชื่อ sheet ที่ส่งมา)
app.post('/sheet/append', async (req, res) => {
  try {
    const { sheet, date, item, category, payment, amount, note } = req.body;
    if (!sheet) return res.status(400).json({ error: 'Missing sheet name' });
    const client = await auth.getClient();
    const sheets = google.sheets({ version: 'v4', auth: client });
    const newRow = [date, item, category, payment, amount, note];
    await sheets.spreadsheets.values.append({
      spreadsheetId: SPREADSHEET_ID,
      range: `${sheet}!A2`, // เปลี่ยนจาก A1 เป็น A2
      valueInputOption: 'USER_ENTERED',
      insertDataOption: 'INSERT_ROWS',
      requestBody: {
        values: [newRow],
      },
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ทดสอบ: เพิ่ม endpoint สำหรับ append ข้อมูลไปที่ AppStorage!A20:F20
app.post('/sheet/test-append-appstorage', async (req, res) => {
  try {
    const { date, item, category, payment, amount, note } = req.body;
    const client = await auth.getClient();
    const sheets = google.sheets({ version: 'v4', auth: client });
    const newRow = [date, item, category, payment, amount, note];
    await sheets.spreadsheets.values.update({
      spreadsheetId: SPREADSHEET_ID,
      range: `${SHEET_NAME}!A20:F20`,
      valueInputOption: 'USER_ENTERED',
      requestBody: {
        values: [newRow],
      },
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// เพิ่ม endpoint สำหรับเพิ่ม category หรือ paymenttype ใหม่
app.post('/sheet/add-meta', async (req, res) => {
  try {
    const { type, value } = req.body; // type: 'category' หรือ 'paymenttype'
    if (!['category', 'paymenttype'].includes(type) || !value || !value.trim()) {
      return res.status(400).json({ error: 'Invalid type or value' });
    }
    const client = await auth.getClient();
    const sheets = google.sheets({ version: 'v4', auth: client });
    // ระบุชื่อคอลัมน์โดยตรง
    let colName = '';
    if (type === 'category') {
      colName = 'Category';
    } else if (type === 'paymenttype') {
      colName = 'PaymentType';
    }
    // หา index ของคอลัมน์จาก header
    const metaRes = await sheets.spreadsheets.values.get({
      spreadsheetId: SPREADSHEET_ID,
      range: `${SHEET_NAME}!1:1`,
    });
    const header = metaRes.data.values?.[0] || [];
    const colIdx = header.findIndex(h => h.trim().toLowerCase() === colName.toLowerCase());
    if (colIdx === -1) return res.status(400).json({ error: 'Header not found' });
    // แปลง index เป็น column letter
    function indexToColumn(n) {
      let s = '';
      while (n >= 0) {
        s = String.fromCharCode((n % 26) + 65) + s;
        n = Math.floor(n / 26) - 1;
      }
      return s;
    }
    const colLetter = indexToColumn(colIdx);
    // อ่านค่าทั้งคอลัมน์นั้น
    const colRange = `${SHEET_NAME}!${colLetter}2:${colLetter}`;
    const colRes = await sheets.spreadsheets.values.get({
      spreadsheetId: SPREADSHEET_ID,
      range: colRange,
    });
    const values = (colRes.data.values || []).map(r => r[0]);
    if (values.includes(value)) return res.json({ success: true, message: 'Already exists' });
    // หาแถวสุดท้ายที่มีข้อมูลในคอลัมน์นั้น
    const lastRow = values.length + 2; // +2 เพราะ header อยู่แถว 1, data เริ่มแถว 2
    const targetCell = `${colLetter}${lastRow}`;
    // ใส่ค่าที่ cell ถัดไปในคอลัมน์นั้น
    await sheets.spreadsheets.values.update({
      spreadsheetId: SPREADSHEET_ID,
      range: `${SHEET_NAME}!${targetCell}`,
      valueInputOption: 'USER_ENTERED',
      requestBody: { values: [[value]] },
    });
    res.json({ success: true });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

const PORT = 3000;
app.listen(PORT, () => {
  console.log(`Backend API listening on port ${PORT}`);
});
