---
marp: true
theme: default
paginate: true
---

# Firebase cho ứng dụng Quản lý Tài liệu

## Google Sign-In · Cloud Storage · Thiết lập tài khoản nhóm

**Dự án:** Study Document Manager
**Firebase project:** `cashew-study-docs-3afed`
**Nhóm:** [Điền tên nhóm] · **Thành viên:** [Điền tên thành viên]

---

# 1. Firebase là gì?

- Nền tảng Backend-as-a-Service của Google, cung cấp dịch vụ cloud quản lý sẵn.
- Firebase Authentication: xác thực người dùng, tích hợp Google.
- Cloud Storage for Firebase: lưu file; Firebase Security Rules kiểm soát quyền.
- Cloud Firestore: cơ sở dữ liệu document; có thể dùng cho metadata và đồng bộ đa thiết bị.
- Firebase Console: quản lý project, ứng dụng, Authentication, Storage, Rules và usage.

**Trong prototype:** Authentication + Storage đã có trong code. Firestore chưa tích hợp.

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

# 3. Firebase Console: tạo và chia sẻ project nhóm

1. Nhóm trưởng tạo/chọn project `cashew-study-docs-3afed`.
2. Mở **Project settings → Users and permissions** (hoặc Google Cloud IAM).
3. Mời thành viên bằng email Google; cấp đúng quyền cần dùng, không chia sẻ mật khẩu.
4. Thành viên đăng nhập Firebase CLI bằng tài khoản được mời: `firebase login`.
5. Xác nhận project nhìn thấy được: `firebase projects:list`.

**An toàn:** chỉ cấp quyền quản trị cho người cần cấu hình; thành viên còn lại dùng quyền tối thiểu để phát triển/demo.

---

# 4. Bật Google Authentication

1. Firebase Console → **Build → Authentication → Get started**.
2. **Sign-in method / Sign-in providers → Google → Enable**.
3. Chọn email hỗ trợ và **Save**.
4. Android: Firebase app package là `vn.edu.cashew.study_document_manager`.
5. Thêm SHA-1 debug/release phù hợp; lấy debug SHA-1 bằng `.\gradlew signingReport` trong thư mục `android`.
6. Web: Authentication settings → **Authorized domains**, thêm hostname chạy app (ví dụ `localhost`).
7. iOS: xác nhận Bundle ID và URL scheme Google trong `ios/Runner/Info.plist`.

---

# 5. Tạo Storage bucket an toàn

1. Firebase Console → **Build → Storage → Get started / Create bucket**.
2. Xem yêu cầu billing/gói dịch vụ đang hiển thị; Cloud Storage có thể cần Blaze.
3. Chọn region phù hợp; region thường khó đổi sau khi tạo.
4. Thiết lập budget alert và theo dõi usage trước khi dùng file thật.
5. Giữ bucket riêng tư; không bật quyền đọc công khai.

**Chi phí phụ thuộc** dung lượng, thao tác upload/download, region, lưu lượng mạng và chính sách hiện hành. Budget alert cảnh báo, không phải giới hạn cứng.

---

# 6. Storage Rules và cấu hình trong ứng dụng

- Rules áp dụng đường dẫn `users/{uid}/documents/{documentId}/{fileId}/{fileName}`.
- Chỉ người đăng nhập có UID trùng `{uid}` được đọc/xóa object.
- Giới hạn request tối đa **20 MiB** và MIME thuộc PDF, Office hoặc TXT.
- MIME do client khai báo không xác minh nội dung thực tế; file rủi ro cần kiểm tra/quét phía tin cậy.
- Cấu hình Firebase nằm trong `lib/firebase_options.dart` và file native tương ứng.

Triển khai từ PowerShell tại thư mục `study_document_manager`:

```powershell
firebase deploy --only storage --project=cashew-study-docs-3afed
```

---

# 7. Luồng upload, mở và xóa

1. Người dùng đăng nhập Google; Firebase Auth cung cấp UID.
2. Chọn file hợp lệ; app kiểm tra đăng nhập, extension và giới hạn 20 MiB.
3. App upload bytes trực tiếp lên Storage, hiển thị tiến độ.
4. App ghi `storage_path` cùng metadata vào SQLite.
5. Khi mở, app lấy Download URL rồi mở file; URL token là bearer link, không chia sẻ ra ngoài.
6. Khi xóa, app xóa file Cloud trước rồi mới xóa bản ghi SQLite; lỗi Storage được báo và giữ lại metadata.

---

# 8. Bảo mật, chi phí và hiệu suất

**Bảo mật**
- Rules giới hạn theo UID; không nhúng mật khẩu hay service-account key vào app.
- Download URL có token có thể được dùng như liên kết truy cập; không chia sẻ.
- Firestore (nếu triển khai) cần Firestore Rules riêng; Storage Rules không bảo vệ Firestore.

**Chi phí và hiệu suất**
- Upload trực tiếp tới Storage, không phải đi qua server tự xây.
- File chưa có mạng không thể upload/mở từ Cloud; metadata local vẫn dùng được trên thiết bị đó.
- Theo dõi usage, region và budget; không ước lượng chi phí khi chưa có workload.

---

# 9. Kịch bản demo và tiêu chí hoàn tất

- [ ] Đăng nhập Google trên Android hoặc Chrome.
- [ ] Upload file PDF nhỏ hơn 20 MiB; thấy tiến độ hoàn tất.
- [ ] Firebase Console hiển thị object dưới đúng UID.
- [ ] Mở file từ màn hình chi tiết.
- [ ] Thử UID khác: không được đọc/xóa object.
- [ ] Thử file sai định dạng và file lớn hơn 20 MiB: app/Rules từ chối.
- [ ] Xóa tài liệu: object Storage và metadata SQLite đều được xử lý.

**Chỉ đánh dấu hoàn tất sau khi kiểm tra trên Firebase Console thật.**

---

# 10. Kết luận và tài liệu tham khảo

- Prototype đáp ứng Google Sign-In + Cloud Storage; metadata vẫn SQLite local.
- Mô hình hiện tại: **Hybrid** (local SQLite + dịch vụ Public Cloud của Firebase).
- Bước tiếp theo nếu cần đa thiết bị: thiết kế Firestore, Rules, migration và đồng bộ/xung đột.

Tài liệu:
- Firebase Flutter setup: https://firebase.google.com/docs/flutter/setup
- Google Sign-In: https://firebase.google.com/docs/auth/flutter/federated-auth
- Cloud Storage Flutter: https://firebase.google.com/docs/storage/flutter/start
- Firebase Security Rules: https://firebase.google.com/docs/rules

**Nhóm:** [Điền tên nhóm] · **Câu hỏi?**
