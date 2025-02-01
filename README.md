# Fedora Config
My Fedora configuration (based on Fedora Workstation). Configures & Updates Fedora.

**Works only with Fedora i3 Spin.**


## File List

- **config-fedora.sh**: Main script

- **configs**: Folder containing configuration files

- **packages.list**: File containing system packages to be added or removed

- **flatpak.list**: File containing Flatpak applications to be added or removed


## Usage

The four files mentioned above must be in the same directory.

Run the main script with superuser privileges:

```bash
./config-fedora.sh
```

## Script Usage

This script can be executed multiple times in a row. If certain steps have already been configured, they will not be repeated. As a result, the script can be used to:

- Perform the initial system configuration
- Update the system configuration
- Update installed packages

You can also check for available updates (list RPM and Flatpak packages that need updating without applying changes) using the `check` option:

```bash
./config-fedora.sh check
```

To preview available updates from the "testing" repositories, use the testing option:

```bash
./config-fedora.sh testing
```

## Operations Performed by the Script

When executed, the script will perform the following operations:

1. Customize DNF configuration
2. Update RPM packages
3. Update Flatpak packages (*Prompt for system reboot if necessary*)
4. Add additional repositories to the system
5. Install essential components from RPM Fusion
6. Swap certain system components with those from RPM Fusion
7. Install all available codecs from RPM Fusion
8. Install essential i3 components
9. Add or remove RPM packages (*Based on `packages.list`*)
10. Add or remove Flatpak applications (*Based on `flatpak.list`*)
11. Customize system settings (*Prompt for system reboot if necessary*)

