<!-- Improved compatibility of back to top link: See: https://github.com/othneildrew/Best-README-Template/pull/73 -->
<a id="readme-top"></a>

[![Contributors][contributors-shield]][contributors-url]
[![Forks][forks-shield]][forks-url]
[![Stargazers][stars-shield]][stars-url]
[![Issues][issues-shield]][issues-url]
[![MIT License][license-shield]][license-url]

<br />
<div align="center">
  <a href="https://github.com/MichaelMIL/ClipBoard">
    <img src="Sources/ClipboardApp/Resources/logo.png" alt="Clipboard logo" width="80" height="80">
  </a>

  <h3 align="center">Clipboard</h3>

  <p align="center">
    macOS menu bar app — keep a history of what you copy and paste older clips in seconds.
    <br />
    <a href="https://github.com/MichaelMIL/ClipBoard#readme"><strong>Explore the docs »</strong></a>
    <br />
    <br />
    <a href="https://github.com/MichaelMIL/ClipBoard/releases">Download</a>
    &middot;
    <a href="https://github.com/MichaelMIL/ClipBoard/issues/new?labels=bug">Report Bug</a>
    &middot;
    <a href="https://github.com/MichaelMIL/ClipBoard/issues/new?labels=enhancement">Request Feature</a>
  </p>
</div>

<br />

<details>
  <summary>Table of Contents</summary>
  <ol>
    <li>
      <a href="#about-the-project">About The Project</a>
      <ul>
        <li><a href="#privacy-and-open-source">Privacy and open source</a></li>
        <li><a href="#built-with">Built With</a></li>
      </ul>
    </li>
    <li>
      <a href="#getting-started">Getting Started</a>
      <ul>
        <li><a href="#prerequisites">Prerequisites</a></li>
        <li><a href="#installation">Installation</a></li>
      </ul>
    </li>
    <li><a href="#usage">Usage</a></li>
    <li><a href="#roadmap">Roadmap</a></li>
    <li><a href="#contributing">Contributing</a></li>
    <li><a href="#license">License</a></li>
    <li><a href="#contact">Contact</a></li>
    <li><a href="#acknowledgments">Acknowledgments</a></li>
  </ol>
</details>

## About The Project

[![Clipboard app logo][product-screenshot]](https://github.com/MichaelMIL/ClipBoard/releases)

Clipboard runs in the **menu bar** and records a rolling **history of things you copy**. Open an **overlay** to browse recent clips, pick one, and it goes back on the system pasteboard so you can paste it anywhere—without digging through other apps.

### Privacy and open source

This project exists so you can use a clipboard manager **without your clips or personal information being collected or shared** by the app. Clipboard is built to keep history **on your Mac**—there is no analytics, telemetry, or cloud sync; nothing is uploaded to remote servers for the app to work. The **full source code is public** (MIT License), so anyone can review it, build it themselves, and confirm how data is handled.

Why use it:

* **Stays out of the way** — one icon next to the clock; no dock clutter.
* **Keyboard-driven** — set a global shortcut for the overlay in Preferences.
* **Private options** — optional copy notifications with a mode that hides preview text.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

### Built With

* [![Swift][Swift-shield]][Swift-url]
* [![SwiftUI][SwiftUI-shield]][SwiftUI-url]
* [![macOS][macOS-shield]][macOS-url]

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Getting Started

Use a **prebuilt app** from [Releases](https://github.com/MichaelMIL/ClipBoard/releases), or build from source with SwiftPM and the included scripts.

### Prerequisites

* **macOS 14** (Sonoma) or later
* **Xcode** or **Xcode Command Line Tools** (for building from source only) — [Apple Developer](https://developer.apple.com/xcode/)

### Installation

#### Option A — Download a release

1. Open **[Releases](https://github.com/MichaelMIL/ClipBoard/releases)** and download the latest asset (for example a `.zip` containing `ClipboardApp.app`).
2. Unzip if needed, then drag **`ClipboardApp.app`** into **Applications**.
3. First launch: if Gatekeeper blocks the app, **right‑click** → **Open** → confirm (common for builds outside the Mac App Store).

#### Option B — Build from source

1. Clone the repo and `cd` into the project folder.
   ```sh
   git clone https://github.com/MichaelMIL/ClipBoard.git
   cd ClipBoard
   ```
2. Create the app bundle (release build; outputs `ClipboardApp.app` at the repo root).
   ```sh
   ./scripts/bundle-app.sh
   ```
3. Run the app.
   ```sh
   open ClipboardApp.app
   ```

**Maintainers:** bump version, rebuild, bundle, and open in one step:

```sh
./scripts/build-and-open.sh --skip-version
./scripts/build-and-open.sh --help
```

> Local bundles are **ad hoc** signed. For **notifications** and **Launch Services**, run the bundled **`ClipboardApp.app`**, not only `swift run`.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Usage

* Click the **Clipboard** icon in the menu bar → **Open overlay** (or use your shortcut).
* Choose an entry; it is copied to the clipboard — paste with **⌘V** in any app.
* **Preferences…** (also **⌘,** from the menu) — history size, notifications, login item, overlay shortcut.
* **About…** — version and app info.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Roadmap

- [ ] Track enhancements and bugs in [GitHub Issues](https://github.com/MichaelMIL/ClipBoard/issues)

See [open issues](https://github.com/MichaelMIL/ClipBoard/issues) for a full list of proposals and known issues.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Contributing

Contributions are welcome. Fork the repo, open a **pull request**, or file an issue with the **enhancement** label.

1. Fork the Project
2. Create your Feature Branch (`git checkout -b feature/amazing-feature`)
3. Commit your Changes (`git commit -m 'Add some amazing feature'`)
4. Push to the Branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Top contributors

<a href="https://github.com/MichaelMIL/ClipBoard/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=MichaelMIL/ClipBoard" alt="Contributors" />
</a>

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## License

Distributed under the MIT License. See [`LICENSE`](LICENSE) for details.

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Contact

**Michael** — [GitHub @MichaelMIL](https://github.com/MichaelMIL)

Project Link: [https://github.com/MichaelMIL/ClipBoard](https://github.com/MichaelMIL/ClipBoard)

<p align="right">(<a href="#readme-top">back to top</a>)</p>

## Acknowledgments

* [Best-README-Template](https://github.com/othneildrew/Best-README-Template) — README structure and conventions
* [Shields.io](https://shields.io) — badge images
* [contrib.rocks](https://contrib.rocks) — contributor avatars

<p align="right">(<a href="#readme-top">back to top</a>)</p>

<!-- MARKDOWN LINKS & IMAGES -->
<!-- https://www.markdownguide.org/basic-syntax/#reference-style-links -->

[contributors-shield]: https://img.shields.io/github/contributors/MichaelMIL/ClipBoard.svg?style=for-the-badge
[contributors-url]: https://github.com/MichaelMIL/ClipBoard/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/MichaelMIL/ClipBoard.svg?style=for-the-badge
[forks-url]: https://github.com/MichaelMIL/ClipBoard/network/members
[stars-shield]: https://img.shields.io/github/stars/MichaelMIL/ClipBoard.svg?style=for-the-badge
[stars-url]: https://github.com/MichaelMIL/ClipBoard/stargazers
[issues-shield]: https://img.shields.io/github/issues/MichaelMIL/ClipBoard.svg?style=for-the-badge
[issues-url]: https://github.com/MichaelMIL/ClipBoard/issues
[license-shield]: https://img.shields.io/github/license/MichaelMIL/ClipBoard.svg?style=for-the-badge
[license-url]: https://github.com/MichaelMIL/ClipBoard/blob/main/LICENSE
[product-screenshot]: Sources/ClipboardApp/Resources/logo.png
[Swift-shield]: https://img.shields.io/badge/Swift-5.9-F05138?style=for-the-badge&logo=swift&logoColor=white
[Swift-url]: https://swift.org/
[SwiftUI-shield]: https://img.shields.io/badge/SwiftUI-0066CC?style=for-the-badge&logo=swift&logoColor=white
[SwiftUI-url]: https://developer.apple.com/xcode/swiftui/
[macOS-shield]: https://img.shields.io/badge/macOS-14%2B-000000?style=for-the-badge&logo=apple&logoColor=white
[macOS-url]: https://www.apple.com/macos/
