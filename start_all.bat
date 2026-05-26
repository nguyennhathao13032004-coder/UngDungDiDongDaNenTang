@echo off
chcp 65001 >nul
title SaHaBa Health - Start All Services

echo.
echo ╔══════════════════════════════════════════════════════╗
echo ║          SAHABA HEALTH - KHỞI ĐỘNG HỆ THỐNG         ║
echo ╚══════════════════════════════════════════════════════╝
echo.

REM ============================================================
REM #NOTE - COPY CÁC LỆNH NÀY NẾU CẦN CHẠY THỦ CÔNG:
REM
REM [1] Python AI Service (port 8000):
REM     cd D:\UngDungDiDongDaNenTang\saha_ai_service
REM     venv\Scripts\activate
REM     python main.py
REM
REM [2] ASP.NET Core API (port 5188):
REM     cd D:\UngDungDiDongDaNenTang\SaHaBaHealth.Api
REM     dotnet run
REM
REM [3] Flutter Web (port tự động):
REM     cd D:\UngDungDiDongDaNenTang\sahaba_health_app
REM     flutter run -d chrome
REM ============================================================

echo [INFO] Kiểm tra thư mục các project...
echo.

REM --- Kiểm tra thư mục tồn tại ---
set BASE=D:\UngDungDiDongDaNenTang
set AI_DIR=%BASE%\saha_ai_service
set API_DIR=%BASE%\SaHaBaHealth.Api
set APP_DIR=%BASE%\sahaba_health_app

if not exist "%AI_DIR%" (
    echo [LỖI] Không tìm thấy: %AI_DIR%
    pause
    exit /b 1
)
if not exist "%API_DIR%" (
    echo [LỖI] Không tìm thấy: %API_DIR%
    pause
    exit /b 1
)
if not exist "%APP_DIR%" (
    echo [LỖI] Không tìm thấy: %APP_DIR%
    pause
    exit /b 1
)

echo [OK] Tất cả thư mục đã sẵn sàng.
echo.

REM ============================================================
REM [1] KHỞI ĐỘNG PYTHON AI SERVICE
REM ============================================================
echo [1/3] Đang khởi động Python AI Service (localhost:8000)...

if not exist "%AI_DIR%\venv\Scripts\activate.bat" (
    echo [LỖI] Không tìm thấy venv tại %AI_DIR%\venv
    echo       Chạy lệnh: python -m venv venv rồi thử lại.
    pause
    exit /b 1
)

if not exist "%AI_DIR%\main.py" (
    echo [LỖI] Không tìm thấy main.py tại %AI_DIR%
    pause
    exit /b 1
)

start " AI Service - Port 8000" cmd /k "^
    cd /d %AI_DIR% ^&^& ^
    echo [AI] Đang kích hoạt môi trường ảo... ^&^& ^
    call venv\Scripts\activate ^&^& ^
    echo [AI] Môi trường ảo OK. ^&^& ^
    echo [AI] Khởi động Python FastAPI... ^&^& ^
    python main.py ^|^| ^
    (echo [LỖI AI] Server bị lỗi! Kiểm tra lại .env và requirements. ^&^& pause)"

echo [OK] Đã mở cửa sổ AI Service.
timeout /t 3 /nobreak >nul

REM ============================================================
REM [2] KHỞI ĐỘNG ASPNET CORE API
REM ============================================================
echo [2/3] Đang khởi động ASP.NET Core API (localhost:5188)...

if not exist "%API_DIR%\*.csproj" (
    if not exist "%API_DIR%\*.sln" (
        echo [CẢNH BÁO] Không tìm thấy file .csproj hoặc .sln tại %API_DIR%
        echo            Vẫn thử chạy dotnet run...
    )
)

start " ASP.NET Core API - Port 5188" cmd /k "^
    cd /d %API_DIR% ^&^& ^
    echo [API] Đang build và khởi động ASP.NET Core... ^&^& ^
    dotnet run ^|^| ^
    (echo [LỖI API] dotnet run thất bại! Kiểm tra lại project. ^&^& pause)"

echo [OK] Đã mở cửa sổ ASP.NET Core API.
timeout /t 3 /nobreak >nul

REM ============================================================
REM [3] KHỞI ĐỘNG FLUTTER WEB
REM ============================================================
echo [3/3] Đang khởi động Flutter Web...

if not exist "%APP_DIR%\pubspec.yaml" (
    echo [LỖI] Không tìm thấy pubspec.yaml tại %APP_DIR%
    pause
    exit /b 1
)

start " Flutter Web App" cmd /k "^
    cd /d %APP_DIR% ^&^& ^
    echo [FLUTTER] Đang chạy flutter pub get... ^&^& ^
    flutter pub get ^&^& ^
    echo [FLUTTER] Khởi động trên Chrome... ^&^& ^
    flutter run -d chrome ^|^| ^
    (echo [LỖI FLUTTER] flutter run thất bại! Chạy flutter doctor để kiểm tra. ^&^& pause)"

echo [OK] Đã mở cửa sổ Flutter Web.
echo.

REM ============================================================
REM THÔNG BÁO HOÀN TẤT
REM ============================================================
echo ╔══════════════════════════════════════════════════════╗
echo ║                  KHỞI ĐỘNG XONG!                    ║
echo ╠══════════════════════════════════════════════════════╣
echo ║   AI Service  : http://localhost:8000              ║
echo ║   AI Docs     : http://localhost:8000/docs         ║
echo ║    ASP.NET API : http://localhost:5188              ║
echo ║   Flutter     : http://localhost:[port tự động]    ║
echo ╠══════════════════════════════════════════════════════╣
echo ║  Chờ khoảng 10-15 giây để tất cả sẵn sàng...        ║
echo ║  Đóng cửa sổ này KHÔNG ảnh hưởng các service.       ║
echo ╚══════════════════════════════════════════════════════╝
echo.
pause
