#include <windows.h>

// This code is heavily inspired by a video mode switching tool from Blueberry:
// https://www.pouet.net/topic.php?which=3637&page=84#c570075

#ifndef NDEBUG
    #include <stdio.h>
    #define Dprintf printf
#else
    #define Dprintf(...) do{}while(0)
#endif

static void ShowInfo(void) {
    MessageBox(NULL,
        "jingleplayer is running in the background.\r\n\r\n"
        "Press [Ctrl]+[Shift]+[1]...[9] to play jingle1.wav ... jingle9.wav.\r\n"
        "Press [Ctrl]+[Shift]+[0] to cancel the currently playing jingle.\r\n\r\n"
        "Run jingleplayer.exe again to stop it.",
        "jingleplayer", MB_ICONINFORMATION);
}

static void PlayJingle(int number) {
    if (!number) {
        Dprintf("Stopping jingle.\n");
        PlaySound(NULL, NULL, SND_ASYNC);
    } else {
        static char filename[] = "jingle0.wav";
        filename[6] = '0' + number;
        Dprintf("Playing %s ... ", filename);
        if (PlaySound(filename, NULL, SND_ASYNC | SND_FILENAME | SND_NODEFAULT)) {
            Dprintf("Success.\n");
        } else {
            Dprintf("FAILED.\n");
        }
    }
}

static int MainLoop(HANDLE hKillEvent) {
    for (int i = 0;  i < 10;  ++i) {
        RegisterHotKey(NULL, i, MOD_CONTROL | MOD_SHIFT, '0'+i);
    }
    for (;;) {
        DWORD res = MsgWaitForMultipleObjects(1, &hKillEvent, FALSE, INFINITE, QS_HOTKEY);
        if (res == WAIT_OBJECT_0) {
            Dprintf("Received kill event, exiting.\n");
            MessageBox(NULL, "jingleplayer has been stopped on user's request.", "jingleplayer", MB_ICONINFORMATION);
            return 0;
        } else if (res == (WAIT_OBJECT_0 + 1)) {
            MSG msg;
            while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
                if (msg.message == WM_HOTKEY) {
                    PlayJingle((int)msg.wParam);
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

    HANDLE hKillEvent = CreateEvent(NULL, TRUE, FALSE, "jingleplayer_kill_event");
    if (!hKillEvent) {
        Dprintf("failed to create kill event.\n");
    } else if (GetLastError() == ERROR_ALREADY_EXISTS) {
        Dprintf("kill event already exists -> another instance is running.\n");
        res = MessageBox(NULL, "jingleplayer is already running.\r\nDo you want to stop jingleplayer?", "jingleplayer", MB_ICONQUESTION | MB_YESNO);
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
