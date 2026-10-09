# BÁO CÁO — LOCAL CACHE & ĐỒNG BỘ CLOUD (OFFLINE-FIRST SYNC)

> **Người thực hiện:** Lý Đình Sơn — MSSV 2351170615 — Thành viên Nhóm 12
> **Nhánh Git:** `son-offline-sync`
> **Sản phẩm bàn giao:** mã nguồn tầng đồng bộ + bộ kiểm thử tự động + báo cáo này (`SON_BAOCAO_OFFLINE_SYNC.md`)
> **Đề tài:** TH1 — Ứng dụng Quản lý Tài liệu Học tập theo Kiến trúc Cashew
> **Kế thừa:** [`SON_BAOCAO_CLOUD.md`](SON_BAOCAO_CLOUD.md) (phân tích Cloud/TCO) và nhánh `son-cloud` (Firebase Auth + Cloud Storage).

---

## 📋 MỤC LỤC

1. [Tổng quan & mục tiêu](#1-tổng-quan--mục-tiêu)
2. [Kiến trúc tầng đồng bộ](#2-kiến-trúc-tầng-đồng-bộ)
3. [Mô hình dữ liệu (Schema v3)](#3-mô-hình-dữ-liệu-schema-v3)
4. [Luồng Offline-First](#4-luồng-offline-first)
5. [Kiểm tra toàn vẹn dữ liệu (Checksum MD5/SHA-256)](#5-kiểm-tra-toàn-vẹn-dữ-liệu-checksum-md5sha-256)
6. [Đồng bộ thao tác xóa (Tombstone & delete_logs)](#6-đồng-bộ-thao-tác-xóa-tombstone--delete_logs)
7. [Giải quyết xung đột (Last-Write-Wins)](#7-giải-quyết-xung-đột-last-write-wins)
8. [Giám sát kết nối & tự động đồng bộ](#8-giám-sát-kết-nối--tự-động-đồng-bộ)
9. [Giao diện trạng thái đồng bộ](#9-giao-diện-trạng-thái-đồng-bộ)
10. [Kiểm thử tự động](#10-kiểm-thử-tự-động)
11. [Kiểm thử hiệu năng mạng yếu](#11-kiểm-thử-hiệu-năng-mạng-yếu)
12. [Hướng dẫn chạy & kiểm thử](#12-hướng-dẫn-chạy--kiểm-thử)
13. [Hạn chế & hướng mở rộng](#13-hạn-chế--hướng-mở-rộng)
14. [Phụ lục](#14-phụ-lục)

---

## 1. Tổng quan & mục tiêu

Ứng dụng Quản lý Tài liệu trước đây lưu metadata trong SQLite và tệp metadata trên Firebase Storage, **nhưng metadata chưa được đồng bộ giữa các thiết bị** và ứng dụng **không hoạt động đầy đủ khi mất mạng**. Báo cáo này trình bày việc bổ sung **cơ chế Offline-First thực sự**:

| Mục tiêu | Cách hiện thực |
|:---|:---|
| Ghi/đọc dữ liệu khi **không có mạng** | Ghi ngay vào SQLite + lưu tệp vào **Local File Cache** |
| **Tự động đẩy** thay đổi lên Cloud khi có mạng | Hàng đợi `sync_outbox` + `SyncEngine.push` |
| **Tự động kéo** thay đổi từ Cloud về | `SyncEngine.pull` theo mốc `lastSyncAt` |
| **Kiểm tra toàn vẹn** tệp sau khi truyền | Checksum **MD5/SHA-256** (gói `crypto`) |
| **Đồng bộ thao tác xóa** hai chiều | Bảng `delete_logs` + tombstone |
| **Phát hiện & xử lý xung đột** | So khớp `version` + Last-Write-Wins |
| **Đo hiệu năng mạng yếu** | `MockRemoteSyncService` + `NetworkProfile` |

**Ràng buộc kỹ thuật:** không sử dụng credentials thật. Tầng Cloud được trừu tượng hóa qua interface `RemoteSyncService` và cài đặt giả lập `MockRemoteSyncService` (lưu trong bộ nhớ, mô phỏng độ trễ/băng thông/mất gói). Nhờ vậy toàn bộ logic đồng bộ **kiểm thử được tự động, tất định**, và có thể thay bằng Firebase/AWS chỉ bằng một cài đặt mới của interface.

---

## 2. Kiến trúc tầng đồng bộ

Tầng đồng bộ nằm trong **Struct/Domain Layer**, phụ thuộc vào **Data Layer** (SQLite) nhưng độc lập với nhà cung cấp Cloud cụ thể:

```
┌───────────────────────────────────────────────────────────────────────┐
│ PRESENTATION LAYER                                                     │
│   HomePage ──► SyncStatusBanner (online/offline, số mục chờ, nút sync) │
└───────────────────────────────┬───────────────────────────────────────┘
                                │ ValueNotifier<SyncSnapshot>
┌───────────────────────────────▼───────────────────────────────────────┐
│ STRUCT / DOMAIN LAYER                                                  │
│   DocumentService ──► ghi SQLite + enqueueOutbox + unawaited(syncNow)  │
│                                                                        │
│   SyncEngine ──► push(outbox) / pull(changes) / conflict (LWW)         │
│      ├── RemoteSyncService (interface)  ◄── MockRemoteSyncService      │
│      ├── LocalFileStore (interface)     ◄── IoLocalFileStore / Memory  │
│      ├── NetworkMonitor (interface)     ◄── HeartbeatNetworkMonitor    │
│      └── ChecksumUtils (MD5 / SHA-256)                                 │
└───────────────────────────────┬───────────────────────────────────────┘
                                │ DAO
┌───────────────────────────────▼───────────────────────────────────────┐
│ DATA LAYER (SQLite schema v3)                                          │
│   documents (+ 8 cột đồng bộ) · delete_logs · sync_outbox · sync_state │
└───────────────────────────────────────────────────────────────────────┘
```

**Các file chính:**

| File | Vai trò |
|:---|:---|
| `lib/struct/sync/sync_engine.dart` | Bộ máy đồng bộ hai chiều, xử lý xung đột, checksum |
| `lib/struct/sync/remote_sync_service.dart` | Interface Cloud + DTO `RemoteDocument`, exception |
| `lib/struct/sync/mock_remote_sync_service.dart` | Cloud giả lập + `NetworkProfile` (mô phỏng mạng yếu) |
| `lib/struct/sync/network_monitor.dart` | Heartbeat / Manual network monitor |
| `lib/struct/sync/local_file_store.dart` | Interface cache tệp + bản bộ nhớ |
| `lib/struct/sync/local_file_store_io.dart` / `_web.dart` | Cache tệp native (path_provider) / web |
| `lib/struct/sync/sync_global.dart` | `syncEngine` toàn cục (nullable) |
| `lib/struct/checksum_utils.dart` | Tính/xác minh MD5 & SHA-256 |
| `lib/struct/models/sync_models.dart` | `DeleteLogModel`, `SyncOutboxEntry` |
| `lib/widgets/sync_status_banner.dart` | Thẻ trạng thái đồng bộ trên Dashboard |
| `lib/main.dart` | Khởi tạo `SyncEngine` + `HeartbeatNetworkMonitor` |

---

## 3. Mô hình dữ liệu (Schema v3)

Schema SQLite được nâng từ **v2 → v3** (có migration giữ nguyên dữ liệu cũ).

### 3.1. Bảng `documents` — bổ sung 8 cột đồng bộ

| Cột | Kiểu | Ý nghĩa |
|:---|:---|:---|
| `checksum` | TEXT | Checksum tệp đính kèm (MD5/SHA-256) |
| `checksum_algo` | TEXT | `md5` hoặc `sha256` |
| `version` | INTEGER | Số phiên bản, tăng mỗi lần sửa (phát hiện xung đột) |
| `sync_status` | TEXT | `localOnly`/`pendingUpload`/`pendingDelete`/`synced`/`conflict` |
| `is_deleted` | INTEGER | Cờ tombstone cục bộ |
| `local_path` | TEXT | Đường dẫn tệp cache cục bộ khi Offline |
| `remote_updated_at` | INTEGER | Thời điểm cập nhật trên Cloud |
| `last_synced_at` | INTEGER | Lần đồng bộ thành công gần nhất |

### 3.2. Các bảng mới

**`delete_logs`** — nhật ký xóa (tombstone) để đồng bộ xóa hai chiều:

| Cột | Ý nghĩa |
|:---|:---|
| `id`, `document_id`, `owner_id` | Định danh bản ghi & chủ sở hữu |
| `storage_path`, `checksum` | Vị trí & checksum tệp đã xóa |
| `deleted_at` | Thời điểm xóa |
| `source` | `local` (xóa từ thiết bị) hoặc `remote` (xóa từ Cloud) |
| `sync_status` | `pending` / `synced` / `failed` |
| `remote_updated_at`, `retry_count`, `last_error` | Phục vụ retry & đối soát |

**`sync_outbox`** — hàng đợi thao tác cục bộ chờ đẩy lên Cloud (FIFO):
`id`, `entity_type`, `entity_id`, `operation` (`upsert`/`delete`), `payload` (JSON), `created_at`, `retry_count`, `last_error`.

**`sync_state`** — key/value lưu mốc `last_sync_at` (dùng `ConflictAlgorithm.replace`).

> **Ghi chú migration:** khi nâng cấp, `_migrateSchema` chạy `ALTER TABLE documents ADD COLUMN ...` cho từng cột trong `DocumentTable.syncColumns` và tạo 3 bảng mới bằng `CREATE TABLE IF NOT EXISTS`.

---

## 4. Luồng Offline-First

```
NGƯỜI DÙNG LƯU TÀI LIỆU
        │
        ▼
DocumentService.saveDocument / updateDocument / deleteDocument
        │  1. Validate (tiêu đề, URL)
        │  2. Tính checksum + lưu tệp vào Local File Cache
        │  3. GHI NGAY vào SQLite (sync_status = pendingUpload)   ◄── luôn thành công dù offline
        │  4. enqueueOutbox(upsert/delete)
        │  5. unawaited(syncNow())  ──► đồng bộ nền nếu có mạng
        ▼
SyncEngine.syncNow()
        │
        ├─ ping() kiểm tra kết nối
        │
        ├─ PUSH: duyệt sync_outbox (FIFO)
        │     • uploadFile (nếu có tệp cục bộ) + xác minh checksum
        │     • pushDocument (metadata + version)
        │     • thành công  → markDocumentSyncStatus(synced) + xóa outbox
        │     • xung đột    → _handleConflict (LWW)
        │     • lỗi mạng    → giữ outbox + incrementOutboxRetry, dừng vòng lặp
        │
        ├─ PULL: pullChanges(since = lastSyncAt)
        │     • bản mới    → tải tệp (verify checksum) + insert
        │     • tombstone  → ghi delete_logs(source=remote) + hard delete cục bộ
        │     • bản cũ hơn → bỏ qua
        │
        └─ setLastSyncAt(serverTime) + notifyDocumentsChanged()
```

**Nguyên tắc cốt lõi:** *Local là nguồn sự thật cho thao tác người dùng; Cloud đồng bộ sau.* Mọi thao tác ghi đều thành công tức thời vào SQLite, kể cả khi mất mạng; outbox đảm bảo không mất thay đổi.

---

## 5. Kiểm tra toàn vẹn dữ liệu (Checksum MD5/SHA-256)

Sử dụng gói `crypto` (đã thêm làm phụ thuộc trực tiếp trong `pubspec.yaml`).

| Hàm | Mô tả |
|:---|:---|
| `ChecksumUtils.compute(bytes, algorithm)` | Trả về chuỗi hex MD5 (32 ký tự) hoặc SHA-256 (64 ký tự) |
| `ChecksumUtils.computeString(text)` | Checksum cho metadata văn bản |
| `ChecksumUtils.computeResult(bytes)` | Trả kèm thuật toán + kích thước |
| `ChecksumUtils.verify(bytes, expected)` | So khớp, **tự suy luận thuật toán theo độ dài hex**, so sánh theo thời gian hằng số |

**Áp dụng:**
- **Trước khi PUSH:** đọc tệp từ cache, tính lại checksum; nếu khác checksum lưu trong DB → chặn đẩy, giữ trong outbox (phát hiện tệp hỏng).
- **Sau khi PULL:** tệp tải về được xác minh; nếu sai → đánh dấu `sync_status = conflict` thay vì tin tưởng mù.

Đây là biện pháp giảm thiểu mối đe dọa **T5 — Toàn vẹn dữ liệu** đã nêu trong `SON_BAOCAO_CLOUD.md`.

---

## 6. Đồng bộ thao tác xóa (Tombstone & delete_logs)

Xóa tài liệu không phải là xóa cứng ngay, mà qua cơ chế tombstone:

1. `DocumentService.deleteDocument` ghi một bản ghi `delete_logs` (`sync_status = pending`, `source = local`) và đưa `delete` vào `sync_outbox`.
2. `SyncEngine._pushDelete` gọi `remote.deleteFile` + `remote.deleteRemoteDocument`, sau đó cập nhật `delete_logs.sync_status = synced`.
3. Khi thiết bị khác PULL, tombstone (`isDeleted = true`) được trả về; `_applyRemote` ghi `delete_logs` với `source = remote` rồi `hardDeleteDocument` cục bộ.

Nhờ đó thao tác xóa **không bị "hồi sinh"** khi thiết bị khác đồng bộ lại, và mọi xóa đều có **nhật ký đối soát**.

---

## 7. Giải quyết xung đột (Last-Write-Wins)

Mỗi lần sửa, `version` tăng thêm 1. Xung đột xảy ra khi Cloud đã có `version` mới hơn bản đang đẩy.

| Tình huống | Xử lý |
|:---|:---|
| **PUSH** gặp `RemoteConflictException` và **bản cục bộ mới hơn** (`updatedDate` > remote) | Tăng local `version = remote.version + 1`, giữ `pendingUpload`, đưa lại vào outbox để đẩy ở chu kỳ sau |
| **PUSH** gặp xung đột và **bản Cloud mới hơn** | Chấp nhận bản Cloud (`updateDocument(remoteDoc.toLocalDocument())`) |
| **PULL** thấy `remote.version <= local.version` | Bỏ qua |
| **PULL** thấy `remote.version > local.version`, cục bộ "bẩn" và mới hơn | Giữ cục bộ, đánh dấu `conflict` để chờ đẩy |
| **PULL** thấy bản Cloud mới hơn | Ghi đè cục bộ bằng bản Cloud |

Chiến lược là **Last-Write-Wins có kiểm soát** dựa trên `version` **và** `updatedDate`, tránh ghi đè mù quáng.

---

## 8. Giám sát kết nối & tự động đồng bộ

- `HeartbeatNetworkMonitor` gọi `RemoteSyncService.ping()` định kỳ (mặc định 15 giây trong `main.dart`). Cách này **đáng tin hơn** việc chỉ kiểm tra "có Wi-Fi", vì nó xác nhận khả năng tới Cloud thực sự.
- `SyncEngine.bindNetworkMonitor` lắng nghe sự kiện Online/Offline; khi mạng phục hồi → tự động gọi `syncNow()`.
- `ManualNetworkMonitor` cho phép bật/tắt mạng tức thời trong kiểm thử.

> Vì không dùng `connectivity_plus` (không có sẵn trong cache), cơ chế heartbeat dựa trên `ping()` vừa nhẹ vừa đủ chính xác cho đồng bộ.

---

## 9. Giao diện trạng thái đồng bộ

`SyncStatusBanner` (đặt đầu Dashboard) lắng nghe `ValueNotifier<SyncSnapshot>` và hiển thị:

| Trạng thái | Hiển thị |
|:---|:---|
| Ngoại tuyến | "Đang ngoại tuyến" + số thay đổi chờ |
| Đang đồng bộ | "Đang đồng bộ..." + vòng xoay |
| Lỗi | "Đồng bộ gặp lỗi" + tóm tắt lỗi |
| Có mục chờ | "N mục chờ đồng bộ" + nút "Đồng bộ ngay" |
| Đã đồng bộ | "Đã đồng bộ Cloud" + thời điểm lần cuối |
| Chưa bật sync | "Chỉ lưu cục bộ" |

Nút "Đồng bộ ngay" cho phép người dùng chủ động đồng bộ (có thể ghi đè hành vi qua tham số `onSyncNow` để phục vụ test).

---

## 10. Kiểm thử tự động

Toàn bộ test chạy bằng `flutter test`. Kết quả hiện tại: **42/42 test pass (100%)**.

| File | Số test | Nội dung |
|:---|:---:|:---|
| `test/data_layer_test.dart` | 6 | CRUD, Search, Reactive Stream (đã có) |
| `test/struct_layer_test.dart` | 5 | Validation, Stats, Formatters (đã có) |
| `test/presentation_layer_test.dart` | 4 | Widget & tương tác UI (đã có) |
| `test/checksum_test.dart` | 6 | MD5/SHA-256 với vector chuẩn, verify, phát hiện hỏng tệp |
| `test/sync_engine_test.dart` | 13 | PUSH/PULL, checksum, delete_logs, mất mạng, xung đột LWW, retry |
| `test/weak_network_perf_test.dart` | 4 | Hiệu năng mạng yếu + mất gói + phục hồi |
| `test/sync_ui_test.dart` | 4 | Trạng thái banner + nút đồng bộ |
| **Tổng** | **42** | |

**Các kịch bản SyncEngine nổi bật:**
1. PUSH tài liệu cục bộ kèm tệp + đối chiếu checksum trên Cloud.
2. PULL tài liệu mới từ Cloud về SQLite + cache tệp.
3. PULL khi tệp Cloud không tồn tại (không lỗi, giữ `localPath = null`).
4. Xóa tài liệu: tạo `delete_logs` + tombstone trên Cloud + cập nhật `synced`.
5. Mất mạng: PUSH thất bại nhưng **giữ nguyên outbox**.
6. Checksum PULL sai → đánh dấu `conflict`.
7–8. Xung đột PULL: cục bộ mới hơn giữ lại; Cloud mới hơn ghi đè.
9. Xung đột PUSH: tăng `version` và đẩy lại.
10. Lỗi tạm thời: `retry_count` tăng, đồng bộ lại thành công.
11. PUSH phát hiện tệp cache hỏng → chặn đẩy.
12. `initialize()` nạp đúng số mục chờ.
13. LWW theo `updatedDate` khi `version` bằng nhau.

---

## 11. Kiểm thử hiệu năng mạng yếu

Bộ `weak_network_perf_test.dart` dùng `MockRemoteSyncService` với các `NetworkProfile` để đo thời gian và thông lượng của chu trình PUSH+PULL (4 tài liệu × 4 KB) trên máy phát triển:

| Hồ sơ mạng | Thời gian | Thông lượng | ms/tài liệu | Số lần truyền | Lỗi |
|:---|---:|---:|---:|---:|---:|
| **Lý tưởng** (0ms, không giới hạn) | **41 ms** | **387,4 KB/s** | 10 | 9 | 0 |
| **3G yếu** (48 KB/s, 30ms) | **731 ms** | **21,9 KB/s** | 183 | 9 | 0 |
| **Rất yếu/2G** (12 KB/s, 90ms) | **2.473 ms** | **6,5 KB/s** | 618 | 9 | 0 |

> Số liệu mang tính **minh họa** (phụ thuộc máy chạy); xu hướng tất định: **mạng càng yếu → thời gian càng lớn, thông lượng càng giảm**, trong khi **cùng khối lượng công việc (9 lần truyền)**.

Ngoài ra, test còn kiểm chứng:
- **Mất gói 100%** → đồng bộ thất bại, hàng đợi được giữ nguyên (`pending = 1`), sau khi mạng ổn định thì tự đồng bộ lại thành công (`pending = 0`).
- Hồ sơ mạng có nhãn mô tả đúng và cờ `unlimitedBandwidth` chính xác.

---

## 12. Hướng dẫn chạy & kiểm thử

```powershell
cd study_document_manager
flutter pub get
flutter analyze          # chỉ còn cảnh báo info có sẵn, không có lỗi
flutter test             # 42/42 test pass
flutter run              # chạy app, xem SyncStatusBanner trên Dashboard
```

**Thử nghiệm Offline thủ công (trên `MockRemoteSyncService`):** tạm đặt `remote.online = false` hoặc ngắt mạng trong môi trường demo; thêm/sửa/xóa tài liệu → thẻ trạng thái báo "Đang ngoại tuyến" và số mục chờ; bật mạng lại → tự động đồng bộ.

---

## 13. Hạn chế & hướng mở rộng

| Hạn chế hiện tại | Hướng khắc phục |
|:---|:---|
| Cloud mặc định là bản **Mock** (lưu trong bộ nhớ) | Viết `FirebaseRemoteSyncService` cài đặt `RemoteSyncService` trên Firestore + Cloud Storage; chỉ thay ở `main.dart` |
| Chưa có xác thực/phân quyền phía Cloud | Dùng Firebase Auth + Security Rules (đã có nền tảng từ nhánh `son-cloud`) |
| Cache tệp trên Web chỉ tồn tại trong phiên | Dùng IndexedDB / Cache Storage API |
| Xung đột mới ở mức LWW | Nâng cấp lên CRDT hoặc giữ nhiều phiên bản (version history) |
| `delete_logs` chưa có cơ chế nén/dọn định kỳ | Thêm job compaction các tombstone đã `synced` quá N ngày |

---

## 14. Phụ lục

### 14.1. Interface `RemoteSyncService`

```dart
abstract class RemoteSyncService {
  Future<bool> ping();
  Future<DateTime> serverTime();
  Future<List<RemoteDocument>> pullChanges({required String ownerId, DateTime? since});
  Future<RemoteDocument> pushDocument(RemoteDocument document);
  Future<void> deleteRemoteDocument({required String ownerId, required String documentId, String? storagePath});
  Future<String> uploadFile({required String ownerId, required String documentId, required String fileName, required List<int> bytes, void Function(double)? onProgress});
  Future<List<int>?> downloadFile({required String storagePath, void Function(double)? onProgress});
  Future<void> deleteFile({required String storagePath});
}
```

### 14.2. Lệnh kiểm thử nhanh từng phần

```powershell
flutter test test/checksum_test.dart
flutter test test/sync_engine_test.dart
flutter test test/weak_network_perf_test.dart
flutter test test/sync_ui_test.dart
```

### 14.3. Cam kết chất lượng

- ✅ Không phá vỡ 15 test có sẵn (tất cả vẫn pass).
- ✅ `flutter analyze` không phát sinh cảnh báo mới trong các file mới.
- ✅ Kiểm thử tất định, không phụ thuộc Cloud/credentials thật.

---

*Báo cáo được tạo cho bài thực hành TH1 — Nhóm 12. Mọi số liệu hiệu năng là kết quả đo minh họa trên máy phát triển.*
