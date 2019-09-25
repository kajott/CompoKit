#if 0  // self-compiling code using cross-build toolchain from Linux or WSL
i686-w64-mingw32-g++ -std=c++11 -Wall -Wextra -pedantic -Werror -Os -static -mwindows -o cklaunch.exe "$0" -luser32 -lgdi32 || exit 1
exec ./cklaunch.exe "$@"
#endif  // note: no Unicode support when building this way!

///////////////////////////////////////////////////////////////////////////////

// CompoKit Launcher, a simple directory navigation tool
//
// Copyright (C) 2019 Martin J. Fiedler <keyj@emphy.de>
// published under the terms of the MIT license
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to
// deal in the Software without restriction, including without limitation the
// rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
// sell copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
// FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
// DEALINGS IN THE SOFTWARE.

///////////////////////////////////////////////////////////////////////////////

// Note: The application doesn't use Windows' UTF-16 API ('W'-suffixed API
//       functions). Unicode support is nevertheless provided by configuring
//       the 8-bit code page to UTF-8 via an XML manifest that's built
//       into the execuable. This requires Windows 10 version 1903 or newer
//       to work though; on older versions, it will fall back to the system's
//       configured ANSI code page and not support Unicode file names.

#define WIN32_LEAN_AND_MEAN
#define _CRT_SECURE_NO_WARNINGS
#include <windows.h>
#include <windowsx.h>
#include <shellapi.h>

#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>

#include <string>
#include <cstring>
#include <vector>
#include <unordered_map>
#include <algorithm>

using namespace std;
typedef unsigned char uchar;


///////////////////////////////////////////////////////////////////////////////
// DATA STRUCTURES                                                           //
///////////////////////////////////////////////////////////////////////////////

struct FileType {
    char prefix;
    string cmd;
    string args;
    inline FileType(char prefix_, const string& cmd_="", const string& args_="")
         : prefix(prefix_), cmd(cmd_), args(args_) {}
};

unordered_map<string, FileType*> fileTypeMap;

struct DirItem {
    bool isDir;
    string name;
    string display;
    string sortKey;
    FileType* fileType;
    inline bool operator<(const DirItem& other) {
        if (isDir && !other.isDir) { return true; }
        if (!isDir && other.isDir) { return false; }
        return (sortKey < other.sortKey);
    }
    void set(const char* name_, bool isDir_=false) {
        size_t s = strlen(name_), dot = s;
        name.resize(s);
        display.resize(s + (isDir_ ? 2 : 1));
        sortKey.resize(s);
        display[0] = isDir_ ? '[' : ' ';
        for (size_t i = 0;  i < s;  ++i) {
            char c = name_[i];
            name[i] = c;
            display[i + 1] = c;
            sortKey[i] = tolower(c);
            if (c == '.') { dot = i; }
        }
        if (isDir_) { display[s + 1] = ']'; }
        isDir = isDir_;
        fileType = nullptr;
        if (!isDir_ && (dot < s)) {
            auto it = fileTypeMap.find(sortKey.substr(dot + 1));
            if (it != fileTypeMap.end()) {
                fileType = it->second;
                display[0] = fileType->prefix;
            }
        }
    }
    void   set    (const string& name_, bool isDir_=false) { set(name_.c_str(), isDir_); }
    inline DirItem(const char* name_,   bool isDir_=false) { set(name_,         isDir_); }
    inline DirItem(const string& name_, bool isDir_=false) { set(name_.c_str(), isDir_); }
};


///////////////////////////////////////////////////////////////////////////////
// CONSTANTS, GLOBALS AND DEFAULTS                                           //
///////////////////////////////////////////////////////////////////////////////

#define WINDOW_TITLE        "CompoKit Launcher"
#define CLASS_NAME          "cklaunch"
#define DEFAULT_MARK        "*"
#define WIDEST_PREFIX       "@"
#define STATE_FILE          "cklaunch.state"
#define CONFIG_FILE         "cklaunch.ini"
#define QUICKSEARCH_TIMEOUT 1000
#define SCROLLBAR_WIDTH     4

string prevDir, currDir;
string execDir, startDir;
string initDir, initFile;
vector<DirItem> items;
unordered_map<string, string> defaults;
unordered_map<string, string> toolMap;
vector<FileType*> fileTypes;

HWND hWnd;
HDC hDC;
HFONT hFont;
int winWidth = 512, winHeight = 640;
int winPosX = CW_USEDEFAULT, winPosY = CW_USEDEFAULT;
int scrollOffset = 0;
int selectIndex = 0;
int defaultIndex = -1;
int lineHeight, markWidth;
int dirIndent, fileIndent;

COLORREF cBackground       = RGB(255, 255, 255);
COLORREF cPrefix           = RGB(128, 128, 128);
COLORREF cText             = RGB(  0,   0,   0);
COLORREF cSubdir           = RGB(  0,   0, 128);
COLORREF cSelectBackground = RGB(  0, 120, 215);
COLORREF cSelectPrefix     = RGB(192, 192, 192);
COLORREF cSelectText       = RGB(255, 255, 255);
COLORREF cSelectSubdir     = RGB(255, 255, 192);
COLORREF cDirBackground    = RGB(192, 192, 192);
COLORREF cDirText          = RGB(  0,   0,   0);
COLORREF cScrollbar        = RGB(  0, 120, 215);

string fontName = "Fixedsys";
int fontSize = 16;
int fontWeight = FW_NORMAL;

inline bool IsValidIndex(int index) {
    return (index >= 0) && (index < int(items.size()));
}

inline bool IsValidSelectIndex() {
    return IsValidIndex(selectIndex);
}


///////////////////////////////////////////////////////////////////////////////
// STRING AND UTILITY FUNCTIONS                                              //
///////////////////////////////////////////////////////////////////////////////

// get the contents of an environment variable,
// or the empty string if the variable is not defined
string GetEnv(const string& var) {
    char dummy;
    DWORD size = GetEnvironmentVariable(var.c_str(), &dummy, 1);
    if (!size) { return ""; }
    string res(size + 1, '\0');
    res.resize(GetEnvironmentVariable(var.c_str(), &res[0], size + 1));
    return res;
}

// expand environment variable references in a string
string ExpandEnv(const string& str) {
    string res(str);
    size_t pos = 0, sep = string::npos;
    while (pos < res.size()) {
        if (res[pos] != '%') {
            ++pos;
        }
        else if (sep == string::npos) {
            sep = pos++;
        }
        else {
            string var(GetEnv(res.substr(sep + 1, pos - sep - 1)));
            res.replace(sep, pos + 1 - sep, var);
            pos = sep + var.size();
            sep = string::npos;
        }
    }
    return res;
}

// expand environment variable references in a list of strings
void ExpandEnv(vector<string>& strList) {
    for (size_t i = 0;  i < strList.size();  ++i) {
        strList[i] = ExpandEnv(strList[i]);
    }
}

// trim whitespace off the start of a string (in-place!)
void StringLStrip(string& str) {
    size_t i = 0;
    while ((i < str.size()) && isspace(uchar(str[i]))) { ++i; }
    if (i) { str.erase(0, i); }
}

// trim whitespace off the end of a string (in-place!)
void StringRStrip(string& str) {
    size_t i = str.size();
    while ((i > 0) && isspace(uchar(str[i - 1]))) { --i; }
    str.resize(i);
}

// trim whitespace off both ends of a string (in-place!)
inline void StringStrip(string& str) {
    StringRStrip(str);
    StringLStrip(str);
}

// split a string into a list of strings, using a set of separators
// (roughly equivalent to Python str.split)
vector<string> StringSplit(const string& str, const char* seps, int maxSplit=0) {
    vector<string> res;
    size_t iStart = 0;
    for (size_t j = 0;  j < str.size();  ++j) {
        if (strchr(seps, str[j])) {
            res.push_back(str.substr(iStart, j - iStart));
            iStart = j + 1;
            if (!--maxSplit) { break; }
        }
    }
    res.push_back(str.substr(iStart));
    return res;
}

// split a string into a list of strings, using whitespace as separators,
// and honoring double quotes to form strings with included whitespace
// (essentially, this is a simplified version of CommandLineToArgvA)
vector<string> StringSplit(const string& str) {
    vector<string> res;
    string part;
    part.reserve(str.size());
    enum { sSep, sText, sQuote } state = sSep;
    bool valid = false;
    for (size_t i = 0;  i < str.size();  ++i) {
        char c = str[i];
        if (c == '"') {
            if (state == sSep) { valid = true; }
            state = (state == sQuote) ? sText : sQuote;
        }
        else if (!isspace(uchar(c)) || (state == sQuote)) {
            part.push_back(c);
            valid = true;
            if (state == sSep) { state = sText; }
        }
        else {
            if (valid) { res.push_back(part); }
            state = sSep;
            part.clear();
            valid = false;
        }
    }
    if (valid) { res.push_back(part); }
    return res;
}

// convert multiple strings into integers
vector<int> ListAtoI(const vector<string>& data) {
    vector<int> res(data.size());
    for (size_t i = 0;  i < data.size();  ++i) {
        res[i] = atoi(data[i].c_str());
    }
    return res;
}

// replace all occurrences of "needle" in "haystack" by "replacement"
string StringReplace(const string& haystack, const string& needle, const string& replacement) {
    string res(haystack);
    size_t pos = 0;
    while (pos < res.size()) {
        pos = res.find(needle, pos);
        if (pos == string::npos) { break; }
        res.replace(pos, needle.size(), replacement);
        pos += replacement.size();
    }
    return res;
}

// replace all occurences of "needle" in a list of strings by "replacment"
void StringReplace(vector<string>& strList, const string& needle, const string& replacement) {
    for (size_t i = 0;  i < strList.size();  ++i) {
        strList[i] = StringReplace(strList[i], needle, replacement);
    }
}

// convert a string into lowercase
string StrToLower(const string& str) {
    string res(str);
    for (size_t i = 0;  i < res.size();  ++i) {
        res[i] = tolower(res[i]);
    }
    return res;
}

// get a string from the clipboard,
// returns the empty string if no text in clipboard
string GetClipboard() {
    string res;
    if (!OpenClipboard(hWnd)) { return res; }
    HGLOBAL data = GetClipboardData(CF_TEXT);
    if (data) {
        void* ptr = GlobalLock(data);
        res = (const char*) ptr;
        GlobalUnlock(data);
    }
    CloseClipboard();
    return res;
}

// put a string into the clipboard
void SetClipboard(const string& str) {
    if (!OpenClipboard(hWnd)) { return; }
    HGLOBAL data = GlobalAlloc(GMEM_MOVEABLE, str.size() + 1);
    if (data) {
        void* ptr = GlobalLock(data);
        if (ptr) {
            strcpy((char*)ptr, str.c_str());
            GlobalUnlock(data);
            EmptyClipboard();
            SetClipboardData(CF_TEXT, data);
        }
    }
    CloseClipboard();
}

// read a line from a text file (*not* thread-safe!)
string ReadLine(FILE* f) {
    string res;
    #define RL_BUFSIZE 25
    char buf[RL_BUFSIZE];
    do {
        if (!fgets(buf, RL_BUFSIZE, f)) { break; }
        res.append(buf);
    } while (res.size() && (res[res.size() - 1] != '\n'));
    return res;
}


///////////////////////////////////////////////////////////////////////////////
// PATH MANIPULATION AND FILE SYSTEM ACCESS                                  //
///////////////////////////////////////////////////////////////////////////////

// check whether a character is a path separator (forward or backward slash)
inline bool ispathsep(char c) {
    return (c == '\\') || (c == '/');
}

// check whether a path is an absolute path, i.e. starts with "X:"
bool IsAbsolutePath(const string& path) {
    return ((path.size() >= 2) && isalpha(uchar(path[0])) && (path[1] == ':'));
}

// check whether a path is a volume root, i.e. "X:" or "X:\"
bool IsVolumeRoot(const string& path) {
    return (IsAbsolutePath(path)
        && ((path.size() == 2) || ((path.size() == 3) && ispathsep(path[2]))));
}

// get the current working directory
string GetCWD() {
    string res(MAX_PATH, '\0');
    GetCurrentDirectory(MAX_PATH, &res[0]);
    res.resize(strlen(&res[0]));
    return res;
}

// get the index of the last path separator in a path
size_t GetLastSeparatorIndex(const string& path) {
    size_t res1 = path.rfind('\\');
    size_t res2 = path.rfind('/');
    if (res1 == string::npos) { return res2; }
    if (res2 == string::npos) { return res1; }
    return max(res1, res2);
}

// return the base name (file name part) of a fully qualified path
string BaseName(const string& path) {
    size_t sepPos = GetLastSeparatorIndex(path);
    if (sepPos == string::npos) { return path; }
    return path.substr(sepPos + 1);
}

// return the directory name part of a fully qualified path
string DirName(const string& path) {
    if (IsVolumeRoot(path)) {
        return "";  // special case: return empty string at volume root
    }
    size_t sepPos = GetLastSeparatorIndex(path);
    if (sepPos == string::npos) { sepPos = 0; }
    string res(path.substr(0, sepPos));
    if (IsVolumeRoot(res)) {
        return res + "\\";  // we're at the root of a drive, keep the trailing slash
    }
    return res;
}

// extract the file extension in normalized (lowercase) form
string FileExt(const string& path) {
    if (path.empty()) { return ""; }
    for (int sep = int(path.size()) - 1;  sep >= 0;  --sep) {
        if (ispathsep(path[sep])) {
            break;  // no file extension found, but a path separator
        }
        if (path[sep] == '.') {
            size_t extLen = path.size() - (size_t)sep - 1;
            string res(extLen, '\0');
            for (size_t i = 0;  i < extLen;  ++i) {
                res[i] = tolower(path[(size_t)sep + 1 + i]);
            }
            return res;
        }
    }
    return "";
}

// expand a (possibly relative) path to a fully qualified absolute path
string NormalizePath(const string& path) {
    size_t maxLen = path.size() + 10;
    string res(maxLen, '\0');
    res.resize(GetFullPathName(path.c_str(), DWORD(maxLen - 1), &res[0], nullptr));
    return res;
}

// join two paths together
string JoinPath(const string& a, const string& b) {
    if (b.empty()) {
        return a;
    }
    if (b == "..") {
        // special case: enter parent directory
        return DirName(a);
    }
    if (((b.size() >= 1u) && ispathsep(b[0]))
    ||  ((b.size() >= 2u) && (b[1] == ':'))
    ||  a.empty()) {
        return b;  // B is already an absolute path (or A is empty)
    }
    if (ispathsep(a[a.size() - 1])) {
        // A ends with a path separator already -> just concatenate the strings
        return a + b;
    }
    else {  // need to insert an additional path separator
        return a + "\\" + b;
    }
}

// check what type a path is
enum path_type_t {
    ptNotExisting = 0,
    ptFile,
    ptDir
};
inline path_type_t CheckPath(const string& path) {
    DWORD res = GetFileAttributes(path.c_str());
    return  (res == INVALID_FILE_ATTRIBUTES) ? ptNotExisting :
           ((res & FILE_ATTRIBUTE_DIRECTORY) ? ptDir : ptFile);
}

// check whether a file exists at all
inline bool FileExists(const string& path) {
    return (GetFileAttributes(path.c_str()) != INVALID_FILE_ATTRIBUTES);
}

// check whether a path specifies an existing directory
inline bool IsDir(const string& path) {
    return (CheckPath(path) == ptDir);
}

// check whether a path specifies an existing file
inline bool IsFile(const string& path) {
    return (CheckPath(path) == ptFile);
}

// load a the contents of a directory into a list of DirItems
bool LoadDir(vector<DirItem>& dir, const string& path) {
    if (path.empty()) {
        // drive list pseudo-directory -> list available volumes
        DWORD mask = GetLogicalDrives();
        dir.clear();
        char path[4] = "?:\\";
        for (DWORD drive = 0;  drive < 26;  ++drive) {
            if (mask & (1u << drive)) {
                path[0] = 'A' + char(drive);
                dir.push_back(DirItem(path, true));
            }
        }
    }
    else {
        // normal directory -> list directory contents
        
        // open the directory
        string search(JoinPath(path, "*"));
        WIN32_FIND_DATA fd;
        HANDLE hFind = FindFirstFile(search.c_str(), &fd);
        if (hFind == INVALID_HANDLE_VALUE) {
            return false;  // opening the directory failed; no harm done so far
        }
        dir.clear();

        // iterate over entries
        do {
            if ((fd.cFileName[0] != '.') && !(fd.dwFileAttributes & FILE_ATTRIBUTE_HIDDEN)) {
                dir.push_back(DirItem(fd.cFileName,
                    !!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)));
            }
        } while (FindNextFile(hFind, &fd));
        FindClose(hFind);
        
        // synthesize parent directory entry
        dir.push_back(DirItem("..", true));
    }
    
    // finally, sort and return the list
    sort(dir.begin(), dir.end());
    return true;
}

// find a specific file (or subdirectory) in a DirItem list
int FindInDir(const vector<DirItem>& dir, const string& name) {
    DirItem item(name);
    for (int i = 0;  i < int(dir.size());  ++i) {
        if (dir[i].sortKey == item.sortKey) {
            return i;
        }
    }
    return -1;
}

// resolve the full absolute path to a helper program (with caching)
string GetTool(const string& tool_) {
    // canonicalize tool name (imply .exe suffix if not stated specifically)
    string tool(tool_);
    if (FileExt(tool).empty()) {
        tool.append(".exe");
    }

    // shortcut: prefer absolute path
    if (IsAbsolutePath(tool) && FileExists(tool)) { return tool; }

    // load from cache
    auto it = toolMap.find(tool);
    if (it != toolMap.end()) { return it->second; }

    // create list of directories to search (if not already done so)
    static vector<string> searchDirs;
    if (searchDirs.empty()) {
        // put this program's directory and initial working directory first in the PATH
        searchDirs.push_back(execDir);
        if (startDir != execDir) {
            searchDirs.push_back(startDir);
        }

        // add PATH
        string path(GetEnv("PATH") + ";");
        for (const auto& dir : StringSplit(GetEnv("PATH"), ";")) {
            if (!dir.empty()) {
                searchDirs.push_back(dir);
            }
        }
    }

    // search all directories for the file in question    
    for (const auto& dir : searchDirs) {
        string path(JoinPath(dir, tool));
        if (IsFile(path)) {
            toolMap[tool] = path;
            return path;
        }
    }
    MessageBox(hWnd, (string("unable to find the required application\r\n'") + tool + "'.").c_str(), "CompoKit Launcher", MB_ICONERROR);
    return "";
}


///////////////////////////////////////////////////////////////////////////////
// DRAWING AND CURSOR MOVEMENT                                               //
///////////////////////////////////////////////////////////////////////////////

int GetVisibleLines() {
    return (winHeight / lineHeight) - 1;
}

#define DESIRED_CHARSET ((DWORD)(-1))
void InitFont(DWORD tryCharset=DESIRED_CHARSET, bool allowRetry=true) {
    // destroy old font
    if (hFont) {
        DeleteObject(hFont);
        hFont = nullptr;
    }

    // create new font
    if (tryCharset == DESIRED_CHARSET) {
        tryCharset = (GetOEMCP() == 65001) ? OEM_CHARSET : ANSI_CHARSET;
    }
    hDC = GetDC(hWnd);
    hFont = CreateFont(fontSize, 0, 0, 0, fontWeight, FALSE, FALSE, FALSE, tryCharset, OUT_DEFAULT_PRECIS, CLIP_DEFAULT_PRECIS, DEFAULT_QUALITY, FF_DONTCARE, fontName.c_str());
    SelectObject(hDC, hFont);

    // verify correct font
    string actualFont(fontName.size() + 2, '\0');
    actualFont.resize(GetTextFace(hDC, int(fontName.size() + 1), &actualFont[0]));
    if ((actualFont != fontName) && allowRetry) {
        // we got the wrong font -> try again with a fallback character set
        if (tryCharset != DEFAULT_CHARSET) {
            tryCharset = DEFAULT_CHARSET;
        }
        else {
            // we already tried DEFAULT_CHARSET without success,
            // so we may as well use our desired charset again
            tryCharset = DESIRED_CHARSET;
            allowRetry = false;
        }
        ReleaseDC(hWnd, hDC);
        InitFont(tryCharset, allowRetry);
        return;
    }

    // determine metrics
    SIZE sz;
    GetTextExtentPoint32(hDC, WIDEST_PREFIX, 1, &sz);
    lineHeight = sz.cy;
    fileIndent = sz.cx;
    GetTextExtentPoint32(hDC, DEFAULT_MARK, 1, &sz);
    markWidth = sz.cx;
    GetTextExtentPoint32(hDC, "[", 1, &sz);
    dirIndent = fileIndent - sz.cx;
    ReleaseDC(hWnd, hDC);
}

HBRUSH GetBrush(COLORREF color) {
    static unordered_map<COLORREF, HBRUSH> brushMap;
    auto it = brushMap.find(color);
    if (it != brushMap.end()) { return it->second; }
    HBRUSH newBrush = CreateSolidBrush(color);
    brushMap[color] = newBrush;
    return newBrush;
}

void DrawBox(int x0, int y0, int x1, int y1, COLORREF color) {
    RECT r;
    r.left = x0;
    r.top = y0;
    r.right = x1;
    r.bottom = y1;
    FillRect(hDC, &r, GetBrush(color));
}

void DrawString(int x, int y, COLORREF color, const char* str) {
    SetTextColor(hDC, color);
    TextOut(hDC, x, y, str, int(strlen(str)));
}
inline void DrawString(int x, int y, COLORREF color, const string& str) {
    DrawString(x, y, color, str.c_str());
}

void Redraw(int x0, int y0, int x1, int y1) {
    // context preparations
    SelectObject(hDC, hFont);
    SetBkMode(hDC, TRANSPARENT);

    // draw lines
    int lineIndex = y0 / lineHeight;
    for (int y = lineIndex * lineHeight;  y < y1;  ++lineIndex) {
        COLORREF bg, fg, fgPrefix;
        const char* text = nullptr;
        bool right = false;
        int indent = 0;
        char prefix[2] = { 0, 0 };
        int entryIndex = -1;

        if (!lineIndex) {
            // topmost line is the directory name
            bg = cDirBackground;
            fg = cDirText;
            text = currDir.c_str();
            right = true;
        }
        else {
            // normal entry
            entryIndex = lineIndex - 1 + scrollOffset;
            if (entryIndex >= int(items.size())) {
                // arrived at end of list
                DrawBox(x0, y, x1, y1, cBackground);
                break;
            }
            const DirItem& item = items[entryIndex];

            // select colors
            if (entryIndex == selectIndex) {
                bg = cSelectBackground;
                fg = item.isDir ? cSelectSubdir : cSelectText;
                fgPrefix = cSelectPrefix;
            } else {
                bg = cBackground;
                fg = item.isDir ? cSubdir : cText;
                fgPrefix = cPrefix;
            }

            // get text, determine indent and split off the prefix
            text = item.display.c_str();
            if (item.isDir) {
                indent = dirIndent;
            }
            else if (text && text[0]) {
                indent = fileIndent;
                prefix[0] = text[0];
                text++;
            }
        }
        DrawBox(x0, y, x1, y + lineHeight, bg);
        if (text && text[0]) {
            int x = indent;
            SIZE sz;
            if (right) {
                GetTextExtentPoint32(hDC, text, int(strlen(text)), &sz);
                x = min(0, winWidth - int(sz.cx));
            }
            DrawString(x, y, fg, text);
            if ((entryIndex > 0) && (entryIndex == defaultIndex)) {
                DrawString(winWidth - SCROLLBAR_WIDTH - markWidth, y, fg, DEFAULT_MARK);
            }
            if (prefix[0] && (prefix[0] != ' ')) {
                GetTextExtentPoint32(hDC, prefix, 1, &sz);
                DrawString(indent - sz.cx, y, fgPrefix, prefix);
            }
        }
        y += lineHeight;
    }
    
    // draw scrollbar
    if (items.size() && (GetVisibleLines() < int(items.size()))) {
        int sbSize = ((winHeight - lineHeight) * GetVisibleLines() + int(items.size() >> 1)) / int(items.size());
        int maxScroll = int(items.size()) - GetVisibleLines();
        int sbOffset = lineHeight + (scrollOffset * (winHeight - lineHeight - sbSize) + (maxScroll >> 1)) / maxScroll;
        DrawBox(winWidth - SCROLLBAR_WIDTH, sbOffset, winWidth, sbOffset + sbSize, cScrollbar);
    }
}

void Invalidate(int x0, int y0, int x1, int y1) {
    RECT r;
    r.left = x0;
    r.top = y0;
    r.right = x1;
    r.bottom = y1;
    InvalidateRect(hWnd, &r, FALSE);
}

void Invalidate() {
    Invalidate(0, 0, winWidth, winHeight);
}

void GoTo(int targetIndex) {
    int oldSelect = selectIndex;
    int oldScroll = scrollOffset;
    selectIndex = targetIndex;
    if (selectIndex >= int(items.size())) { selectIndex = int(items.size()) - 1; }
    if (selectIndex < 0) { selectIndex = 0; }
    int scrollMin = selectIndex - GetVisibleLines() + 1;
    if (scrollOffset < scrollMin)   { scrollOffset = scrollMin; }
    if (scrollOffset > selectIndex) { scrollOffset = selectIndex; }
    if (oldScroll != scrollOffset) {
        Invalidate();
    }
    else {
        int a = oldSelect - scrollOffset + 1;
        int b = selectIndex - scrollOffset + 1;
        if (a > b) { int t = a; a = b; b = t; }
        Invalidate(0, a * lineHeight, winWidth, (b + 1) * lineHeight);
    }
}

void ScrollTo(int targetOffset) {
    int scrollMax = int(items.size()) - GetVisibleLines();
    if (targetOffset > scrollMax) { targetOffset = scrollMax; }
    if (targetOffset < 0)         { targetOffset = 0; }
    if (targetOffset != scrollOffset) {
        scrollOffset = targetOffset;
        Invalidate();
    }
}


///////////////////////////////////////////////////////////////////////////////
// CONFIG AND STATE FILE I/O                                                 //
///////////////////////////////////////////////////////////////////////////////

// parse a color specification
void ParseColor(COLORREF& target, const string& str) {
    const char* s = str.c_str();
    if (s[0] == '#') { ++s; }
    size_t l = strlen(s);
    char* end = nullptr;
    unsigned long i = strtoul(s, &end, 16);
    if (!end || *end || ((l != 3) && (l != 6))) {
        fprintf(stderr, "WARNING: invalid color spec '%s'\n", s);
        return;
    }
    if (l == 3) {
        target = RGB((i >> 8) * 17, ((i >> 4) & 15) * 17, (i & 15) * 17);
    }
    else {
        target = RGB(i >> 16, (i >> 8) & 255, i & 255);
    }
}

// load config file
void LoadConfig() {
    // try to open the file
    string path(JoinPath(execDir, CONFIG_FILE));
    #ifdef _DEBUG
        printf("loading config file: %s\n", path.c_str());
    #endif
    FILE *f = fopen(path.c_str(), "r");
    if (!f) { return; }

    // clear old settings
    toolMap.clear();
    fileTypeMap.clear();
    for (auto* t : fileTypes) { delete t; }
    fileTypes.clear();

    // parse the file
    string line, section;
    bool actionSection;
    while (!(line = ReadLine(f)).empty()) {
        StringStrip(line);
        if (line.empty() || (line[0] == ';') || (line[0] == '#')) { continue; }

        // new section?
        if ((line[0] == '[') && (line[line.size() - 1] == ']')) {
            section = StrToLower(line.substr(1, line.size() - 2)) + ".";
            actionSection = (section == "actions.");
            continue;
        }

        // key / value pair?
        size_t sep = line.find('=');
        if (sep == string::npos) {
            fprintf(stderr, "WARNING: invalid line '%s' in INI file\n", line.c_str());
            continue;
        }
        string key(StrToLower(line.substr(0, sep)));  StringRStrip(key);
        string value(line.substr(sep + 1));  StringLStrip(value);
        if (key.empty()) {
            fprintf(stderr, "WARNING: empty key found in INI file\n");
            continue;
        }

        // file type association ?
        if (actionSection) {
            // extract prefix
            char prefix = ' ';
            if ((value.size() >= 3) && (value[0] == '\'') && (value[2] == '\'')) {
                prefix = value[1];
                value.erase(0, 3);
                StringLStrip(value);
            }
            value = ExpandEnv(value);

            // extract first argument (command name)
            // note: we don't support partial quoting here!
            string cmd;
            char sep = ' ';
            if (!value.empty() && (value[0] == '"')) {
                sep = '"';
                value.erase(0, 1);
            }
            size_t end = value.find(sep, 1);
            if (end == string::npos) { end = value.size(); }
            cmd = value.substr(0, end);
            value.erase(0, end + 1);
            StringLStrip(value);

            // append '$' argument if not specified explicitly
            if (!cmd.empty() && (value.find('$') == string::npos)) {
                value.append(" \"$\"");
                StringLStrip(value);
            }

            // construct the file type object and set associations
            auto* t = new FileType(prefix, cmd, value);
            fileTypes.push_back(t);
            for (const auto& ext : StringSplit(key, ", \t;|")) {
                if (!ext.empty()) {
                    fileTypeMap[ext] = t;
                }
            }
            continue;
        }

        // other key
        key.insert(0, section);
        if (0) {}
        else if (key == "font.name")   { fontName = value; }
        else if (key == "font.size")   { fontSize = atoi(value.c_str()); }
        else if (key == "font.weight") { fontWeight = atoi(value.c_str()); }
        else if (key == "colors.background")       { ParseColor(cBackground,       value); }
        else if (key == "colors.prefix")           { ParseColor(cPrefix,           value); }
        else if (key == "colors.text")             { ParseColor(cText,             value); }
        else if (key == "colors.subdir")           { ParseColor(cSubdir,           value); }
        else if (key == "colors.selectbackground") { ParseColor(cSelectBackground, value); }
        else if (key == "colors.selectprefix")     { ParseColor(cSelectPrefix,     value); }
        else if (key == "colors.selecttext")       { ParseColor(cSelectText,       value); }
        else if (key == "colors.selectsubdir")     { ParseColor(cSelectSubdir,     value); }
        else if (key == "colors.dirbackground")    { ParseColor(cDirBackground,    value); }
        else if (key == "colors.dirtext")          { ParseColor(cDirText,          value); }
        else if (key == "colors.scrollbar")        { ParseColor(cScrollbar,        value); }
        else { fprintf(stderr, "WARNING: unrecognized key '%s' in INI file\n", key.c_str()); }
    }
    fclose(f);
}

// load state file; must be called exactly once before the window is created
void LoadState() {
    string path(JoinPath(execDir, STATE_FILE));
    #ifdef _DEBUG
        printf("loading state file: %s\n", path.c_str());
    #endif
    FILE *f = fopen(path.c_str(), "r");
    if (!f) { return; }
    defaults.clear();
    string line;
    while (!(line = ReadLine(f)).empty()) {
        // extract line type (first column)
        StringStrip(line);
        if (line.empty()) { continue; }
        char lineType = line[0];
        line.erase(0, 1);
        StringStrip(line);
        if (line.empty()) { continue; }

        // handle line
        switch (lineType) {
            case '@': {
                vector<int> coords(ListAtoI(StringSplit(line, ", |")));
                if ((coords.size() == 4) && (coords[0] > 20) && (coords[1] > 20)) {
                    winWidth = coords[0];
                    winHeight = coords[1];
                    winPosX = coords[2];
                    winPosY = coords[3];
                }
                break; }
            case '\\':
                if (IsDir(initDir)) {
                    initDir = line;
                }
                break;
            case '.':
                initFile = line;
                break;
            case '*':
                defaults[DirName(line)] = BaseName(line);
                break;
            case '#':
                break;
            default:
                fprintf(stderr, "WARNING: invalid line type '%c' in state file\n", lineType);
                break;
        }
    }
    fclose(f);
}

void SaveState(bool forceSave=false) {
    static bool saved = false;
    if (!forceSave && saved) { return; }
    string path(JoinPath(execDir, STATE_FILE));
    FILE *f = fopen(path.c_str(), "w");
    if (!f) { return; }
    fprintf(f, "# CompoKit Launcher state file; no need to modify this manually, it'll be overwritten anyway!\n");
    RECT r;
    if (GetWindowRect(hWnd, &r)) {
        fprintf(f, "@%d,%d,%d,%d\n", r.right - r.left, r.bottom - r.top, r.left, r.top);
    }
    fprintf(f, "\\%s\n", currDir.c_str());
    if (IsValidSelectIndex()) {
        fprintf(f, ".%s\n", items[selectIndex].name.c_str());
    }
    for (const auto& it : defaults) {
        fprintf(f, "*%s\n", JoinPath(it.first, it.second).c_str());
    }
    fclose(f);
    if (!forceSave) { saved = true; }
}


///////////////////////////////////////////////////////////////////////////////
// EVENT HANDLING                                                            //
///////////////////////////////////////////////////////////////////////////////

// return the currently selected item or (if not representable) directory name
string GetCurrentItem() {
    if (!IsValidSelectIndex()) { return currDir; }
    const DirItem& item = items[selectIndex];
    if (item.name == "..") { return currDir; }
    return JoinPath(currDir, item.name);
}

bool EnterDir(const string& path, const string& select="", bool forceReload=false) {
    // determine with *directory* to enter (even if a file has been specified)
    path_type_t pt = path.empty() ? ptDir : CheckPath(path);
    if (pt == ptNotExisting) { return false; }
    string dirToLoad((pt == ptDir) ? path : DirName(path));
    if ((dirToLoad == currDir) && !forceReload) { return false; }

    // load the directory and adjust the defaults
    if (!LoadDir(items, dirToLoad)) { return false; }
    prevDir = currDir;
    currDir = dirToLoad;
    scrollOffset = 0;
    
    // load the default index
    defaultIndex = -1;
    auto it = defaults.find(StrToLower(currDir));
    defaultIndex = (it != defaults.end()) ? FindInDir(items, it->second) : -1;
    
    // pre-select the appropriate item
    if ((pt == ptDir) && !select.empty()) {
        // explicit file name specified as parameter -> select the file
        selectIndex = FindInDir(items, select);
    }
    else if (pt == ptFile) {
        // explicit file name specified as part of path -> select the file
        selectIndex = FindInDir(items, BaseName(path));
    }
    else if ((prevDir.size() > currDir.size())
         &&  (prevDir.substr(0, currDir.size()) == currDir)) {
        // just descended to parent directory -> select the item
        selectIndex = FindInDir(items, prevDir.substr(currDir.size() + (ispathsep(prevDir[currDir.size()]) ? 1 : 0)));
    }
    else {
        selectIndex = defaultIndex;
    }

    // adjust indices and queue a redraw
    if (!IsValidSelectIndex()) {
        selectIndex = 0;  // ignore invalid selection index
    }
    GoTo(selectIndex);  // scroll into view
    Invalidate();
    return true;
}

void Reload() {
    int oldScroll = scrollOffset;
    LoadConfig();
    InitFont();
    EnterDir(currDir, IsValidSelectIndex() ? items[selectIndex].name : "", true);
    scrollOffset = oldScroll;
    GoTo(selectIndex);
}

void EnterItem() {
    if (!IsValidSelectIndex()) { return; }
    const DirItem& item = items[selectIndex];
    string path(JoinPath(currDir, item.name));

    // check for a Ctrl/Shift/Alt modifier override
    string mod;
    if (GetKeyState(VK_CONTROL) & 0x8000) { mod.append(":ctrl"); }
    if (GetKeyState(VK_SHIFT)   & 0x8000) { mod.append(":shift"); }
    if (GetKeyState(VK_MENU)    & 0x8000) { mod.append(":alt"); }

    // select file type based on modifier or extension
    FileType *ft = nullptr;
    if (!mod.empty()) {
        auto it = fileTypeMap.find(mod);
        if (it != fileTypeMap.end()) {
            ft = it->second;
        }
    }
    if (!ft && !item.isDir) {
        ft = item.fileType;
    }
    if (ft && ft->cmd.empty()) {
        ft = nullptr;  // filetype has empty command line -> ignore it
    }

    // call a specific program
    if (ft) {
        // look up the program to launch
        string cmdline(GetTool(ft->cmd));
        if (cmdline.empty()) { return; }
        string cmdDir(DirName(cmdline));

        // quote the program name if necessary
        if (cmdline.find(' ') != string::npos) {
            cmdline.insert(0, 1, '"');
            cmdline.push_back('"');
        }

        // add the remaining arguments
        cmdline.push_back(' ');
        cmdline.append(StringReplace(StringReplace(ft->args, "$", path), "&", cmdDir));
        #ifdef _DEBUG
            printf("+ %s\n", cmdline.c_str());
        #endif

        // call the helper application
        SaveState(true);
        STARTUPINFO si;
        PROCESS_INFORMATION pi;
        ZeroMemory(&si, sizeof(si));
        si.cb = sizeof(si);
        ZeroMemory(&pi, sizeof(pi));
        if (!CreateProcess(nullptr, (LPSTR) cmdline.c_str(), nullptr, nullptr, FALSE, 0, nullptr, currDir.c_str(), &si, &pi)) {
            MessageBox(hWnd, "Failed to run the application associated with this file.", WINDOW_TITLE, MB_ICONERROR);
        }
        CloseHandle(pi.hThread);
        CloseHandle(pi.hProcess);
        return;
    }

    // enter a subdirectory
    if (item.isDir) {
        EnterDir(path);
        return;
    }

    // fall back to ShellExecute
    SaveState(true);
    ShellExecute(hWnd, nullptr, path.c_str(), nullptr, currDir.c_str(), SW_SHOWNORMAL);
}

void EnterSiblingDir(int delta) {
    if (currDir.empty()) {
        return;  // already at volume selection screen, which has no parent
    }
    string parentName(DirName(currDir));
    vector<DirItem> parentContents;
    if (!LoadDir(parentContents, parentName)) { return; }
    int index = FindInDir(parentContents, BaseName(currDir));
    if (index < 0) {
        return;  // current directory not found in parent, WTF?
    }
    index += delta;
    if ((index >= 0) && (index < int(parentContents.size())) && (parentContents[index].name != "..")) {
        EnterDir(JoinPath(parentName, parentContents[index].name));
    }
}

void SetDefaultIndex(int index) {
    string key(StrToLower(currDir));
    if (IsValidIndex(index) && (items[index].name != "..")) {
        defaultIndex = index;
        defaults[key] = items[index].sortKey;
    }
    else {
        defaultIndex = -1;
        defaults.erase(key);
    }
    SaveState(true);
    Invalidate();
}

void HandleKey(int vk) {
    static bool escape = false;
    static bool wantEnter = false;
    if ((vk < 0) && (vk != -VK_ESCAPE)) { escape = false; }
    switch (vk) {
        case  VK_UP:     GoTo(selectIndex - 1); break;
        case  VK_DOWN:   GoTo(selectIndex + 1); break;
        case  VK_LEFT:   EnterSiblingDir(-1); break;
        case  VK_RIGHT:  EnterSiblingDir(+1); break;
        case  VK_PRIOR:  GoTo(selectIndex - GetVisibleLines() + 1); break;
        case  VK_NEXT:   GoTo(selectIndex + GetVisibleLines() - 1); break;
        case  VK_HOME:   GoTo(0); break;
        case  VK_END:    GoTo(int(items.size()) - 1); break;
        case  VK_BACK:   EnterDir(DirName(currDir)); break;
        case  VK_F5:     Reload(); break;
        case  VK_SPACE:  SetDefaultIndex(selectIndex); break;
        case  'C':       if (GetKeyState(VK_CONTROL) & 0x8000) { SetClipboard(GetCurrentItem()); } break;
        case  'V':       if (GetKeyState(VK_CONTROL) & 0x8000) { string path(GetClipboard()); if (!path.empty()) { EnterDir(path); } } break;
        case  'Q':       if (GetKeyState(VK_CONTROL) & 0x8000) { PostQuitMessage(0); } break;
        case -VK_ESCAPE: if (!escape) { escape = true; }
                                 else { PostQuitMessage(0); } break;
        case  VK_RETURN: wantEnter = true; break;
        case -VK_RETURN: if (wantEnter) { wantEnter = false; EnterItem(); } break;
        default: break;
    }
}

void QuickSearch(int c) {
    static string term;
    static DWORD timeout = 0;

    // search term update/timeout logic
    if (c == 27) { timeout = 0; /* Esc enforces timeout */ }
    if ((c < 0x20) || (c >= 0x7F)) { return; }
    DWORD now = GetTickCount();
    if (now > timeout) { term.clear(); }
    timeout = now + QUICKSEARCH_TIMEOUT;
    term.push_back(tolower(c));

    // now actually search the term
    int searchIndex = selectIndex;
    do {
        if (IsValidIndex(searchIndex) && (items[searchIndex].sortKey.substr(0, term.size()) == term)) {
            GoTo(searchIndex);
            return;
        }
        if (searchIndex++ >= int(items.size())) {
            searchIndex = 0;
        }
    } while (searchIndex != selectIndex);
}

LRESULT CALLBACK WndProc(HWND hWnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
        case WM_PAINT: {
            PAINTSTRUCT ps;
            hDC = BeginPaint(hWnd, &ps);
            Redraw(ps.rcPaint.left, ps.rcPaint.top, ps.rcPaint.right, ps.rcPaint.bottom);
            EndPaint(hWnd, &ps);
            break; }
        case WM_SIZE:
            winWidth = LOWORD(lParam);
            winHeight = HIWORD(lParam);
            GoTo(selectIndex);
            break;
        case WM_DESTROY:
            SaveState();
            PostQuitMessage(0);
            break;
        case WM_KEYDOWN:
            HandleKey(int(wParam));
            break;
        case WM_KEYUP:
            HandleKey(-int(wParam));
            break;
        case WM_CHAR:
            QuickSearch(int(wParam));
            break;
        case WM_LBUTTONDOWN: {
            int index = scrollOffset + (GET_Y_LPARAM(lParam) / lineHeight) - 1;
            if (index >= scrollOffset) { GoTo(index); }
            break; }
        case WM_LBUTTONDBLCLK: {
            int index = scrollOffset + (GET_Y_LPARAM(lParam) / lineHeight) - 1;
            if (index == selectIndex) { EnterItem(); }
            break; }
        case WM_MOUSEWHEEL:
            ScrollTo(scrollOffset - GET_WHEEL_DELTA_WPARAM(wParam) / 40);
            break;
        case WM_DROPFILES: {
            HDROP drop = (HDROP) wParam;
            UINT size = DragQueryFile(drop, 0, NULL, 0);
            string path(size + 1, '\0');
            path.resize(DragQueryFile(drop, 0, &path[0], size + 1));
            DragFinish(drop);
            if (EnterDir(path)) {
                SetForegroundWindow(hWnd);
            }
            break; }
        default:
            return DefWindowProc(hWnd, msg, wParam, lParam);
    }
    return 0;
}


///////////////////////////////////////////////////////////////////////////////
// MAIN PROGRAM                                                              //
///////////////////////////////////////////////////////////////////////////////

int APIENTRY WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int nCmdShow) {
    UNREFERENCED_PARAMETER(hPrevInstance);
    UNREFERENCED_PARAMETER(lpCmdLine);

    // environment initialization
    vector<string> argv = StringSplit(GetCommandLine());
    execDir = DirName(NormalizePath(argv[0]));
    string binDir(NormalizePath(JoinPath(execDir, "..\\..\\bin")));
    if (IsDir(binDir) && IsDir(JoinPath(binDir, "..\\src\\cklaunch"))) {
        // when developing in the CompoKit source tree,
        // act as if the program had been started from the bin/ directory as usual
        execDir = binDir;
    }
    startDir = GetCWD();
    initDir = startDir;
    LoadConfig();
    LoadState();

    // window class creation
    WNDCLASS wc;
    ZeroMemory(&wc, sizeof(wc));
    wc.style = CS_HREDRAW | CS_VREDRAW | CS_DBLCLKS;
    wc.lpfnWndProc = WndProc;
    wc.cbClsExtra = 0;
    wc.cbWndExtra = 0;
    wc.hInstance = hInstance;
    wc.hIcon = LoadIcon(hInstance, MAKEINTRESOURCE(1337));
    wc.hCursor = LoadCursor(nullptr, IDC_ARROW);
    wc.lpszClassName = CLASS_NAME;
    if (!RegisterClass(&wc)) {
        MessageBox(nullptr, "Failed to register the window class.", WINDOW_TITLE, MB_ICONERROR);
        return 1;
    }

    // sanitize window coordinates (i.e. ensure that the window is visible,
    // even though its monitor might have disappeared since)
    if ((winPosX != CW_USEDEFAULT) || (winPosY != CW_USEDEFAULT)) {
        RECT r;
        r.right  = (r.left = winPosX) + winWidth;
        r.bottom = (r.top  = winPosY) + winHeight;
        if (!MonitorFromRect(&r, MONITOR_DEFAULTTONULL)) {
            winPosX = winPosY = CW_USEDEFAULT;
        }
    }

    // window creation
    hWnd = CreateWindow(
        CLASS_NAME, WINDOW_TITLE, WS_OVERLAPPEDWINDOW,
        winPosX, winPosY, winWidth, winHeight,
        nullptr, nullptr, hInstance, nullptr);
    if (!hWnd) {
        MessageBox(nullptr, "Failed to create the window.", WINDOW_TITLE, MB_ICONERROR);
        return 1;
    }

    // determine effective initial window size and initialize the font
    RECT r;
    GetClientRect(hWnd, &r);
    winWidth = r.right;
    winHeight = r.bottom;
    InitFont();

    // initialize file browser
    EnterDir(initDir, initFile);

    // show and draw the window
    DragAcceptFiles(hWnd, TRUE);
    ShowWindow(hWnd, nCmdShow);
    UpdateWindow(hWnd);

    // main message loop
    MSG msg;
    while (GetMessage(&msg, nullptr, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    // finalization
    SaveState();
    DestroyWindow(hWnd);
    UnregisterClass(CLASS_NAME, hInstance);
    return 0;
}

#ifdef _DEBUG
int main() {
    return WinMain(GetModuleHandle(nullptr), nullptr, nullptr, SW_SHOWNORMAL);
}
#endif
