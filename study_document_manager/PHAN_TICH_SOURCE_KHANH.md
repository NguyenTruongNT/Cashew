# NHẬT KÝ PHÂN TÍCH SOURCE DMS

> **Người thực hiện:** Vũ Tuấn Khanh  
> **MSSV:** 2251172386  
> **Nhóm:** 12  
> **Nhánh Git:** `khanh-cloud-analysis`  
> **Phạm vi:** Phân tích source trong thư mục `study_document_manager/`

---

## 1. Mục tiêu phân tích

Quá trình phân tích source được thực hiện nhằm:

- Xác định các thành phần cốt lõi của ứng dụng DMS.
- Đánh giá khả năng tái sử dụng khi tích hợp Cloud.
- Xác định các thành phần cần thay đổi hoặc xây dựng mới.
- Đề xuất dịch vụ Cloud Storage phù hợp.
- Cung cấp căn cứ cho nội dung Mục 1 và Mục 3 của báo cáo.

---

## 2. Frontend

### 2.1. Công nghệ

- Framework: Flutter.
- Ngôn ngữ: Dart.
- Nền tảng: Web, Android, Windows, iOS, Linux và macOS.
- Giao diện: Material Design.
- Hỗ trợ giao diện sáng, tối và theo hệ thống.

### 2.2. Các màn hình chính

| Chức năng | File source |
|---|---|
| Trang chủ | `lib/pages/home_page.dart` |
| Danh sách tài liệu | `lib/pages/document_list_page.dart` |
| Thêm và sửa tài liệu | `lib/pages/add_edit_document_page.dart` |
| Xem chi tiết tài liệu | `lib/pages/document_detail_page.dart` |
| Tìm kiếm tài liệu | `lib/pages/document_search_page.dart` |
| Widget dùng chung | `lib/widgets/` |
| Trạng thái bộ lọc | `lib/struct/document_global.dart` |

### 2.3. Chức năng quan sát được

- Hiển thị danh sách tài liệu.
- Thêm, sửa và xóa tài liệu.
- Tìm kiếm theo tiêu đề, ghi chú hoặc thẻ.
- Lọc theo môn học và loại tài liệu.
- Đánh dấu tài liệu quan trọng.
- Theo dõi trạng thái bài tập.
- Hiển thị tài liệu gần đây.
- Mở liên kết hoặc đường dẫn tài liệu.

### 2.4. Đánh giá

Frontend có khả năng tái sử dụng cao. Khi tích hợp Cloud, cần bổ sung:

- Login Page.
- Auth State.
- Chọn tệp từ thiết bị.
- Tiến trình upload và download.
- Trạng thái đồng bộ.
- Xử lý mất kết nối.
- Thông báo lỗi xác thực và lưu trữ.

**Mức Cloud-readiness:** Cao.

---

## 3. Tầng nghiệp vụ

### 3.1. Thành phần chính

- Service: `lib/struct/document_service.dart`.
- Database engine: `lib/database/app_database.dart`.
- Tiện ích chung: `lib/functions.dart`.
- Database global: `lib/database/databaseGlobal.dart`.

### 3.2. Nghiệp vụ hiện tại

`DocumentService` thực hiện:

- Kiểm tra tiêu đề.
- Kiểm tra URL.
- Gọi các thao tác CRUD.
- Lọc và sắp xếp tài liệu.
- Tính toán thống kê.
- Truy cập database cục bộ.

### 3.3. Hạn chế

- Chưa có Backend server.
- Chưa có RESTful API.
- Chưa có xác thực người dùng.
- Chưa có phân quyền tài liệu.
- Service còn phụ thuộc vào database global.
- Chưa có cơ chế xử lý lỗi mạng.
- Chưa có Remote Repository.

### 3.4. Đề xuất

Kiến trúc truy cập dữ liệu nên được tổ chức:

```text
UI / Presentation
        │
        ▼
Use Case / Service
        │
        ▼
Document Repository
   ┌────┴─────┐
   ▼          ▼
Local       Remote
Repository  Repository
   │          │
SQLite       Cloud
```

**Mức Cloud-readiness:** Trung bình – Cao.

---

## 4. Metadata Database

### 4.1. Công nghệ

- Database: SQLite.
- Thư viện: `sqflite`.
- Desktop support: `sqflite_common_ffi`.
- Web: SQLite WASM và bộ nhớ In-Memory dự phòng.

### 4.2. File source

| Nội dung | File |
|---|---|
| Khởi tạo database | `lib/database/app_database.dart` |
| Database global | `lib/database/databaseGlobal.dart` |
| Schema | `lib/database/tables.dart` |
| Model tài liệu | `lib/struct/models/document_models.dart` |

### 4.3. Bảng dữ liệu

#### Bảng `subjects`

Lưu các thông tin:

- ID.
- Tên môn học.
- Mã môn học.
- Màu sắc.
- Biểu tượng.
- Ngày tạo.

#### Bảng `documents`

Lưu các thông tin:

- ID.
- Tiêu đề.
- Môn học.
- Loại tài liệu.
- Ghi chú.
- Chuỗi `file_url`.
- Tags.
- Trạng thái.
- Độ ưu tiên.
- Yêu thích.
- Deadline.
- Ngày tạo.
- Ngày cập nhật.

### 4.4. Trường cần bổ sung khi tích hợp Cloud

| Trường | Mục đích |
|---|---|
| `ownerId` | Định danh chủ sở hữu |
| `cloudPath` | Đường dẫn tệp trên Cloud |
| `downloadUrl` | URL tải xuống khi cần |
| `syncStatus` | Trạng thái đồng bộ |
| `checksum` | Kiểm tra tính toàn vẹn |
| `version` | Phát hiện xung đột |
| `updatedAt` | So sánh thời điểm cập nhật |
| `isDeleted` | Hỗ trợ xóa mềm |

### 4.5. Đánh giá

SQLite có thể tiếp tục làm Local Cache. Tuy nhiên, hệ thống cần migration và cơ chế đồng bộ với nguồn dữ liệu Cloud.

**Mức Cloud-readiness:** Trung bình.

---

## 5. File Storage

### 5.1. Hiện trạng

- Trường hiện tại: `documents.file_url`.
- Kiểu dữ liệu: chuỗi URL hoặc đường dẫn.
- Ứng dụng dùng `url_launcher` để mở liên kết.
- Chưa có File Picker.
- Chưa có upload.
- Chưa có download.
- Chưa có checksum.
- Chưa có quản lý quyền tệp.
- Chưa có tiến trình truyền tệp.

### 5.2. Đề xuất

Cấu trúc Cloud Storage:

```text
users/
└── {uid}/
    └── documents/
        └── {documentId}/
            └── {fileName}
```

Các chức năng cần xây dựng:

1. Chọn tệp.
2. Kiểm tra loại và kích thước.
3. Upload lên Cloud.
4. Theo dõi tiến trình.
5. Lưu metadata.
6. Download hoặc mở tệp.
7. Xóa theo quyền.
8. Kiểm tra tính toàn vẹn.

**Mức Cloud-readiness:** Trung bình.

---

## 6. Xác thực và phân quyền

### 6.1. Hiện trạng

Source hiện tại chưa có:

- Login Page.
- Firebase Authentication.
- Google Sign-In.
- Auth State.
- User UID.
- Phân quyền tài liệu.

### 6.2. Đề xuất

Sử dụng:

- Firebase Authentication.
- Google Sign-In.
- Firebase UID.
- Firebase Security Rules.
- Auth State Stream.

UID được sử dụng để gắn tài liệu với người sở hữu và phân chia thư mục trên Cloud Storage.

**Mức Cloud-readiness:** Thấp.

---

## 7. So sánh Cloud Storage

| Nền tảng | Điểm mạnh | Điểm cần lưu ý | Phù hợp |
|---|---|---|:---:|
| Amazon S3 | Hệ sinh thái AWS lớn, IAM chi tiết, Pre-signed URL | Cấu hình phức tạp hơn, thường cần Backend | Cao |
| Firebase Storage | Tích hợp FlutterFire và Firebase Auth | Cần kiểm thử Security Rules và đồng bộ metadata | **Rất cao** |
| Azure Blob Storage | Phù hợp hệ sinh thái Microsoft | Cần quản lý SAS và tích hợp API | Trung bình |

---

## 8. Kết luận

Ứng dụng có mức sẵn sàng tích hợp Cloud ở mức trung bình đến cao.

Các thành phần có khả năng tái sử dụng tốt:

- Frontend Flutter.
- Widget giao diện.
- Logic lọc và thống kê.
- SQLite Local Cache.

Các thành phần cần xây dựng mới:

- Firebase Authentication.
- Google Sign-In.
- File Storage.
- Security Rules.
- Đồng bộ đa thiết bị.
- Cơ chế xử lý xung đột.

Phương án phù hợp cho bản thử nghiệm là kết hợp:

```text
Flutter
   │
   ├── Firebase Authentication
   ├── Google Sign-In
   ├── Cloud Storage for Firebase
   └── SQLite Local Cache
```