# CompoKit Launcher

The CompoKit Launcher is a small Win32 application for navigating directories, starting programs and opening other files (using external applications). There are some unique features that make it ideal for preparing and hosting competitions in a [demoparty](https://en.wikipedia.org/wiki/Demoscene#Parties) context:

- In each directory, a file can be marked to be auto-selected when the directory is entered. This helps against accidentally running the wrong file.

- Sibling directories can be entered directly without going through the parent directory first. This reduces the risk of acidentally exposing the listing of all entries in a compo to the public.

- It maintains its own file extension registry, i.e. it can be configured to open files with other applications than the ones which are set up system-wide.

- There are some shortcuts to transfer control back and forth between the Launcher and a "proper" file manager.

----------------------

## Controls

| Key/Operation | Function
| --- | ---
| Up / Down / PageUp / PageDown / Home / End | Move the selection cursor.
| Backspace | Navigate to the parent directory.
| Left / Right | Navigate to the previous or next sibling directory (in lexicographic order, case-insensitive).
| Enter | Run the currently selected file. If an application has been configured for the file's extension in the `[Actions]` section of the configuration file, the configured application is run. Otherwise, the system's default operation is performed, just as if the file was double-clicked in Explorer.
| Ctrl+Enter, Shift+Enter, Alt+Enter | If configured in the configuration file, open the currently selected file in an alternate application, independent of its extension.
| Space | Mark the currently selected file (or subdirectory) as the default for this directory. When re-entering the directory later, the marked file is automatically selected instead of the parent directory (`[..]`). A star (`*`) is shown right of the name of the default file. Press Space on the `[..]` entry to remove the default mark for a directory.
| Esc | Exit the program, but only after being pressed **twice**.
| Ctrl+Q | Exit the program immediately.
| Ctrl+C | Copy the selected file's full path into the clipboard; if the `[..]` entry is selected, copy the current directory's name.
| Ctrl+V | Navigate to the file or directory name that's currently in the clipboard.
| drag&drop | Dragging a file or directory from another file manager into the CompoKit Launcher window navigates to the dropped directory or selects the dropped file.
| F2 | Rename the currently selected item. If it's a directory, default file markings for it and its child directories are preserved.
| F5 | Reload the configuration file and refresh the current directory listing.
| alphanumeric keys | Quick navigation in the current directory, like in Explorer.

The current window position, directory and selected item is stored and preserved across sessions.

----------------------

## Configuration File

The program is configured in a file called `cklaunch.ini` that resides in the same directory as `cklaunch.exe`.

### Section `[Actions]`

This section configures "rules" which programs to call for specific file types, or when using a modifier key while activating a file. The general syntax of this section's entries is as follows:

    ext [ext...] = ['x'] [command [args...]]

With the following fields:
- `ext` specifies one or more file extensions, lowercase without preceding dot, separated by spaces or commas, for which the rule shall match.
  - Instead of file extensions, the special codes `:ctrl`, `:shift` and `:alt` can be used to specify rules that match when activating a file or directory while a modifier key is pressed down; these rules do **not** match any specific file extension.
- `'x'` is optional and specifies a single-character "prefix" that is shown in the file list in front of the file names that match the rule.
- `command` and `args` specify the program to execute and its arguments.
  - Quoting has to be done properly to allow paths with spaces to work.
  - Dollar signs ('`$`') are replaced by the full path to the file that is to be opened.
  - If the command line doesn't explicitly contain a dollar sign, the file path is automatically added as a last argument.
  - Ampersands ('`&`') are replaced by the path of the directory where the viewer program has been found. This can be useful if e.g. config files need to be specified with full paths.
  - Question marks ('`?`') are replaced by the path of the directory where `cklaunch.exe` resides. (In a CompoKit context, that's usually the CompoKit `bin` directory.)
  - If not specified, the `.exe` suffix is implied for `command`.
  - If a matching `command.exe` exists in the directory of `cklaunch.exe`, this is used; otherwise, the `PATH` environment variable is searched.
  - Environment variables are expanded, e.g. "`%OS%`" becomes "`Windows_NT`".
  - If `command` and `args` are omitted, the system default program is used for the rule, as is done with files that don't match any rule.

#### Examples

The following rule marks `.exe` files with a '`*`' prefix, but otherwise makes them behave as usual:

    exe = '*'

The following rule marks music files with a '`>`' prefix and plays them back with XMPlay:

    mp3 wav ogg = '>' xmplay

Note that the `.exe` suffix of `xmplay.exe` isn't needed, and neither is the `"$"` argument at the end. If there is an `xmplay.exe` file in the same directory as `cklaunch.exe`, it is preferred over a system-wide installation.

The following rule makes it possible to navigate to any file or folder in Explorer by pressing Ctrl+Enter on it:

    :ctrl = explorer /select,"$"

In this case, the explicit dollar sign is required because the path name must *not* be an argument of its own, but part of Explorer's `/select` option.



### Section `[Font]`

This section configures the font used in the program.

| Option | Function
| --- | ---
| `Name` | font face name
| `Size` | font size in pixels
| `Weight` | font [weight](https://en.wikipedia.org/wiki/Font#Weight) (400 = normal, 600 = bold)


### Section `[Colors]`

This section configures the colors of the user interface. Colors are specified as HTML/CSS-style 3-digit or 6-digit hex codes with an optional preceding hash sign (`#`), e.g. `#ff3700`.

| Option | Function
| --- | ---
| `Background` | file list background color
| `Prefix` | file type prefix color
| `Text` | file name color
| `Subdir` | directory name color
| `SelectBackground` | selected item's background color
| `SelectPrefix` | selected item's file type prefix color
| `SelectText` | selected item's file name color
| `SelectSubdir` | selected item's directory name color
| `DirBackground` | current directory name background color
| `DirText` | current directory name text color
| `Scrollbar` | scroll indicator color

----------------------

## Caveats

- Unicode support is a little sketchy because the author was too lazy:
  - No Unicode support at all on Windows versions before 10 1903.
  - UTF-8 strings may be visible with some fonts (e.g. Fixedsys).
  - Case-insensitive sorting, quick search, and sibling directory navigation only works for Latin characters without diacritics.

- The `command` of an `[Actions]` rule must be either fully quoted (i.e. enclosed in double quotes) or not quoted at all; partial quoting (like `"C:\Program Files"\foo\bar`) is **not** supported.

- Session restoration doesn't work when the program is quit while the drive letter selection was open.

- The source code isn't particularly clean ;)

----------------------

## Build Instructions

Use Visual Studio 2019 (any edition) to open the `.sln` file and build the `Release|Win32` configuration. The resulting executable will automatically be copied into the `bin` directory of the CompoKit directory tree.

The program automatically detects if it is run from the source directory in the CompoKit tree, and uses the configuration file, state file, and helper applications from the `bin` directory in this case.

The Debug configurations open a console window to show some debugging info and non-fatal error messages.
