# npaper

A Quickshell-based wallpaper selector for Wayland compositors.

## Preview

![Preview](.github/preview/preview.png)

## Features

- Local and remote (Wallhaven) wallpaper support
- Dual view modes: CoverFlow carousel & grid view
- Search, filter, and browse wallpapers by folder
- Concurrent thumbnail generation with ffmpeg
- Wallhaven API integration with download/apply
- Folder picker for wallpaper and cache directories
- Full keyboard navigation

## Dependencies

### Required

- **awww** - Wallpaper daemon with transitions
- **wlr-randr** - Monitor detection
- **Quickshell** - QML-based Wayland shell
- **ffmpeg** - Thumbnail generation
- **imagemagick** - Dynamic logo color extraction

### Optional

- **mpvpaper** - Video wallpaper support
- **curl** - Wallhaven API requests and wallpaper downloads

### Installation (Arch Linux)

```bash
sudo pacman -S awww wlr-randr quickshell ffmpeg imagemagick mpvpaper curl
```

### Installation (NixOS)

#### Using Flakes (Recommended)

Add to your `flake.nix`:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    npaper.url = "github:lonerOrz/npaper";
  };

  outputs = { nixpkgs, npaper, ... }: {
    nixosConfigurations.your-host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [ npaper.packages.${pkgs.stdenv.hostPlatform.system}.default ];
        })
      ];
    };
  };
}
```

#### Run without installing

```bash
nix run github:lonerOrz/npaper
```

## Usage

### Quickshell Widget

```bash
qs -c npaper
```

## Configuration

All settings are managed through the in-app **Settings panel** (`S` key):

### Paths Tab

- **Wallpaper Directories** — Add/remove multiple wallpaper folders
- **Cache Directory** — Thumbnail cache location (default: `~/.cache/wallpaper_thumbs`)

### Wallhaven Tab

- **API Key** — Your Wallhaven API key (optional, increases rate limit)
- **Download Folder** — Custom download location for remote wallpapers (optional, falls back to first wallpaper directory)
- **Filters** — Toggle categories (General, Anime, People) and purity (Safe, Sketchy, NSFW)

### Appearance Tab

- **Overlay Opacity** — Background dimming level
- **Border Glow** — Enable/disable active card glow effect
- **Card Shadow** — Enable/disable card drop shadows
- **Background Preview** — Show wallpaper preview behind cards

## Keyboard Shortcuts

| Key            | Action                             |
| -------------- | ---------------------------------- |
| `←` / `→`      | Navigate wallpapers                |
| `↑` / `↓`      | Grid view navigation               |
| `Enter`        | Apply wallpaper                    |
| `/` / `Ctrl+F` | Focus search bar                   |
| `Tab`          | Switch wallpaper folder            |
| `[` / `]`      | Toggle view mode (carousel ↔ grid) |
| `W`            | Toggle Wallhaven browser           |
| `R`            | Random wallpaper                   |
| `F5`           | Refresh cache                      |
| `S`            | Toggle settings panel              |
| `Esc`          | Quit / close settings              |

## License

This project is licensed under the BSD 3-Clause License.

---

> If you find `npaper` useful, please give it a ⭐ and share! 🎉
