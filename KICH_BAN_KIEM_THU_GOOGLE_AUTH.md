# KỊCH BẢN KIỂM THỬ GOOGLE AUTHENTICATION

> **Người thực hiện:** Vũ Tuấn Khanh  
> **MSSV:** 2251172386  
> **Nhóm:** 12  
> **Nhánh Git:** `khanh-google-auth`  
> **Firebase Project:** `cashew-study-docs-3afed`

---

## 1. Mục tiêu kiểm thử

Kiểm tra luồng xác thực Google trong ứng dụng Quản lý tài liệu học tập, bao gồm:

- Hiển thị màn hình đăng nhập.
- Mở cửa sổ chọn tài khoản Google.
- Đăng nhập bằng tài khoản Google.
- Chuyển sang trang chính sau khi xác thực thành công.
- Duy trì trạng thái đăng nhập.
- Hủy thao tác đăng xuất.
- Đăng xuất khỏi ứng dụng.
- Quay lại màn hình đăng nhập sau khi đăng xuất.

---

## 2. Môi trường kiểm thử

| Thành phần | Thông tin |
|---|---|
| Hệ điều hành | Windows |
| Framework | Flutter |
| Nền tảng kiểm thử | Flutter Web |
| Trình duyệt | Google Chrome |
| Firebase Project | `cashew-study-docs-3afed` |
| Nhà cung cấp xác thực | Google |
| Nhánh Git | `khanh-google-auth` |

---

## 3. Danh sách Test Case

| ID | Chức năng | Các bước thực hiện | Kết quả mong đợi | Kết quả thực tế | Trạng thái |
|---|---|---|---|---|:---:|
| AUTH-01 | Hiển thị trang đăng nhập | Đăng xuất tài khoản rồi mở ứng dụng | Hiển thị LoginPage và nút đăng nhập Google | Trang đăng nhập hiển thị đúng | Đạt |
| AUTH-02 | Mở Google Sign-In | Nhấn nút Đăng nhập bằng Google | Hiển thị cửa sổ chọn tài khoản | Cửa sổ chọn tài khoản xuất hiện | Đạt |
| AUTH-03 | Đăng nhập hợp lệ | Chọn tài khoản Google hợp lệ | Xác thực thành công và chuyển đến HomePage | Ứng dụng chuyển đến trang chính | Đạt |
| AUTH-04 | Hiển thị nút đăng xuất | Quan sát thanh công cụ sau đăng nhập | Có biểu tượng đăng xuất | Biểu tượng đăng xuất hiển thị đúng | Đạt |
| AUTH-05 | Mở hộp thoại đăng xuất | Nhấn biểu tượng đăng xuất | Hiển thị hộp thoại xác nhận | Hộp thoại có nút Hủy và Đăng xuất | Đạt |
| AUTH-06 | Hủy đăng xuất | Trong hộp thoại chọn Hủy | Người dùng vẫn ở HomePage | Ứng dụng tiếp tục hiển thị HomePage | Đạt |
| AUTH-07 | Đăng xuất thành công | Nhấn đăng xuất rồi xác nhận | Kết thúc phiên và quay về LoginPage | Ứng dụng quay về trang đăng nhập | Đạt |
| AUTH-08 | Duy trì phiên | Đăng nhập rồi tải lại trang | Người dùng vẫn được xác định nếu phiên còn hiệu lực | Chưa kiểm tra | Chưa chạy |
| AUTH-09 | Xử lý mất mạng | Tắt mạng rồi thực hiện đăng nhập | Hiển thị lỗi mạng và ứng dụng không bị đóng | Chưa kiểm tra | Chưa chạy |

---

## 4. Ảnh minh chứng

| Tên tệp | Nội dung minh chứng |
|---|---|
| `screenshots/google_auth/01_login_page.png` | Màn hình đăng nhập Google |
| `screenshots/google_auth/02_google_account_picker.png` | Cửa sổ chọn tài khoản Google |
| `screenshots/google_auth/03_login_success.png` | Trang chính sau khi đăng nhập thành công |
| `screenshots/google_auth/04_logout_confirm.png` | Hộp thoại xác nhận đăng xuất |
| `screenshots/google_auth/05_logout_success.png` | Trang đăng nhập sau khi đăng xuất thành công |

---

## 5. Kết quả tổng hợp

- Tổng số test case: 9
- Số test case đạt: 7
- Số test case không đạt: 0
- Số test case chưa chạy: 2

### Lỗi hoặc giới hạn còn tồn tại

- SQLite WebAssembly chưa hoạt động ổn định trong môi trường kiểm thử.
- Ứng dụng tự động sử dụng chế độ In-Memory Fallback.
- Vấn đề SQLite Web không ảnh hưởng đến luồng Firebase Authentication.
- Kiểm thử Google Sign-In trên Android cần cấu hình SHA-1 trong Firebase Project.

### Kết luận

Luồng Google Authentication đã hoạt động trên Flutter Web. Người dùng có thể đăng nhập bằng tài khoản Google, truy cập trang chính, mở hộp thoại xác nhận đăng xuất và kết thúc phiên đăng nhập. `AuthGate` tự động cập nhật giao diện dựa trên trạng thái xác thực của Firebase.