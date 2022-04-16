<p align="center">
    <a href="LICENSE">
        <img src="https://img.shields.io/badge/license-MIT-brightgreen.svg" alt="MIT License">
    </a>
    <a href="https://swift.org">
        <img src="https://img.shields.io/badge/swift-5.3-brightgreen.svg" alt="Swift 5.3">
    </a>
    <a href="https://discord.gg/q5wCPYv">
        <img src="https://img.shields.io/discord/612561840765141005" alt="Swift.Stream">
    </a>
</p>


# Webber

Powerful console tool for cooking your swifweb apps

## Requirements

macOS 10.15 and Xcode 11.4 or later.

## Installation

On macOS `webber` can be installed with Homebrew. Make sure you have Homebrew installed and then run:

```bash
brew install swifweb/tap/webber
```

to update already installed version run

```bash
brew upgrade webber
```

## Usage

If you already have a project then just go to its folder in console

If you don't then manually `git clone` a template and then go to its directory

### New project

You could either clone one of templates from swifweb organization repos or you could use `webber`

single page app
```bash
git clone https://github.com/swifweb/spa-template myspawebsite
cd myspawebsite
open Package.swift # to work with code
webber serve # to launch in browser
```

progressive web app
```bash
git clone https://github.com/swifweb/pwa-template mypwawebsite
cd mypwawebsite
open Package.swift # to work with code
webber serve -t pwa -s Service # to launch in browser
```

### Development

if your project is `single page application` then this command will be enough to start working

```bash
webber serve 
```

This command do:
- compile your project into webassembly file
- cook needed html and js files, store them into `.webber` hidden folder inside project directory
- spinup local webserver
- open default browser to see your web app (it is on http/2 by default with self-signed cert, so add it into system)
- watch for changes in the project directory, rebuild project automatically and update page in browser

if you clone the `pwa` template then you should additionally provide the following arguments:
- `-t pwa` to say `webber` that your project should be cooked as PWA
- the name of your service worker target e.g. `-s Service`

so in the end `serve` command for `pwa` template could look like this

```bash
webber serve -t pwa -s Service
```

### Release

just run

```bash
webber release
```

and then grub your files from `.webber/release/`

## Credits

Infinite thanks to the [swiftwasm](https://github.com/swiftwasm) organization for their
- awesome swift fork adopted for webassembly
- awesome [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit) which is used under the hood of the `web` package
- awesome [carton](https://github.com/swiftwasm/carton) tool which was an inspiration for creating `webber` to cover all the needs
