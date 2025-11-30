@echo off
setlocal enabledelayedexpansion

echo.
echo ===========================================
echo === Wi-Fi AutoConfig Toggler v1.0 ===
echo ===========================================
echo Imagined by Tianist

set "count=0"
set "InterfaceList="

echo Detecting active Wi-Fi interfaces...
echo (Requires Administrator privileges for successful operation)

:: -----------------------------------------------------
:: 1. DISCOVER AND LIST WI-FI INTERFACES (Using In-Memory Pipe for Robustness)
:: -----------------------------------------------------

:: Use in-memory parsing by piping the output directly. The pipe MUST be escaped with ^.
for /f "tokens=1* delims=:" %%a in ('netsh wlan show interface ^| findstr /I "Name"') do (
    set "InterfaceNameRaw=%%b"
    
    :: Safely remove the single leading space that results from the "tokens=1* delims=:" split.
    set "InterfaceNameClean=!InterfaceNameRaw:~1!"
    
    :: Remove surrounding quotes.
    set "InterfaceNameClean=!InterfaceNameClean:"=!"

    if defined InterfaceNameClean (
        set /A count+=1
        :: Variable naming using Interface_!count! is correct for dynamic retrieval
        set "Interface_!count!=!InterfaceNameClean!"
        echo [!count!]: !InterfaceNameClean!
        set "InterfaceList=!InterfaceList! !count!"
    )
)

:: Handle case where no interfaces were found.
if !count! equ 0 (
    echo Error: No Wi-Fi interfaces were found, or script lacks permissions.
    pause
    goto :EOF
)

:: -----------------------------------------------------
:: 2. PROMPT FOR USER SELECTION
:: -----------------------------------------------------

:PromptUser
echo.
set "InterfaceName=" :: Clear the variable before accepting input
set /p "Choice=Enter the number of the interface to toggle (1 to !count!): "

:: Check if the input is a valid number within the discovered range
set "IsValid=0"
for %%i in (%InterfaceList%) do (
    if "!Choice!" equ "%%i" (
        set "IsValid=1"
    )
)

if "!IsValid!" equ "0" (
    echo Invalid choice. Please enter a number from the list above.
    goto :PromptUser
)

:: Retrieve the selected interface name using the validated 'Choice' number.
:: CRITICAL FIX: Use CALL to force double expansion, reliably retrieving the variable value.
call set "InterfaceName=%%Interface_!Choice!%%"

:: -----------------------------------------------------
:: 3. TOGGLE LOGIC (using the selected interface)
:: -----------------------------------------------------

echo.
echo Selected Interface: "!InterfaceName!"

:: CRITICAL SAFETY CHECK: Ensure the interface name was successfully retrieved.
if not defined InterfaceName (
    echo CRITICAL ERROR: Could not retrieve the interface name associated with choice !Choice!.
    pause
    goto :EOF
)

:: 3.1. Check the current Auto Configuration status using 'netsh wlan show settings'.
netsh wlan show settings | findstr /I /C:"!InterfaceName!" | findstr /I "enabled" >nul

:: 3.2. Use ERRORLEVEL to determine the result of the FINDSTR command.
if errorlevel 1 (
    :: --- Current Status is DISABLED (ERRORLEVEL 1) ---
    echo Status check indicates: DISABLED.
    echo Running command to ENABLE AutoConfig...
    netsh wlan set autoconfig enabled=yes interface="!InterfaceName!"
    if errorlevel 1 (
        echo.
        echo ERROR: Command failed. You MUST run this script as Administrator.
    ) else (
        echo Success: AutoConfig is now ENABLED. Computer state is Normal.
    )
) else (
    :: --- Current Status is ENABLED (ERRORLEVEL 0) ---
    echo Status check indicates: ENABLED.
    echo Running command to DISABLE AutoConfig...
    netsh wlan set autoconfig enabled=no interface="!InterfaceName!"
    if errorlevel 1 (
        echo.
        echo ERROR: Command failed. You MUST run this script as Administrator.
    ) else (
        echo Success: AutoConfig is now DISABLED. Computer state is Gaming.
    )
)

echo.
echo Operation complete.
pause
endlocal