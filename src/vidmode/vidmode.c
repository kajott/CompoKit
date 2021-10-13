#include <windows.h>

#ifndef NDEBUG
    #include <stdio.h>
    #define Dprintf printf
#else
    #define Dprintf(...) do{}while(0)
#endif

static void ShowInfo(void) {
    MessageBox(NULL,
        "vidmode is running in the background.\r\n\r\n"
        "To switch to 50 Hz mode, press [Ctrl] + [Win] + [Alt] + [5].\r\n"
        "To switch to 60 Hz mode, press [Ctrl] + [Win] + [Alt] + [6].\r\n\r\n"
        "Run vidmode.exe again to stop it.",
        "vidmode", MB_ICONINFORMATION);
}

static void SetRefresh(int rate) {
    Dprintf("Switching to %d Hz ...\n", rate);

    DEVMODE modes[2], current;
    DEVMODE *iter = &modes[0];
    DEVMODE *best = NULL;
    modes[0].dmSize = sizeof(current);  modes[0].dmDriverExtra = 0;
    modes[1].dmSize = sizeof(current);  modes[1].dmDriverExtra = 0;
    current.dmSize  = sizeof(current);  current.dmDriverExtra  = 0;

    if (!EnumDisplaySettings(NULL, ENUM_CURRENT_SETTINGS, &current)) {
        Dprintf("Failed to get current video mode.\n");
        return;
    }
    Dprintf("current mode: %dx%d, %d bpp, %d Hz\n", current.dmPelsWidth, current.dmPelsHeight, current.dmBitsPerPel, current.dmDisplayFrequency);

    int i = 0;
    while (EnumDisplaySettings(NULL, i, iter)) {
        if ((iter->dmPelsWidth  == current.dmPelsWidth)
        &&  (iter->dmPelsHeight == current.dmPelsHeight)
        &&  (iter->dmBitsPerPel == current.dmBitsPerPel)
        && (!best || (abs(iter->dmDisplayFrequency - rate) < abs(best->dmDisplayFrequency - rate)))) {
            DEVMODE *m = best ? best : &modes[1];
            best = iter;
            iter = m;
        }
        ++i;
    }
    if (!best) {
        Dprintf("%d modes checked, but nothing suitable found.\n", i);
        return;
    }
    Dprintf("%d modes checked, best match: %dx%d, %d bpp, %d Hz\n", i, best->dmPelsWidth, best->dmPelsHeight, best->dmBitsPerPel, best->dmDisplayFrequency);
    LONG res = ChangeDisplaySettings(best, CDS_UPDATEREGISTRY);
    switch (res) {
        case DISP_CHANGE_SUCCESSFUL:   Dprintf("Mode switch successful.\n"); break;
        case DISP_CHANGE_BADDUALVIEW:  Dprintf("Mode switch failed because of multi-monitor setup.\n"); break;
        case DISP_CHANGE_BADFLAGS:     Dprintf("Mode switch failed: invalid flags.\n"); break;
        case DISP_CHANGE_BADMODE:      Dprintf("Mode switch failed: invalid mode.\n"); break;
        case DISP_CHANGE_BADPARAM:     Dprintf("Mode switch failed: invalid parameter.\n"); break;
        case DISP_CHANGE_FAILED:       Dprintf("Mode switch failed: rejected by driver.\n"); break;
        case DISP_CHANGE_NOTUPDATED:   Dprintf("Mode switch succeeded, but could not update system settings.\n"); break;
        case DISP_CHANGE_RESTART:      Dprintf("Mode switch failed: restart required.\n"); break;
        default:                       Dprintf("Mode switch failed for unknown reason.\n"); break;
    }
}

static int MainLoop(HANDLE hKillEvent) {
    RegisterHotKey(NULL, 50, MOD_CONTROL | MOD_ALT | MOD_WIN, '5');
    RegisterHotKey(NULL, 60, MOD_CONTROL | MOD_ALT | MOD_WIN, '6');
    for (;;) {
        DWORD res = MsgWaitForMultipleObjects(1, &hKillEvent, FALSE, INFINITE, QS_HOTKEY);
        if (res == WAIT_OBJECT_0) {
            Dprintf("Received kill event, exiting.\n");
            MessageBox(NULL, "vidmode has been stopped on user's request.", "vidmode", MB_ICONINFORMATION);
            return 0;
        } else if (res == (WAIT_OBJECT_0 + 1)) {
            MSG msg;
            while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
                if (msg.message == WM_HOTKEY) {
                    SetRefresh((int)msg.wParam);
                }
                else if (msg.message == WM_ENDSESSION) {
                    Dprintf("WM_ENDSESSION received, exiting.\n");
                    return 1;
                }
            }
        } else {
            Dprintf("MsgWaitForMultipleObjects returned unexpected value 0x%08X, exiting in fear.\n", res);
            return 1;
        }
    }
}

int main(void) {
    int res = 0;

    HANDLE hKillEvent = CreateEvent(NULL, TRUE, FALSE, "vidmode_kill_event");
    if (!hKillEvent) {
        Dprintf("failed to create kill event.\n");
    } else if (GetLastError() == ERROR_ALREADY_EXISTS) {
        Dprintf("kill event already exists -> another instance is running.\n");
        res = MessageBox(NULL, "vidmode is already running.\r\nDo you want to stop vidmode?", "vidmode", MB_ICONQUESTION | MB_YESNO);
        if (res == IDYES) {
            SetEvent(hKillEvent);
        } else if (res == IDNO) {
            ShowInfo();
        }
        return 1;
    } else {
        Dprintf("kill event created.\n");
        ShowInfo();
    }

    res = MainLoop(hKillEvent);

    if (hKillEvent) {
        CloseHandle(hKillEvent);
    }
    return res;
}


#ifdef NDEBUG
    void WINAPI WinMainCRTStartup(void) {
        ExitProcess(main());
    }
#endif
