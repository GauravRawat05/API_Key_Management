# API_Key_Management
# DevifyX Assignment – API Key Management Dashboard
**Author**: Gaurav Singh Rawat

## ✅ Objective
This project implements a complete API Key Management System using only MySQL (v8.0+), focused on:
- User & API Key management
- Secure key generation
- Rate limiting
- Key usage logging
- Key expiry & revocation
- Reporting and audit logs

## 🏗️ Schema
- `users`: User details
- `api_keys`: Secure keys with expiry and environment info
- `api_usage_logs`: Tracks each API call
- `admin_logs`: Admin audit trail

## 🔧 Features
- Secure API key creation (SHA2 hash + UUID)
- Custom rate limits per key
- Auto-expiry via MySQL Event Scheduler
- Usage tracking and rate limiting logic
- Reporting Views:
  - `v_usage_per_key`
  - `v_usage_per_user`

## 🧪 Sample Data
Includes:
- 3 users
- 3 keys
- API usage logs to simulate rate limiting

## 🛠️ How to Run
1. Enable Event Scheduler: `SET GLOBAL event_scheduler = ON;`
2. Execute the SQL file in MySQL 8.0+
3. Use procedures to test features.

## 📌 Note
- Entirely SQL-based: no frontend/backend
- Fully documented and ready for review
