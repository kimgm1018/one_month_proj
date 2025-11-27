@echo off
echo ========================================
echo Cursor Jupyter 수정 스크립트
echo ========================================
echo.

echo [1/5] Cursor 프로세스 종료 중...
taskkill /F /IM Cursor.exe >nul 2>&1
timeout /t 3 >nul
echo 완료

echo.
echo [2/5] Jupyter Extension 데이터 삭제 중...
if exist "%APPDATA%\Cursor\User\globalStorage\ms-toolsai.jupyter" (
    rmdir /s /q "%APPDATA%\Cursor\User\globalStorage\ms-toolsai.jupyter"
    echo 완료
) else (
    echo 이미 삭제됨
)

echo.
echo [3/5] 워크스페이스 캐시 삭제 중...
if exist "%APPDATA%\Cursor\User\workspaceStorage" (
    rmdir /s /q "%APPDATA%\Cursor\User\workspaceStorage"
    echo 완료
) else (
    echo 이미 삭제됨
)

echo.
echo [4/5] Jupyter 런타임 캐시 삭제 중...
if exist "%LOCALAPPDATA%\Jupyter\runtime" (
    rmdir /s /q "%LOCALAPPDATA%\Jupyter\runtime"
    echo 완료
) else (
    echo 이미 삭제됨
)

echo.
echo [5/5] 커널 등록 재시도...
"%~dp0myenv\Scripts\python.exe" -m ipykernel install --user --name=myenv_fixed --display-name="Python (myenv)"
echo 완료

echo.
echo ========================================
echo 모든 작업 완료!
echo Cursor를 다시 실행하고 노트북을 여세요.
echo ========================================
echo.
pause













