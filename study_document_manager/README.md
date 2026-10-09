# Ứng Dụng Quản Lý Tài Liệu Học Tập (Cashew Architecture)

> **Môn học:** Phát triển Ứng dụng Di động / Kiến trúc & Thiết kế Phần mềm  
> **Bài thực hành:** TH1 - Xây dựng Ứng dụng Quản lý Tài liệu Học tập theo Kiến trúc Cashew  
> **Nền tảng:** Flutter & Dart  
> **Cơ sở dữ liệu:** SQLite / Drift Pattern  

---

## 📌 1. Giới thiệu dự án
Ứng dụng **Quản lý Tài liệu Học tập** được xây dựng nhằm giúp học sinh, sinh viên tổ chức, phân loại, lưu trữ và theo dõi tiến độ các tài liệu học thuật (Bài giảng Slide, Bài tập/Đồ án, Tài liệu tham khảo, Đề thi/Đề cương) trong suốt học kỳ.

Dự án được kế thừa và áp dụng triệt để **nguyên lý kiến trúc của Cashew** (một ứng dụng mã nguồn mở tiêu biểu về quản lý tài chính cá nhân trên Flutter). Điểm trọng tâm của đề tài là **phân tách độc lập các tầng xử lý (Separation of Concerns)**, đảm bảo tính **mô-đun hóa (Modularity)**, khả năng bảo trì và mở rộng hệ thống (Scalability).

---

## 🏛️ 2. Sơ đồ Kiến trúc Chuẩn Cashew (4-Tier Architecture)

```
               ┌────────────────────────────────────────────────────────┐
               │         PRESENTATION LAYER (Tầng Giao diện)            │
               │  - pages/: HomePage, DocumentListPage, AddEditPage...  │
               │  - widgets/: DocumentCard, SearchBar, PageFramework... │
               └───────────────────────────┬────────────────────────────┘
                                           │ Gọi nghiệp vụ / Lắng nghe
                                           ▼
               ┌────────────────────────────────────────────────────────┐
               │       STRUCT / DOMAIN LAYER (Tầng Nghiệp vụ & Dịch vụ) │
               │  - models/: DocumentModel, SubjectModel, Enums         │
               │  - services/: DocumentService (Validation, Filtering)  │
               │  - state/: DocumentGlobalState (Reactive Notifiers)    │
               │  - formatters/: DocumentFormatters                     │
               └───────────────────────────┬────────────────────────────┘
                                           │ Gọi lưu trữ & phản ứng
                                           ▼
               ┌────────────────────────────────────────────────────────┐
               │          DATA LAYER (Tầng Cơ sở Dữ liệu)               │
               │  - tables.dart: Định nghĩa Schema bảng SQLite          │
               │  - app_database.dart: SQLite DAO, Reactive Streams     │
               │  - databaseGlobal.dart: Singleton toàn cục             │
               └────────────────────────────────────────────────────────┘
```

---

## 📂 3. Cấu trúc thư mục dự án

```
study_document_manager/
├── lib/
│   ├── colors.dart                 # [Theme & Colors] Bảng màu chuẩn, hỗ trợ Light/Dark mode
│   ├── functions.dart              # [Global Utils] Tiện ích điều hướng, Snackbar, Popup
│   ├── main.dart                   # [Entry Point] Khởi động DB và cấu hình App
│   │
│   ├── database/                   # [DATA LAYER - Tầng Dữ liệu]
│   │   ├── tables.dart             # Cấu trúc bảng SQLite (Subjects, Documents)
│   │   ├── app_database.dart       # Quản lý kết nối, CRUD, tìm kiếm, Reactive Streams
│   │   └── databaseGlobal.dart     # Singleton truy cập cơ sở dữ liệu toàn cục
│   │
│   ├── struct/                     # [STRUCT / DOMAIN LAYER - Tầng Nghiệp vụ]
│   │   ├── models/
│   │   │   └── document_models.dart# Enums phân loại, Data models (Subject, Document)
│   │   ├── document_service.dart   # Logic kiểm thực dữ liệu (Validation), lọc, sắp xếp, thống kê
│   │   ├── document_global.dart    # Biến trạng thái toàn cục (ValueNotifier)
│   │   └── formatters.dart         # Định dạng thời gian, hạn nộp, văn bản
│   │
│   ├── widgets/                    # [REUSABLE UI COMPONENTS - Giao diện dùng chung]
│   │   ├── framework/
│   │   │   ├── page_framework.dart # Khung màn hình Scaffold chuẩn Cashew
│   │   │   └── popup_framework.dart# Khung hộp thoại Dialog/Popup đồng bộ
│   │   ├── document_card.dart      # Thẻ hiển thị tài liệu, badge màu, hạn nộp, trạng thái
│   │   ├── document_search_bar.dart# Thanh tìm kiếm có Debounce 300ms
│   │   ├── filter_chip_bar.dart    # Thanh lọc nhanh dạng Chip nằm ngang
│   │   ├── custom_text_field.dart  # Ô nhập liệu tiêu chuẩn hóa
│   │   └── confirm_delete_dialog.dart # Hộp thoại xác nhận xóa an toàn
│   │
│   └── pages/                      # [PRESENTATION SCREENS - Màn hình chức năng]
│       ├── home_page.dart          # Dashboard: Thống kê số liệu, môn học, bài tập gấp, gần đây
│       ├── document_list_page.dart # Quản lý danh sách tài liệu đầy đủ, lọc, sắp xếp
│       ├── add_edit_document_page.dart # Màn hình Thêm mới và Chỉnh sửa tài liệu
│       ├── document_detail_page.dart # Chi tiết tài liệu, ghi chú, đính kèm, đổi trạng thái
│       └── document_search_page.dart # Tìm kiếm nâng cao đa tiêu chí
│
├── test/                           # [TESTING LAYER - Kiểm thử tính đúng đắn]
│   ├── data_layer_test.dart        # Kiểm thử tầng Data (CRUD, Search, Reactive Stream)
│   ├── struct_layer_test.dart      # Kiểm thử tầng Struct (Validation, Stats, Formatters)
│   └── presentation_layer_test.dart# Kiểm thử tầng UI (Widget render & User interactions)
│
└── pubspec.yaml                    # Cấu hình gói và thư viện
```

---

## 🚀 4. Hướng dẫn cài đặt và Chạy ứng dụng

### Yêu cầu hệ thống
- Flutter SDK `>= 3.0.0`
- Dart SDK `>= 3.0.0`

### Các bước khởi chạy
1. Mở terminal tại thư mục dự án:
   ```bash
   cd study_document_manager
   ```
2. Cài đặt các gói phụ thuộc:
   ```bash
   flutter pub get
   ```
3. Chạy ứng dụng trên máy ảo Android/iOS hoặc Windows desktop:
   ```bash
   flutter run
   ```

---

## 🧪 5. Kiểm thử tự động (Automated Testing)
Dự án được viết đầy đủ bộ Unit Test & Widget Test cho cả 3 tầng kiến trúc, bao gồm cả tầng đồng bộ Offline-First:
```bash
flutter test
```
Kết quả kiểm thử đạt **42/42 test cases pass (100%)**, trong đó:

- 15 test nền tảng: Data (CRUD/Search/Reactive Stream), Struct (Validation/Stats/Formatters), Presentation (Widgets).
- 6 test checksum MD5/SHA-256 với vector chuẩn.
- 13 test SyncEngine: PUSH/PULL, checksum, `delete_logs`, mất mạng, xung đột LWW, retry.
- 4 test hiệu năng mạng yếu + mất gói.
- 4 test giao diện thẻ trạng thái đồng bộ.

## 🎨 6. Giao diện và nhập môn học
- Giao diện dùng dải màu Indigo–Violet–Blue, có biến thể sáng/tối và giới hạn chiều rộng nội dung trên Chrome để dễ đọc.
- Trên màn hình nhỏ, các thẻ thống kê tự chuyển thành bố cục hai cột để tránh tràn viền.
- Khi thêm tài liệu, chọn môn có sẵn từ gợi ý hoặc nhập môn mới theo định dạng `MÃ MÔN - Tên môn`. Môn mới được lưu cùng tài liệu; mã hoặc tên bị trùng sẽ được báo để tránh tạo nhầm môn.

## 🔥 7. Firebase Authentication và Cloud Storage

Ứng dụng kết nối Firebase project `cashew-study-docs-3afed` trên Android, iOS và Web:

- **Firebase Authentication:** đăng nhập/đăng xuất bằng Google, xem trạng thái đăng nhập và hồ sơ cơ bản tại nút tài khoản trên Dashboard.
- **Cloud Storage:** chọn PDF, Word, PowerPoint, Excel hoặc TXT tối đa 20 MB. File được tải lên `users/{uid}/documents/{documentId}/{fileId}/{fileName}`; tiến trình upload được hiển thị.
- **SQLite:** tiếp tục lưu metadata cục bộ. Cột `storage_path` chứa đường dẫn Storage; schema được nâng từ phiên bản 1 lên 2 để giữ nguyên dữ liệu cũ. Metadata hiện chưa đồng bộ giữa các thiết bị.
- **Rules:** `storage.rules` chỉ cho phép chủ sở hữu đã đăng nhập đọc/xóa file và giới hạn loại nội dung/kích thước. Ứng dụng không lưu Download URL có token vào SQLite; không chia sẻ URL tải xuống được tạo khi mở file ra ngoài vì URL dạng token có thể được dùng như liên kết truy cập.

### Cấu hình Firebase Console cần hoàn tất

1. Nhóm trưởng mở **Project settings → Users and permissions** và mời thành viên bằng email Google; chỉ cấp quyền cần thiết để cấu hình project/deploy Rules, không chia sẻ mật khẩu.
2. Trong **Authentication → Sign-in method**, bật nhà cung cấp **Google** và chọn email hỗ trợ.
3. Trong **Storage**, tạo default bucket. Kiểm tra gói/billing mà Console yêu cầu cho bucket, chọn region phù hợp (khó đổi sau khi tạo) và cấu hình cảnh báo ngân sách trước khi upload.
4. Với Android, thêm SHA-1 của debug/release signing key vào app Android trong Firebase Console. Có thể xem fingerprint từ thư mục `android` bằng `.\gradlew signingReport`; sau khi thêm SHA, tải/cập nhật cấu hình Android nếu Firebase yêu cầu.
5. Web cần cho phép domain đang dùng trong Authentication settings → Authorized domains. iOS Google Sign-In cần URL scheme đã cấu hình trong `ios/Runner/Info.plist`.

### Cấu hình lại máy thành viên hoặc project Firebase

Chạy từ thư mục `study_document_manager`:

```powershell
firebase login
dart pub global activate flutterfire_cli
flutter pub get
dart pub global run flutterfire_cli:flutterfire configure --project=cashew-study-docs-3afed --platforms=android,ios,web
```

Không dán URL đăng nhập Google vào PowerShell. Chỉ mở URL trong trình duyệt khi Firebase CLI yêu cầu đăng nhập. Các tệp `lib/firebase_options.dart`, `android/app/google-services.json` và `ios/Runner/GoogleService-Info.plist` gắn ứng dụng với đúng Firebase project.

Sau khi bật/tạo Storage bucket trong Console, triển khai rules từ thư mục ứng dụng:

```powershell
firebase deploy --only storage --project=cashew-study-docs-3afed
```

### Kiểm tra luồng demo

1. Chạy app trên Android, iOS hoặc Chrome và đăng nhập bằng Google.
2. Tạo/chỉnh sửa tài liệu, chọn một file hợp lệ và lưu; xác nhận tiến độ upload hoàn tất.
3. Kiểm tra file trong Firebase Console dưới thư mục UID tương ứng; mở file từ trang chi tiết.
4. Thử người dùng khác truy cập file và thử file quá 20 MB hoặc sai loại; Storage Rules phải từ chối.
5. Xóa tài liệu; ứng dụng xóa object Storage trước rồi mới xóa metadata SQLite. Nếu Storage báo lỗi, metadata được giữ lại và lỗi được báo rõ.

### Báo cáo và slide

- Báo cáo phân tích đủ checklist 1–7: [BAO_CAO_TICH_HOP_CLOUD.md](BAO_CAO_TICH_HOP_CLOUD.md).
- Slide trình chiếu: [SLIDE_FIREBASE_CLOUD.pptx](SLIDE_FIREBASE_CLOUD.pptx); nội dung có thể chỉnh ở [SLIDE_FIREBASE_CLOUD.md](SLIDE_FIREBASE_CLOUD.md). Thay `[Điền tên nhóm]` và `[Điền tên thành viên]` trước khi nộp.
- Báo cáo phân biệt phần đã có (Google Authentication, Cloud Storage, SQLite local) với Firestore/đồng bộ metadata là phần mở rộng. Nhánh `son-offline-sync` đã bổ sung **Local Cache + đồng bộ metadata Offline-First** (xem Mục 8). Build/test thành công không thay thế cho kiểm tra đăng nhập, bucket và Rules trên Firebase Console thật.

---

## 🔄 8. Local Cache & Đồng bộ Cloud (Offline-First)

Nhánh `son-offline-sync` bổ sung cơ chế **Offline-First**: thao tác cục bộ được ghi ngay vào SQLite và lưu tệp vào cache; khi có mạng, dữ liệu tự động đẩy lên/kéo về Cloud.

- **Hàng đợi đồng bộ:** bảng `sync_outbox` lưu các thao tác `upsert`/`delete` chờ đẩy lên Cloud.
- **Đồng bộ hai chiều:** `SyncEngine.push` (outbox → Cloud) và `SyncEngine.pull` (Cloud → SQLite theo mốc `lastSyncAt`).
- **Toàn vẹn dữ liệu:** checksum **MD5/SHA-256** (`crypto`) kiểm tra tệp trước khi đẩy và sau khi kéo.
- **Đồng bộ xóa:** bảng `delete_logs` (tombstone) đảm bảo xóa hai chiều, không "hồi sinh" dữ liệu.
- **Xung đột:** Last-Write-Wins có kiểm soát dựa trên `version` + `updatedDate`.
- **Kết nối:** `HeartbeatNetworkMonitor` tự động kích hoạt đồng bộ khi mạng phục hồi.
- **Giao diện:** thẻ `SyncStatusBanner` trên Dashboard hiển thị Online/Offline, số mục chờ và nút "Đồng bộ ngay".
- **Nền tảng Cloud:** trừu tượng qua `RemoteSyncService`; mặc định dùng `MockRemoteSyncService` (không cần credentials), dễ thay bằng Firebase/AWS.

**Schema SQLite nâng từ v2 lên v3** (tự động migration): thêm 8 cột đồng bộ vào `documents` và 3 bảng `delete_logs`, `sync_outbox`, `sync_state`.

📄 Chi tiết kiến trúc, mô hình dữ liệu, kết quả kiểm thử và hiệu năng mạng yếu: [SON_BAOCAO_OFFLINE_SYNC.md](SON_BAOCAO_OFFLINE_SYNC.md).
