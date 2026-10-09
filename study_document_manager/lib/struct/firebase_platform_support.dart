import 'package:flutter/foundation.dart';

bool firebaseInitialized = false;

/// Firebase Auth/Storage are configured for Web and Android in this project.
bool get isFirebaseConfiguredPlatform =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android;

/// True khi Firebase đã khởi tạo thành công trên nền tảng được hỗ trợ.
bool get canUseFirebase => isFirebaseConfiguredPlatform && firebaseInitialized;

/// True khi có thể tải tệp lên Firebase Cloud Storage.
bool get canUploadToCloud => canUseFirebase;

/// True trên mọi nền tảng — luôn cho phép lưu đính kèm cục bộ trong bộ nhớ.
bool get canSaveLocalAttachment => true;
