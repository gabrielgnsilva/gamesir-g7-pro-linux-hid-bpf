# GameSir G7 Pro Linux HID-BPF Fix

HID-BPF report-descriptor fix for the **GameSir G7 Pro 2.4 GHz wireless
dongle**, USB ID `3537:1022`.

## Problem

The controller sends F5/F10 through its keyboard HID collection correctly, but
its Consumer Control collection declares `Usage Maximum` as a four-byte value:

```text
2b ff ff 00 00
```

Linux's generic HID parser interprets that usage incorrectly, reports
`ignoring exceeding usage max`, and drops media reports such as Play/Pause,
Volume Up, Volume Down and Mute. The raw reports are present on `hidraw`, but
no corresponding `evdev` events are generated.

This fix changes the descriptor in the kernel HID-BPF descriptor-fixup hook:

```text
2b ff ff 00 00  ->  2a ff 03 a4 b4
```

The replacement keeps the descriptor length unchanged while making the usage
range valid for the Consumer Control page.

## Supported device

| Vendor | Product | Device |
| --- | --- | --- |
| `3537` | `1022` | GameSir G7 Pro 2.4 GHz wireless dongle |

The BPF program also validates the expected 214-byte report descriptor and the
original bytes before modifying it.

## Requirements

- Linux kernel with HID-BPF support and BTF enabled;
- `udev-hid-bpf`;
- a udev-based system;
- root access for installation.

On Arch Linux, install the runtime and optional build dependencies with:

```bash
sudo pacman -S --needed udev-hid-bpf
```

Clang, LLVM and Git are only needed to rebuild the object, not to install the
prebuilt object in `dist/`.

## Install the prebuilt fix

Review the generated udev rule first with `--dry-run`:

```bash
sudo udev-hid-bpf install --dry-run \
  "$PWD/dist/gamesir-g7-pro-1022.bpf.o"
```

If the output is expected, install it:

```bash
sudo udev-hid-bpf install \
  "$PWD/dist/gamesir-g7-pro-1022.bpf.o"
sudo udevadm control --reload-rules
```

Disconnect and reconnect the controller after installation. The installed
files are:

```text
/etc/udev-hid-bpf/gamesir-g7-pro-1022.bpf.o
/etc/udev/rules.d/99-hid-bpf-gamesir-g7-pro-1022.rules
```

Verify the result with:

```bash
sudo evtest /dev/input/eventX
```

The keyboard device should expose and emit `KEY_PLAYPAUSE`, `KEY_NEXTSONG`,
`KEY_PREVIOUSSONG`, `KEY_VOLUMEUP`, `KEY_VOLUMEDOWN` and `KEY_MUTE`.

## Remove the fix

```bash
sudo rm -f /etc/udev-hid-bpf/gamesir-g7-pro-1022.bpf.o
sudo rm -f /etc/udev/rules.d/99-hid-bpf-gamesir-g7-pro-1022.rules
sudo udevadm control --reload-rules
```

Disconnect and reconnect the controller. Removing the package is not required
if other HID-BPF fixes use it.

## Rebuild

The repository includes the compiled object so Clang and LLVM are not required
on the target machine. To rebuild it:

```bash
sudo pacman -S --needed clang llvm git
./scripts/build.sh
```

The build script pins the `udev-hid-bpf` headers to commit
`bbaad639d4b2efe2a909e8b7c594b91e87704ab8` so future builds do not silently
change when that repository's `HEAD` moves. The script only compiles and
inspects the object; it never installs it.

## Validation status

- Compiled specifically for USB ID `3537:1022`;
- validated on Arch Linux with kernel `7.2.14-arch1-1`;
- tested successfully with one GameSir G7 Pro 2.4 GHz wireless dongle;
- not validated against other GameSir G7 Pro firmware revisions;
- adapted from the original Deadband implementation targeting `3537:100a`.

Success on other firmware revisions is not guaranteed. The descriptor-size and
byte-pattern guards are intentionally kept to avoid modifying an unexpected
descriptor.

## Credits and licensing

This project is based on the HID-BPF report-descriptor fix developed for
[Deadband's `gamesir-linux-tools`](https://github.com/broroeror/gamesir-linux-tools).
The original implementation targeted GameSir devices including USB ID
`3537:100a`; this derivative adds support for the GameSir G7 Pro USB ID
`3537:1022`.

The HID-BPF source and its compiled binary are distributed under the GNU
General Public License version 2.0 only. The original source file declares
`SPDX-License-Identifier: GPL-2.0`; this repository preserves that notice and
ships the complete GPLv2 text in [LICENSE](LICENSE).

The source corresponding to the distributed `.bpf.o` is included in `src/`,
and `scripts/build.sh` documents how to reproduce the binary. The source file
also identifies the modification date and target device.

This is an independent community modification and is not affiliated with,
endorsed by, or supported by GameSir or the Deadband project.

## License

The BPF source is licensed under GNU GPL version 2. See [LICENSE](LICENSE).
