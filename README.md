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

or 

any ubuntu supported on [swift.org](https://swift.org/)

## Installation

#### macOS

On macOS `webber` can be installed with Homebrew. Make sure you have Homebrew installed and then run:

```bash
brew install swifweb/tap/webber
```

to update already installed version run

```bash
brew upgrade webber
```

#### Ubuntu

1. Install swift manually or via [swiftlang.xyz](https://www.swiftlang.xyz)
2. Install `binaryen`
```bash
apt-get install binaryen
```
3. Install `wasmer`
```bash
curl https://get.wasmer.io -sSfL | sh
```
4. Install `npm`
```bash
apt-get install npm
```
5. Install `webber`
```bash
cd /opt
git clone https://github.com/swifweb/webber
cd /opt/webber
swift build -c release
ln -s /opt/webber/.build/release/Webber /usr/bin/webber
exec bash
```
6. Start using it inside of your project folder

To update `webber` to latest version just do
```bash
cd /opt/webber && git pull && swift build -c release
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

for SPA just run

```bash
webber release
```

for PWA execute it this way

```bash
webber release  -t pwa -s Service
```

and then grub your files from `.webber/release/`

### How to serve release files with `nginx`

1. Install nginx by the [official instrucation](https://www.nginx.com/resources/wiki/start/topics/tutorials/install/)
2. Edit `/etc/nginx/mime.types` add `application/wasm    wasm;` in order to serve `wasm` files correctly
3. Generate SSL certificate with letsencrypt (or anything else)
4. Declare your server like this
```ruby
server {
    server_name yourdomain.com;

    listen [::]:443 ssl;
    listen 443 ssl;
    ssl_certificate /etc/letsencrypt/live/yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/yourdomain.com/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
    
    ssl_session_cache    shared:SSL:10m;
	ssl_protocols       TLSv1 TLSv1.1 TLSv1.2;
	add_header Strict-Transport-Security "max-age=31536000; includeSubdomains;";
	ssl_stapling on;
	ssl_stapling_verify on;
    
    root /app/yourdomain.com/.webber/release;
    
    location / {
 	   try_files $uri $uri/ /index.html;
 	}
 	
 	location ~* \.(js|jpg|png|css|wasm)$ {
        root /app/yourdomain.com/.webber/release;
        expires 30d;
        add_header Cache-Control "public, no-transform";
    }
}
```

## Credits

Infinite thanks to the [swiftwasm](https://github.com/swiftwasm) organization for their
- awesome swift fork adopted for webassembly
- awesome [JavaScriptKit](https://github.com/swiftwasm/JavaScriptKit) which is used under the hood of the `web` package
- awesome [carton](https://github.com/swiftwasm/carton) tool which was an inspiration for creating `webber` to cover all the needs
