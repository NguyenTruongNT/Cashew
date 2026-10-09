---
marp: true
theme: default
paginate: true
---

# Firebase cho ứng dụng Quản lý Tài liệu

## Google Sign-In · Cloud Storage · Thiết lập tài khoản nhóm

**Dự án:** Study Document Manager
**Firebase project:** `cashew-study-docs-3afed`
**Nhóm 12 · Lớp 65KTPM**
**Nguyễn Văn Trường (nhóm trưởng) · Vũ Tuấn Khanh · Vũ Hải Đăng · Lý Đình Sơn**

---

# 1. Firebase là gì?

- Nền tảng Backend-as-a-Service của Google, cung cấp dịch vụ cloud quản lý sẵn.
- Firebase Authentication: xác thực người dùng, tích hợp Google.
- Cloud Storage for Firebase: lưu file; Firebase Security Rules kiểm soát quyền.
- Cloud Firestore: cơ sở dữ liệu document; có thể dùng cho metadata và đồng bộ đa thiết bị.
- Firebase Console: quản lý project, ứng dụng, Authentication, Storage, Rules và mức sử dụng.

**Trong mã nguồn:** Authentication + Storage đã được nối cho Android/Web. Firestore chưa tích hợp; cấu hình provider, bucket và Rules thật còn phải xác nhận trên Console.

---

# 2. Kiến trúc hiện tại

```text
Người dùng
   │
   ▼
Ứng dụng Flutter ───────► Firebase Authentication
   │                       Google Sign-In / UID
   ├─────────────────────► Firebase Cloud Storage
   │                       tệp theo UID + Storage Rules
   ▼
SQLite trên thiết bị
metadata + storage_path
```

- SQLite vẫn giữ metadata cục bộ.
- Firebase Storage lưu bytes của file.
- Đăng nhập trên thiết bị khác **không tự đồng bộ metadata**.
- Firestore chỉ là bước mở rộng đề xuất, không trình bày như chức năng đã xong.

---

# 3. Bốn thành phần cốt lõi của DMS

| Thành phần | Hiện trạng trong repo | Vai trò / khả năng chuyển đổi |
|---|---|---|
| Frontend | Flutter: Dashboard, danh sách, tìm kiếm, chi tiết, form, tài khoản | UI chạy Android/Web; gọi service Firebase qua SDK. |
| Backend | Chưa có REST API hoặc Cloud Functions | Nghiệp vụ/kiểm tra ở client; không coi Firebase SDK là backend riêng. |
| Database | SQLite: `subjects`, `documents`, metadata và `storage_path` | Local-first; metadata chưa đồng bộ giữa thiết bị. Firestore là hướng mở rộng. |
| File Storage | Firebase Cloud Storage theo UID | Lưu bytes; Rules hạn chế UID, loại nội dung và 20 MiB. Bucket cần tạo/kiểm tra trên Console. |

---

# 4. Hạn chế truyền thống và thay đổi sau Cloud

| Hạ tầng truyền thống / cục bộ | Prototype hiện tại sau tích hợp |
|---|---|
| Dung lượng đĩa và I/O đặt giới hạn lên máy chủ/thiết bị | Tệp được chuyển tới object storage managed; metadata SQLite vẫn local. |
| Một máy lưu file có thể là điểm lỗi; backup do nhóm tự vận hành | Firebase quản lý hạ tầng file; ứng dụng vẫn cần chiến lược sao lưu metadata. |
| Truy cập từ xa cần VPN/chia sẻ file và tự quản quyền | UID + Storage Rules kiểm soát object; cần mạng và Firebase Console hoạt động. |
| Mở rộng dung lượng, cập nhật thiết bị và xử lý lỗi do đơn vị vận hành | Dịch vụ managed giảm phần việc hạ tầng, đổi lại phụ thuộc nhà cung cấp và usage. |
| CapEx ban đầu và chi phí vận hành cố định | Pay-as-you-go theo dịch vụ/usage; phải theo dõi billing, không bảo đảm luôn rẻ hơn. |

**Giới hạn còn lại:** metadata không đa thiết bị; không có Firestore/Backend riêng; SyncEngine dùng mock in-memory, không đồng bộ Cloud thật.

---

# 5. Chọn mô hình triển khai Cloud

- **Public Cloud:** nhanh triển khai, dịch vụ managed và tính phí theo usage; phụ thuộc nhà cung cấp/mạng.
- **Private Cloud:** kiểm soát hạ tầng cao hơn nhưng cần đội ngũ, máy chủ và vận hành riêng.
- **Hybrid Cloud (được chọn):** giữ Flutter + SQLite cục bộ, dùng Firebase Authentication và Cloud Storage trên Public Cloud.
- **Dịch vụ cụ thể:** Firebase Authentication (Google) + Cloud Storage for Firebase; Firestore chỉ là đề xuất cho metadata đa thiết bị.
- Lựa chọn này khớp code hiện tại; không tuyên bố đã xây AWS S3, Cloud Functions hay private backend.

---

# 6. Kiến trúc tích hợp và luồng dữ liệu

```text
Người dùng → Flutter (Android/Web) ↔ SQLite local
                      │
                      ├─ Google Sign-In → Firebase Authentication → UID
                      │
                      └─ file bytes → Storage Rules (UID, MIME, size)
                                      → Firebase Cloud Storage

SQLite lưu metadata + storage_path; Firestore chưa triển khai.
```

1. Người dùng đăng nhập Google; Auth trả về phiên và UID.
2. App chọn file, kiểm tra đăng nhập/định dạng/20 MiB.
3. Storage Rules kiểm tra owner UID, MIME và kích thước.
4. App lưu storage path và metadata cục bộ; khi mở, lấy URL tải xuống.

---

# 7. Firebase Console: tạo và chia sẻ project nhóm

1. Nhóm trưởng tạo/chọn project `cashew-study-docs-3afed`.
2. Mở **Project settings → Users and permissions** (hoặc Google Cloud IAM).
3. Mời thành viên bằng email Google; cấp đúng quyền cần dùng, không chia sẻ mật khẩu.
4. Thành viên đăng nhập Firebase CLI bằng tài khoản được mời: `firebase login`.
5. Xác nhận project nhìn thấy được: `firebase projects:list`.

**An toàn:** chỉ cấp quyền quản trị cho người cần cấu hình; thành viên còn lại dùng quyền tối thiểu để phát triển/demo.

---

# 8. Bật Google Authentication

1. Firebase Console → **Build → Authentication → Get started**.
2. **Sign-in method / Sign-in providers → Google → Enable**.
3. Chọn email hỗ trợ và **Save**.
4. Android: Firebase app package là `vn.edu.cashew.study_document_manager`.
5. Thêm SHA-1 debug/release phù hợp; lấy debug SHA-1 bằng `.\gradlew signingReport` trong thư mục `android`.
6. Web: Authentication settings → **Authorized domains**, thêm hostname chạy app (ví dụ `localhost`).
7. iOS hiện chưa được cấu hình trong mã nguồn; không demo Firebase trên iOS cho tới khi bổ sung cấu hình riêng.

---

# 9. Tạo Storage bucket an toàn

1. Firebase Console → **Build → Storage → Get started / Create bucket**.
2. Đọc yêu cầu billing/gói dịch vụ mà Console hiện hiển thị; không bật billing nếu chưa được chủ project đồng ý.
3. Chọn region phù hợp; region thường khó đổi sau khi tạo.
4. Thiết lập budget alert và theo dõi usage trước khi dùng file thật.
5. Giữ bucket riêng tư; không bật quyền đọc công khai.

**Chi phí phụ thuộc** dung lượng, thao tác upload/download, region, lưu lượng mạng và chính sách hiện hành. Budget alert cảnh báo, không phải giới hạn cứng.

---

# 10. Storage Rules và cấu hình trong ứng dụng

- Rules áp dụng đường dẫn `users/{uid}/documents/{documentId}/{fileId}/{fileName}`.
- Chỉ người đăng nhập có UID trùng `{uid}` được đọc/xóa object.
- Giới hạn request tối đa **20 MiB** và MIME thuộc PDF, Office hoặc TXT.
- MIME do client khai báo không xác minh nội dung thực tế; file rủi ro cần kiểm tra/quét phía tin cậy.
- Cấu hình Firebase nằm trong `lib/firebase_options.dart` và `android/app/google-services.json`; hiện hỗ trợ Android/Web.

Triển khai từ PowerShell tại thư mục `study_document_manager`:

```powershell
firebase deploy --only storage --project=cashew-study-docs-3afed
```

---

# 11. Luồng upload, mở và xóa

1. Người dùng đăng nhập Google; Firebase Auth cung cấp UID.
2. Chọn file hợp lệ; app kiểm tra đăng nhập, extension và giới hạn 20 MiB.
3. App upload bytes trực tiếp lên Storage, hiển thị tiến độ.
4. App ghi `storage_path` cùng metadata vào SQLite.
5. Khi mở, app lấy Download URL rồi mở file; URL token là bearer link, không chia sẻ ra ngoài.
6. Khi xóa, app xóa file Cloud trước rồi mới xóa bản ghi SQLite; lỗi Storage được báo và giữ lại metadata.

---

# 12. Bảo mật, chi phí và hiệu suất

**Bảo mật**
- Rules giới hạn theo UID; không nhúng mật khẩu hay service-account key vào app.
- Download URL có token có thể được dùng như liên kết truy cập; không chia sẻ.
- Firestore (nếu triển khai) cần Firestore Rules riêng; Storage Rules không bảo vệ Firestore.

**Chi phí và hiệu suất**
- Upload trực tiếp tới Storage, không phải đi qua server tự xây.
- File chưa có mạng không thể upload/mở từ Cloud; metadata local vẫn dùng được trên thiết bị đó.
- Theo dõi usage, region và budget; không ước lượng chi phí khi chưa có workload.
- Build/test không xác nhận Google provider, bucket, billing hoặc Storage Rules đang hoạt động trên project thật.

---

# 13. Kịch bản demo và tiêu chí hoàn tất

- [ ] Đăng nhập Google trên Android hoặc Chrome.
- [ ] Upload file PDF nhỏ hơn 20 MiB; thấy tiến độ hoàn tất.
- [ ] Firebase Console hiển thị object dưới đúng UID.
- [ ] Mở file từ màn hình chi tiết.
- [ ] Thử UID khác: không được đọc/xóa object.
- [ ] Thử file sai định dạng và file lớn hơn 20 MiB: app/Rules từ chối.
- [ ] Xóa tài liệu: object Storage và metadata SQLite đều được xử lý.

**Chỉ đánh dấu hoàn tất sau khi kiểm tra trên Firebase Console thật.**

---

# 14. Kết luận và tài liệu tham khảo

- Mã nguồn có Google Sign-In + Cloud Storage cho Android/Web; cần chạy thử Firebase Console thật trước khi kết luận luồng end-to-end thành công.
- Mô hình hiện tại: **Hybrid** (local SQLite + dịch vụ Public Cloud của Firebase).
- Bước tiếp theo nếu cần đa thiết bị: thiết kế Firestore, Rules, migration và đồng bộ/xung đột.

Tài liệu:
- Firebase Flutter setup: https://firebase.google.com/docs/flutter/setup
- Google Sign-In: https://firebase.google.com/docs/auth/flutter/federated-auth
- Cloud Storage Flutter: https://firebase.google.com/docs/storage/flutter/start
- Firebase Security Rules: https://firebase.google.com/docs/rules

**Nhóm 12 · Lớp 65KTPM · Câu hỏi?**
