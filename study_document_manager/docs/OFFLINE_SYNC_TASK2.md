# [Sơn] Task 2 — Offline Local Cache + Đồng bộ hai chiều + Toàn vẹn dữ liệu

> Phạm vi: **Logic layer + Unit test** (không làm UI — UI Cloud thuộc nhánh `dang-cloud-ui`).
> Nhánh: `son-cloud` (tách riêng khi merge theo quy trình nhóm).

## 1. Các yêu cầu đã triển khai

| # | Yêu cầu | Trạng thái | Nơi hiện thực |
|---|---------|-----------|---------------|
| 1 | Local Cache khi Offline (đọc/ghi tài liệu + tệp không cần mạng) | ✅ | `file_cache_store_*.dart`, cột sync trên `documents` |
| 2 | Tự động đồng bộ **hai chiều** khi mạng trở lại | ✅ | `offline_sync_service.dart` (pull→merge→push) |
| 3 | Kiểm tra toàn vẹn tệp bằng **MD5 / SHA-256** | ✅ | `checksum_util.dart` |
| 4 | Cập nhật bảng **`delete_logs`** (tombstone chống hồi sinh dữ liệu xóa) | ✅ | `DeleteLogTable`, DAO trong `app_database.dart` |
| 5 | **Kiểm thử hiệu năng truyền tải khi mạng yếu** | ✅ | `InMemorySyncBackend` (latency / bandwidth / retry / timeout) |
| 6 | Chỉ "test pass" — code compile, app không cần chạy thật | ✅ | `flutter analyze` + `flutter test` 41/41 |

## 2. Kiến trúc (đều nằm ở tầng logic, tách khỏi UI)

```
lib/struct/sync/
├── sync_status.dart            # enum SyncStatus (synced/pendingCreate/pendingUpdate/pendingDelete)
├── sync_models.dart            # RemoteDocument, DeleteLogEntry, SyncReport, SyncState, SyncNetworkException
├── checksum_util.dart          # băm MD5/SHA-256, hàm verify() cho byte tệp
├── file_cache_store_base.dart  # interface FileCacheStore + bản In-Memory
├── file_cache_store_io.dart    # bản dùng ổ đĩa thật (Desktop/mobile)
├── file_cache_store_web.dart   # bản Web (In-Memory, không cần dart:io)
├── file_cache_store.dart       # factory có conditional import theo nền tảng
├── connectivity_monitor.dart   # abstract + ManualConnectivityMonitor (mô phỏng offline/online)
├── sync_backend.dart           # interface SyncBackend + InMemorySyncBackend (giả lập Cloud)
├── firebase_sync_backend.dart  # backend THẬT (Firestore + Storage + Auth)
├── offline_sync_service.dart   # điều phối đồng bộ (lõi của Task 2)
└── sync_bootstrap.dart         # khai báo/kết nối, fallback an toàn khi chưa cấu hình Firebase
```

Tầng dữ liệu (SQLite):
- `lib/database/tables.dart` — nâng schema lên **v2**: thêm cột sync vào `documents`, tạo bảng `delete_logs` + `sync_meta`.
- `lib/database/app_database.dart` — migration v1→v2 (`onUpgrade` giữ nguyên dữ liệu cũ), DAO: `getPendingDocuments`, `applyRemoteDocument/Delete`, `markDocumentSynced` (không đụng `updated_date`), ghi/truy vấn `delete_logs`, `sync_meta`.
- `lib/struct/models/document_models.dart` — `DocumentModel` có các trường sync; `copyWithSync()` chỉ sửa trường sync mà không làm mới `updatedDate` (bảo toàn mốc Last-Write-Wins).
- `lib/main.dart` — khởi tạo `initCloudSyncService` (Firebase thật khi có cấu hình; không có thì chạy Offline-First bình thường).

## 3. Cơ chế hoạt động

```
Người dùng thao tác (tạo/sửa/xóa)
   │  ── lúc OFFLINE ─────────────────────────
   ▼
SQLite: tài liệu đánh dấu pendingCreate/pendingUpdate,
        xóa thì ghi TOMBSTONE vào delete_logs (synced=0)
   │  ── có mạng trở lại (ConnectivityMonitor) ─
   ▼
OfflineSyncService.syncNow()
   ① PULL metadata + tombstone từ Cloud, MERGE theo updated_date (LWW)
   ② PUSH tài liệu còn chờ + byte tệp (kèm checksum SHA-256)
   ③ PUSH tombstone delete_logs → Cloud xóa tài liệu + tệp
   ④ Đồng bộ tệp xuống Local Cache, xác minh checksum trước khi dùng
```

- **Xung đột**: *Last-Write-Wins* theo `updatedDate` (bản nào mới hơn thắng). Xóa/sửa xung đột: sửa mới hơn lệnh xóa → giữ bản (hồi sinh).
- **Tombstone**: không xóa thẳng bản ghi Cloud khi offline — ghi `delete_logs` trước, có mạng mới đẩy lệnh xóa, tránh đồng bộ ngược "hồi sinh" dữ liệu.
- **Checksum**: SHA-256 (mặc định) hoặc MD5; tệp tải về sai checksum bị coi là hỏng (trả về null).
- **Mạng yếu**: `OfflineSyncService` bọc mọi thao tác Cloud bằng retry (mặc định 3 lần) + timeout (30s); `SyncReport` ghi lại số byte, thời gian, thông lượng → dữ liệu cho kiểm thử hiệu năng.

## 4. Hiệu năng mạng yếu (InMemorySyncBackend mô phỏng)

- `online = false` → ném `SyncNetworkException` (mô phỏng mất mạng).
- `latency` + `bytesPerSecond` → mô phỏng độ trễ & băng thông (tính cả thời gian truyền byte).
- `failNext(n)` → làm hỏng n lần gọi liên tiếp (mạng chập chờn) để kiểm cơ chế retry.

Kết quả test (nhóm D): upload 100 KB trên băng thông 200 KB/s mất >100 ms, thông lượng ≤ băng thông; lỗi thoáng qua được retry thành công; mạng hỏng dài hạn → fail đúng số lần retry; thao tác quá chậm → timeout không treo.

## 5. Chạy kiểm thử

```bash
cd study_document_manager
flutter pub get
flutter analyze      # 0 lỗi (chỉ còn info có sẵn từ trước ở file UI khác)
flutter test         # 41/41 pass
```

Test mới: `test/sync_layer_test.dart` (26 test, 5 nhóm A–E: Checksum, Local Cache/delete_logs, đồng bộ hai chiều, hiệu năng mạng yếu, DTO round-trip). 3 file test cũ của team vẫn pass nguyên vẹn.

## 6. Ghi chú Firebase thật

`FirebaseSyncBackend` dùng Firestore (`users/{uid}/documents`, `users/{uid}/deleteLogs`) + Storage (`users/{uid}/files/{documentId}`) + Auth (UID). Khi chạy trên Desktop/CI chưa có `google-services.json`/`firebase_options.dart`, `sync_bootstrap.dart` tự fallback → app chạy Offline-First bình thường, không crash. Lưu ý Deploy: cần composite index cho `where('updated_date') + orderBy` trong Firestore.