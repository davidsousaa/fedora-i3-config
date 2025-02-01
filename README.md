# Fedora Config
My Fedora configuration (based on Fedora Workstation). Configures & Updates Fedora.

**Works only with Fedora i3 Spin.**


## File List

- **config-fedora.sh**: Main script

- **gnome.list**: File containing packages to be added or removed for GNOME customization (themes and extensions)

- **packages.list**: File containing system packages to be added or removed

- **flatpak.list**: File containing Flatpak applications to be added or removed


## Usage

The four files mentioned above must be in the same directory.

Run the main script with superuser privileges:

```bash
./config-fedora.sh
