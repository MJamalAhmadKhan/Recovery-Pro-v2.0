.386
.model flat, stdcall
option casemap:none

include \masm32\include\windows.inc
include \masm32\include\kernel32.inc
include \masm32\include\user32.inc
include \masm32\include\masm32.inc
include \masm32\include\advapi32.inc
include \masm32\include\comctl32.inc
includelib \masm32\lib\comctl32.lib

includelib \masm32\lib\kernel32.lib
includelib \masm32\lib\user32.lib
includelib \masm32\lib\masm32.lib
includelib \masm32\lib\advapi32.lib

.data
    ClassName       db "RecoveryGUIClass",0
    AppName         db "Recovery Pro",0
    ButtonText      db "START SCAN",0
    LabelText       db "Enter Drive Letter (e.g. D, E, H):",0
    StatusReady     db "Status: Ready to Scan",0
    StatusScanning  db " [STATUS] Scanning: %lu MB scanned...", 0
    StatusSaving    db " [SAVING] File %lu: Extracting...", 0 ; Simplified status
    
    szStatic        db "Static",0
    szEdit          db "Edit",0
    szButton        db "Button",0

    msgTitle        db "Advanced File Recovery v2.0",0
    msgSuccess      db "RECOVERY COMPLETE!",13,10,"Scanned: %lu MB",13,10,"Files recovered: %lu",0
    msgWarning      db "Confirm recovery from %c: drive? This is a read-only scan.",0
    msgError        db "Cannot access %c: drive. Ensure you are running as Admin.",0
    
    outputFolder    db 20 dup(?)
    volumePath      db 20 dup(?)
    backslash       db "\",0
    
    nameJPEG        db "image_%05lu.jpg",0
    namePNG         db "image_%05lu.png",0
    nameGIF         db "image_%05lu.gif",0
    nameBMP         db "image_%05lu.bmp",0
    namePDF         db "doc_%05lu.pdf",0
    nameDOCX        db "doc_%05lu.docx",0
    nameXLSX        db "doc_%05lu.xlsx",0
    nameZIP         db "archive_%05lu.zip",0
    nameRAR         db "archive_%05lu.rar",0
    
    SE_MANAGE_VOLUME_NAME db "SeManageVolumePrivilege",0
    BUFFER_SIZE     equ 4194304
    MAX_FILE_SIZE   equ 104857600

.data?
    hInstance       HINSTANCE ?
    hWnd            HWND ?
    hEdit           HWND ?  
    hStatus         HWND ?  
    hVolume         HANDLE ?
    hFile           HANDLE ?
    pBuffer         DWORD ?
    bytesRead       DWORD ?
    bytesWritten    DWORD ?
    totalMB         DWORD ?
    maxMB           DWORD ?
    filesFound      DWORD ?
    jpegCount       DWORD ?
    pngCount        DWORD ?
    gifCount        DWORD ?
    bmpCount        DWORD ?
    pdfCount        DWORD ?
    docxCount       DWORD ?
    xlsxCount       DWORD ?
    zipCount        DWORD ?
    rarCount        DWORD ?
    imageCount      DWORD ?
    docCount        DWORD ?
    archiveCount    DWORD ?
    currentOffset   LARGE_INTEGER <>
    diskSize        LARGE_INTEGER <>
    driveLetter     db ?
    fileNameBuf     db 300 dup(?)
    tempName        db 256 dup(?)
    msgBuffer       db 1024 dup(?)

.code

start:
    invoke InitCommonControls 
    invoke GetModuleHandle, NULL
    mov hInstance, eax
    call WinMain
    invoke ExitProcess, eax

WinMain proc
    LOCAL wc:WNDCLASSEX
    LOCAL msg:MSG
    mov wc.cbSize, sizeof WNDCLASSEX
    mov wc.style, CS_HREDRAW or CS_VREDRAW
    mov wc.lpfnWndProc, offset WndProc
    mov wc.cbClsExtra, NULL
    mov wc.cbWndExtra, NULL
    push hInstance
    pop wc.hInstance
    mov wc.hbrBackground, COLOR_BTNFACE+1
    mov wc.lpszMenuName, NULL
    mov wc.lpszClassName, offset ClassName
    invoke LoadIcon, NULL, IDI_APPLICATION
    mov wc.hIcon, eax
    mov wc.hIconSm, eax
    invoke LoadCursor, NULL, IDC_ARROW
    mov wc.hCursor, eax
    invoke RegisterClassEx, addr wc
    invoke CreateWindowEx, WS_EX_CLIENTEDGE, addr ClassName, addr AppName, \
            WS_OVERLAPPED or WS_CAPTION or WS_SYSMENU or WS_MINIMIZEBOX, \
            CW_USEDEFAULT, CW_USEDEFAULT, 420, 260, NULL, NULL, hInstance, NULL ; Adjusted height
    mov hWnd, eax
    invoke ShowWindow, hWnd, SW_SHOWNORMAL
    invoke UpdateWindow, hWnd
    .while TRUE
        invoke GetMessage, addr msg, NULL, 0, 0
        .break .if (!eax)
        invoke TranslateMessage, addr msg
        invoke DispatchMessage, addr msg
    .endw
    mov eax, msg.wParam
    ret
WinMain endp

WndProc proc hWin:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM
    .if uMsg == WM_CREATE
        invoke CreateWindowEx, NULL, addr szStatic, addr LabelText, \
                WS_CHILD or WS_VISIBLE, 20, 20, 300, 20, hWin, 0, hInstance, NULL
        invoke CreateWindowEx, WS_EX_CLIENTEDGE, addr szEdit, NULL, \
                WS_CHILD or WS_VISIBLE or ES_UPPERCASE or ES_CENTER, 20, 45, 60, 25, hWin, 1, hInstance, NULL
        mov hEdit, eax
        invoke CreateWindowEx, NULL, addr szButton, addr ButtonText, \
                WS_CHILD or WS_VISIBLE, 20, 90, 150, 40, hWin, 2, hInstance, NULL
        invoke CreateWindowEx, NULL, addr szStatic, addr StatusReady, \
                WS_CHILD or WS_VISIBLE, 20, 150, 350, 40, hWin, 3, hInstance, NULL
        mov hStatus, eax

    .elseif uMsg == WM_COMMAND
        mov eax, wParam
        .if ax == 2
            call StartRecoveryProcess
        .endif
    .elseif uMsg == WM_DESTROY
        invoke PostQuitMessage, NULL
    .else
        invoke DefWindowProc, hWin, uMsg, wParam, lParam
        ret
    .endif
    xor eax, eax
    ret
WndProc endp

StartRecoveryProcess proc
    LOCAL input[4]:BYTE
    invoke GetWindowText, hEdit, addr input, 2
    mov al, input[0]
    .if al < 'A' || al > 'Z'
        .if al >= 'a' && al <= 'z'
            sub al, 32
        .else
            invoke MessageBox, hWnd, addr szEdit, addr AppName, MB_OK or MB_ICONERROR
            ret
        .endif
    .endif
    mov driveLetter, al
    invoke wsprintf, addr msgBuffer, addr msgWarning, driveLetter
    invoke MessageBox, hWnd, addr msgBuffer, addr AppName, MB_YESNO or MB_ICONQUESTION
    .if eax == IDNO
        ret
    .endif
    lea edi, volumePath
    mov byte ptr [edi], '\'
    mov byte ptr [edi+1], '\'
    mov byte ptr [edi+2], '.'
    mov byte ptr [edi+3], '\'
    mov al, driveLetter
    mov byte ptr [edi+4], al
    mov byte ptr [edi+5], ':'
    mov byte ptr [edi+6], 0
    lea edi, outputFolder
    mov dword ptr [edi], 'r' + ('e' shl 8) + ('c' shl 16) + ('o' shl 24)
    mov dword ptr [edi+4], 'v' + ('e' shl 8) + ('r' shl 16) + ('e' shl 24)
    mov word ptr [edi+8], 'd' + ('_' shl 8)
    mov al, driveLetter
    mov byte ptr [edi+10], al
    mov byte ptr [edi+11], 0
    invoke GlobalAlloc, GMEM_FIXED, BUFFER_SIZE
    mov pBuffer, eax
    call EnableVolumePrivileges
    invoke CreateDirectory, addr outputFolder, NULL
    invoke CreateFile, addr volumePath, GENERIC_READ, FILE_SHARE_READ or FILE_SHARE_WRITE,
            NULL, OPEN_EXISTING, 0, NULL
    .if eax == INVALID_HANDLE_VALUE
        invoke GlobalFree, pBuffer
        invoke wsprintf, addr msgBuffer, addr msgError, driveLetter
        invoke MessageBox, hWnd, addr msgBuffer, addr AppName, MB_OK or MB_ICONERROR
        ret
    .endif
    mov hVolume, eax
    mov filesFound, 0
    mov totalMB, 0
    mov currentOffset.LowPart, 0
    mov currentOffset.HighPart, 0
    call RecoverFiles
    invoke wsprintf, addr msgBuffer, addr msgSuccess, totalMB, filesFound
    invoke MessageBox, hWnd, addr msgBuffer, addr AppName, MB_OK or MB_ICONINFORMATION
    invoke CloseHandle, hVolume
    invoke GlobalFree, pBuffer
    ret
StartRecoveryProcess endp

RecoverFiles proc
    local lowPart:DWORD
    local highPart:DWORD
    invoke GetDiskFreeSpaceEx, addr volumePath, NULL, addr diskSize, NULL
    mov eax, diskSize.LowPart
    shr eax, 20
    .if eax > 102400
        mov maxMB, 102400
    .else
        .if eax < 100
            mov maxMB, 100
        .else
            mov maxMB, eax
        .endif
    .endif
ScanLoop:
    mov eax, totalMB
    cmp eax, maxMB
    jae ScanComplete
    invoke wsprintf, addr msgBuffer, addr StatusScanning, totalMB
    invoke SetWindowText, hStatus, addr msgBuffer
    mov eax, currentOffset.LowPart
    mov edx, currentOffset.HighPart
    mov lowPart, eax
    mov highPart, edx
    invoke SetFilePointer, hVolume, lowPart, addr highPart, FILE_BEGIN
    invoke ReadFile, hVolume, pBuffer, BUFFER_SIZE, addr bytesRead, NULL
    .if eax == 0 || bytesRead == 0
        jmp ScanComplete
    .endif
    call ScanForSignatures
    mov eax, BUFFER_SIZE
    add currentOffset.LowPart, eax
    adc dword ptr currentOffset.HighPart, 0
    mov eax, currentOffset.LowPart
    shr eax, 20
    mov edx, currentOffset.HighPart
    shl edx, 12
    add eax, edx
    mov totalMB, eax
    jmp ScanLoop
ScanComplete:
    ret
RecoverFiles endp

ScanForSignatures proc
    local bufPos:DWORD
    mov bufPos, 0
CheckNextPosition:
    mov eax, bufPos
    mov ebx, bytesRead
    sub ebx, 16
    cmp eax, ebx
    jae EndScan
    mov esi, pBuffer
    add esi, bufPos
    cmp byte ptr [esi], 0FFh
    jne CheckPNG
    cmp byte ptr [esi+1], 0D8h
    jne CheckPNG
    cmp byte ptr [esi+2], 0FFh
    jne CheckPNG
    mov eax, bufPos
    mov ebx, 1
    call RecoverFile
    add bufPos, 512
    jmp CheckNextPosition
CheckPNG:
    mov esi, pBuffer
    add esi, bufPos
    cmp byte ptr [esi], 89h
    jne CheckGIF
    cmp byte ptr [esi+1], 50h
    jne CheckGIF
    cmp byte ptr [esi+2], 4Eh
    jne CheckGIF
    cmp byte ptr [esi+3], 47h
    jne CheckGIF
    mov eax, bufPos
    mov ebx, 2
    call RecoverFile
    add bufPos, 512
    jmp CheckNextPosition
CheckGIF:
    mov esi, pBuffer
    add esi, bufPos
    cmp byte ptr [esi], 47h
    jne CheckBMP
    cmp byte ptr [esi+1], 49h
    jne CheckBMP
    cmp byte ptr [esi+2], 46h
    jne CheckBMP
    cmp byte ptr [esi+3], 38h
    jne CheckBMP
    mov eax, bufPos
    mov ebx, 3
    call RecoverFile
    add bufPos, 512
    jmp CheckNextPosition
CheckBMP:
    mov esi, pBuffer
    add esi, bufPos
    cmp byte ptr [esi], 42h
    jne CheckPDF
    cmp byte ptr [esi+1], 4Dh
    jne CheckPDF
    mov eax, bufPos
    mov ebx, 4
    call RecoverFile
    add bufPos, 512
    jmp CheckNextPosition
CheckPDF:
    mov esi, pBuffer
    add esi, bufPos
    cmp byte ptr [esi], 25h
    jne CheckDOCX
    cmp byte ptr [esi+1], 50h
    jne CheckDOCX
    cmp byte ptr [esi+2], 44h
    jne CheckDOCX
    cmp byte ptr [esi+3], 46h
    jne CheckDOCX
    mov eax, bufPos
    mov ebx, 5
    call RecoverFile
    add bufPos, 512
    jmp CheckNextPosition
CheckDOCX:
    mov esi, pBuffer
    add esi, bufPos
    cmp byte ptr [esi], 50h
    jne CheckRAR
    cmp byte ptr [esi+1], 4Bh
    jne CheckRAR
    cmp byte ptr [esi+2], 03h
    jne CheckRAR
    cmp byte ptr [esi+3], 04h
    jne CheckRAR
    mov eax, bufPos
    call IdentifyZipType
    call RecoverFile
    add bufPos, 512
    jmp CheckNextPosition
CheckRAR:
    mov esi, pBuffer
    add esi, bufPos
    cmp byte ptr [esi], 52h
    jne NextPosition 
    cmp byte ptr [esi+1], 61h
    jne NextPosition
    cmp byte ptr [esi+2], 72h
    jne NextPosition
    cmp byte ptr [esi+3], 21h
    jne NextPosition
    mov eax, bufPos
    mov ebx, 9
    call RecoverFile
    add bufPos, 512
    jmp CheckNextPosition
NextPosition:
    add bufPos, 16
    jmp CheckNextPosition
EndScan:
    ret
ScanForSignatures endp

IdentifyZipType proc
    local pos:DWORD
    mov pos, eax
    mov esi, pBuffer
    add esi, pos
    add esi, 30
    mov ecx, 100
SearchLoop:
    cmp byte ptr [esi], 'w'
    jne TryXLSX
    cmp byte ptr [esi+1], 'o'
    jne TryXLSX
    cmp byte ptr [esi+2], 'r'
    jne TryXLSX
    cmp byte ptr [esi+3], 'd'
    jne TryXLSX
    cmp byte ptr [esi+4], '/'
    jne TryXLSX
    mov ebx, 6
    ret
TryXLSX:
    cmp byte ptr [esi], 'x'
    jne TryZIP
    cmp byte ptr [esi+1], 'l'
    jne TryZIP
    cmp byte ptr [esi+2], '/'
    jne TryZIP
    mov ebx, 7
    ret
TryZIP:
    inc esi
    loop SearchLoop
    mov ebx, 8
    ret
IdentifyZipType endp

RecoverFile proc
    local bufferPos:DWORD
    local fileType:DWORD
    local namePtr:DWORD
    local maxSize:DWORD
    local count:DWORD
    local actualSize:DWORD
    local remaining:DWORD
    local offsetLow:DWORD
    local offsetHigh:DWORD
    local bytesSaved:DWORD

    mov bufferPos, eax
    mov fileType, ebx
    
    mov maxSize, 10485760 
    .if fileType == 5
        mov maxSize, 31457280 
    .elseif fileType >= 8
        mov maxSize, MAX_FILE_SIZE
    .endif

    mov esi, pBuffer
    add esi, bufferPos
    mov actualSize, 0

    .if fileType == 1 
        mov edi, esi
        add edi, 2
        mov ecx, bytesRead
        sub ecx, bufferPos
        sub ecx, 2
JPEGScan:
        cmp ecx, 0
        jle NoSizeParsed
        cmp byte ptr [edi], 0FFh
        jne NextJPEG
        cmp byte ptr [edi+1], 0D9h
        je FoundJPEGEnd
NextJPEG:
        inc edi
        dec ecx
        jmp JPEGScan
FoundJPEGEnd:
        mov eax, edi
        sub eax, esi
        add eax, 2
        mov actualSize, eax
    .elseif fileType == 2 
        mov edi, esi
        add edi, 8
        mov ecx, bytesRead
        sub ecx, bufferPos
        sub ecx, 8
PNGScan:
        cmp ecx, 0
        jle NoSizeParsed
        cmp byte ptr [edi], 49h
        jne NextPNG
        cmp byte ptr [edi+1], 45h
        jne NextPNG
        cmp byte ptr [edi+2], 4Eh
        jne NextPNG
        cmp byte ptr [edi+3], 44h
        je FoundPNGEnd
NextPNG:
        inc edi
        dec ecx
        jmp PNGScan
FoundPNGEnd:
        mov eax, edi
        sub eax, esi
        add eax, 12
        mov actualSize, eax
    .endif

NoSizeParsed:
    mov eax, actualSize
    .if eax == 0
        mov eax, bytesRead
        sub eax, bufferPos
        mov actualSize, eax
    .endif
    mov eax, maxSize
    .if actualSize > eax
        mov actualSize, eax
    .endif

    .if fileType == 1
        inc dword ptr [jpegCount]
        mov eax, [jpegCount]
        mov count, eax
        lea eax, nameJPEG
        inc dword ptr [imageCount]
    .elseif fileType == 2
        inc dword ptr [pngCount]
        mov eax, [pngCount]
        mov count, eax
        lea eax, namePNG
        inc dword ptr [imageCount]
    .elseif fileType == 3
        inc dword ptr [gifCount]
        mov eax, [gifCount]
        mov count, eax
        lea eax, nameGIF
        inc dword ptr [imageCount]
    .elseif fileType == 4
        inc dword ptr [bmpCount]
        mov eax, [bmpCount]
        mov count, eax
        lea eax, nameBMP
        inc dword ptr [imageCount]
    .elseif fileType == 5
        inc dword ptr [pdfCount]
        mov eax, [pdfCount]
        mov count, eax
        lea eax, namePDF
        inc dword ptr [docCount]
    .elseif fileType == 6
        inc dword ptr [docxCount]
        mov eax, [docxCount]
        mov count, eax
        lea eax, nameDOCX
        inc dword ptr [docCount]
    .elseif fileType == 7
        inc dword ptr [xlsxCount]
        mov eax, [xlsxCount]
        mov count, eax
        lea eax, nameXLSX
        inc dword ptr [docCount]
    .elseif fileType == 8
        inc dword ptr [zipCount]
        mov eax, [zipCount]
        mov count, eax
        lea eax, nameZIP
        inc dword ptr [archiveCount]
    .elseif fileType == 9
        inc dword ptr [rarCount]
        mov eax, [rarCount]
        mov count, eax
        lea eax, nameRAR
        inc dword ptr [archiveCount]
    .else
        ret
    .endif

    mov namePtr, eax
    invoke wsprintf, addr tempName, namePtr, count
    invoke lstrcpy, addr fileNameBuf, addr outputFolder
    invoke lstrcat, addr fileNameBuf, addr backslash
    invoke lstrcat, addr fileNameBuf, addr tempName
    invoke CreateFile, addr fileNameBuf, GENERIC_WRITE, 0, NULL, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL
    .if eax == INVALID_HANDLE_VALUE
        ret
    .endif
    mov hFile, eax

    mov eax, bytesRead
    sub eax, bufferPos
    mov edx, actualSize
    .if eax > edx
        mov eax, edx
    .endif
    mov bytesWritten, eax
    mov eax, pBuffer
    add eax, bufferPos
    invoke WriteFile, hFile, eax, bytesWritten, addr bytesWritten, NULL
    
    mov eax, bytesWritten
    mov bytesSaved, eax 
    
    mov eax, actualSize
    sub eax, bytesWritten
    mov remaining, eax

    mov eax, currentOffset.LowPart
    mov offsetLow, eax
    mov eax, currentOffset.HighPart
    mov offsetHigh, eax

    .while remaining > 0
        mov eax, BUFFER_SIZE
        add offsetLow, eax
        adc offsetHigh, 0 

        invoke SetFilePointer, hVolume, offsetLow, addr offsetHigh, FILE_BEGIN
        invoke ReadFile, hVolume, pBuffer, BUFFER_SIZE, addr bytesRead, NULL
        .if eax == 0 || bytesRead == 0
            .break
        .endif

        mov eax, bytesRead
        .if eax > remaining
            mov eax, remaining
        .endif
        invoke WriteFile, hFile, pBuffer, eax, addr bytesWritten, NULL
        
        mov eax, bytesWritten
        add bytesSaved, eax
        sub remaining, eax

        ; Update GUI Status text only (Progress bar calls removed)
        invoke wsprintf, addr msgBuffer, addr StatusSaving, filesFound
        invoke SetWindowText, hStatus, addr msgBuffer
    .endw

    invoke CloseHandle, hFile
    inc dword ptr [filesFound]
    ret
RecoverFile endp

EnableVolumePrivileges proc
    local hToken:HANDLE
    local tkp:TOKEN_PRIVILEGES
    invoke OpenProcessToken, -1, TOKEN_ADJUST_PRIVILEGES or TOKEN_QUERY, addr hToken
    .if eax == 0
        ret
    .endif
    invoke LookupPrivilegeValue, NULL, addr SE_MANAGE_VOLUME_NAME, addr tkp.Privileges[0].Luid
    mov tkp.PrivilegeCount, 1
    mov tkp.Privileges[0].Attributes, SE_PRIVILEGE_ENABLED
    invoke AdjustTokenPrivileges, hToken, FALSE, addr tkp, sizeof tkp, NULL, NULL
    invoke CloseHandle, hToken
    ret
EnableVolumePrivileges endp

end start