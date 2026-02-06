@echo off
setlocal enabledelayedexpansion

cd /d "%~dp0"

REM Locate jar tool
set "JAR_CMD="
for /f "delims=" %%I in ('where jar 2^>nul') do (
    if not defined JAR_CMD set "JAR_CMD=%%~fI"
)

if not defined JAR_CMD (
    if defined JAVA_HOME if exist "%JAVA_HOME%\bin\jar.exe" (
        set "JAR_CMD=%JAVA_HOME%\bin\jar.exe"
    )
)

if not defined JAR_CMD (
    for /d %%D in ("%ProgramFiles%\Microsoft\jdk*") do (
        if exist "%%D\bin\jar.exe" set "JAR_CMD=%%D\bin\jar.exe"
    )
)

if not defined JAR_CMD (
    for /d %%D in ("%ProgramFiles%\Java\jdk*") do (
        if exist "%%D\bin\jar.exe" set "JAR_CMD=%%D\bin\jar.exe"
    )
)

if not defined JAR_CMD (
    for /d %%D in ("%ProgramFiles%\Eclipse Adoptium\jdk*") do (
        if exist "%%D\bin\jar.exe" set "JAR_CMD=%%D\bin\jar.exe"
    )
)

if not defined JAR_CMD (
    for /d %%D in ("%ProgramFiles%\JetBrains\*") do (
        if exist "%%D\jbr\bin\jar.exe" set "JAR_CMD=%%D\jbr\bin\jar.exe"
    )
)

REM Package plugin
echo [1/2] Packaging IntelliJ plugin JAR...
if not exist "MonokaiVibrantAmped\resources\META-INF\plugin.xml" (
    echo [ERROR] Could not find MonokaiVibrantAmped\resources\META-INF\plugin.xml
    exit /b 1
)

set "TARGET_JAR=%~dp0MonokaiVibrantAmped\MonokaiVibrantAmped.jar"

if defined JAR_CMD (
    pushd "%~dp0MonokaiVibrantAmped\resources"
    "%JAR_CMD%" -cf "!TARGET_JAR!" META-INF theme
    set "BUILD_STATUS=!ERRORLEVEL!"
    popd
) else (
    echo [INFO] jar tool not found in PATH; using PowerShell archiver...
    powershell -NoProfile -Command ^
        "$src = Join-Path '%~dp0' 'MonokaiVibrantAmped\resources';" ^
        "$out = '!TARGET_JAR!';" ^
        "if (Test-Path $out) { Remove-Item $out -Force };" ^
        "Add-Type -AssemblyName System.IO.Compression.FileSystem;" ^
        "$zip = [System.IO.Compression.ZipFile]::Open($out, [System.IO.Compression.ZipArchiveMode]::Create);" ^
        "Get-ChildItem -Path $src -Recurse | Where-Object { -not $_.PSIsContainer } | ForEach-Object {" ^
        "  $rel = $_.FullName.Substring($src.Length + 1).Replace('\', '/');" ^
        "  [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $_.FullName, $rel);" ^
        "};" ^
        "$zip.Dispose();"
    set "BUILD_STATUS=!ERRORLEVEL!"
)

if %BUILD_STATUS% neq 0 (
    echo.
    echo [ERROR] Failed to package the plugin JAR.
    echo.
    exit /b %BUILD_STATUS%
)

echo Built: MonokaiVibrantAmped\MonokaiVibrantAmped.jar

REM Install plugin
echo.
echo [2/2] Installing into JetBrains IDEs...
set "INSTALLED_COUNT=0"
set "JETBRAINS_DIR=%APPDATA%\JetBrains"

if exist "%JETBRAINS_DIR%" (
    for /d %%D in ("%JETBRAINS_DIR%\*") do (
        set "IDE_NAME=%%~nxD"
        REM Skip non-IDE folders
        if /i not "!IDE_NAME!"=="consentOptions" if /i not "!IDE_NAME!"=="PrivacyPolicy" (
            set "PLUGIN_DEST=%%D\plugins\MonokaiVibrantAmped\lib"
            if not exist "!PLUGIN_DEST!" mkdir "!PLUGIN_DEST!" >nul 2>&1
            if exist "!PLUGIN_DEST!\MonokaiVibrantAmped.jar" (
                del /f /q "!PLUGIN_DEST!\MonokaiVibrantAmped.jar.old" >nul 2>&1
                ren "!PLUGIN_DEST!\MonokaiVibrantAmped.jar" "MonokaiVibrantAmped.jar.old" >nul 2>&1
            )
            copy /y "!TARGET_JAR!" "!PLUGIN_DEST!\MonokaiVibrantAmped.jar" >nul 2>&1
            if !ERRORLEVEL! equ 0 (
                set "COLORS_DEST=%%D\colors"
                if not exist "!COLORS_DEST!" mkdir "!COLORS_DEST!" >nul 2>&1
                copy /y "%~dp0MonokaiVibrantAmped\resources\theme\MonokaiVibrantAmped.xml" "!COLORS_DEST!\MonokaiVibrantAmped.xml" >nul 2>&1

                echo  - Installed into !IDE_NAME!
                set /a INSTALLED_COUNT+=1
            )
        )
    )
)

if %INSTALLED_COUNT% equ 0 goto :no_ides

echo.
echo Successfully installed into %INSTALLED_COUNT% JetBrains IDE installation(s)!
echo Restart your IDE (if running) and select 'Monokai Vibrant Amped' under:
echo   Settings -^> Appearance and Behavior -^> Appearance -^> Theme
goto :done

:no_ides
echo.
echo [INFO] No JetBrains IDE configuration folders were automatically found in %APPDATA%\JetBrains.
echo You can install manually in your IDE via:
echo   Settings -^> Plugins -^> Gear icon -^> Install Plugin from Disk...
echo   and select: %TARGET_JAR%

:done
