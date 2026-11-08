# AZERTY-Digits

[![Support on Ko-fi](https://img.shields.io/badge/Support%20on-Ko--fi-FF5E5B?logo=kofi&logoColor=white)](https://ko-fi.com/kaecr)

A custom macOS keyboard layout for French AZERTY. The number row types digits without Shift or Caps Lock, in Apple's French order (1 2 3 4 6 5 _ 9 7 ° 8 0 across the row). Holding Shift gives the French symbols (& é " ' § ( - ç è ) ! à).

## Files

- [AZERTY-Digits.keylayout](./AZERTY-Digits.keylayout): the layout.
- [install.sh](./install.sh): installs, updates, removes and checks the layout.

## Install, update, remove

Run [install.sh](./install.sh) from this folder:

```
./install.sh install     # copy the layout to ~/Library/Keyboard Layouts
./install.sh update      # copy again if AZERTY-Digits.keylayout has changed
./install.sh uninstall   # remove the layout
./install.sh status      # show whether the installed copy matches this folder
```

After `install` or `update`, log out and back in (or restart). Then add it in System Settings > Keyboard > Input Sources > **+** > Others > **AZERTY Digits**, and switch to it from the menu bar.

macOS doesn't let scripts add input sources, so that last step is manual. `uninstall` only removes the file, so also remove the input source in System Settings if it's still listed.

## Notes

- Built from Apple's French AZERTY layout. Only the number row changes, so letters, Option, Option+Shift, Cmd, Control and dead keys behave as in Apple's French layout (for example Option + the $ key gives €).
- Number row: digits without Shift, in Apple's French order. Shift gives & é " ' § ( - ç è ) ! à.
- Caps Lock: letters are uppercase and the number row still types digits. Caps Lock + Shift gives symbols.
- The `<` `>` key next to the left Shift is unchanged.
- Status: the file parses as XML, and the install, status and uninstall commands were tested in a temporary HOME. Not yet tested on a real keyboard. Check the number row, @, €, Option+Shift and a few accented letters before relying on it.
