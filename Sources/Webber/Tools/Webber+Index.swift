//
//  Webber+Index.swift
//  Webber
//
//  Created by Mihael Isaev on 09.02.2021.
//

extension Webber {
    func index(dev: Bool = false, appJS: String, swJS: String, type: AppType = .spa, manifest: Manifest?) -> String {
        var headlines: [String] = []
        headlines.append(#"<title>&lrm;</title>"#)
        headlines.append(#"<meta charset="utf-8" />"#)
        headlines.append(#"<meta name="viewport" content="width=device-width, initial-scale=1" />"#)
        headlines.append(#"<meta name="description" content="An awesome Swift web app">"#)
        if type == .pwa {
            if let manifest = manifest {
                headlines.append("<meta name=\"theme-color\" content=\"\(manifest.themeColor)\">")
            }
            headlines.append(#"<link rel="manifest" href="./manifest.json">"#)
        }
        headlines.append("<script type=\"text/javascript\" src=\"\(appJS)\" async></script>")
        let style = """
        <style>
        * { box-sizing: border-box; }
        body {
            background-color: #f4f4f4;
            flex-direction: column;
            font-family: system, 'apple-system', 'San Francisco', 'Roboto', 'Segoe UI', 'Helvetica Neue', 'Lucida Grande', sans-serif;
            display: flex;
            align-items: center;
            justify-content: center;
            height: 100vh;
            margin: 0;
        }
        h3 { color: #d5d5d5; }
        h4 { color: #dfdfdf; }
        .error { color: #ff2b2b!important; }
        .progress {
            position: fixed;
            left: 0px;
            top: 0px;
            height: 3px;
            width: 100%;
        }
        .progress-bar { color: #fff; height: 100%; }
        @keyframes sub-bar {
            0% { transform: scaleX(5) translateX(-60%); }
            40% { transform: scaleX(33) translateX(-50%); }
            100% { transform: scaleX(0) translateX(-50%); }
        }
        @keyframes bar {
            0% { transform: translateX(0); }
            100% { transform: translateX(100%); }
        }
        .progress-bar-indeterminate {
            animation: bar 1.8s ease infinite;
            width: 100%;
        }
        .progress-bar-indeterminate::before, .progress-bar-indeterminate::after {
            position: absolute;
            content: "";
            width: 1%;
            min-width: 0.5px;
            height: 100%;
            background: linear-gradient(to left, #F2709C, #FF9472);
            animation: sub-bar 1.8s ease infinite;
            transform-origin: right;
        }
        .progress-bar-determinate {
            display: flex;
            align-items: center;
            justify-content: center;
            width: 0;
            background: linear-gradient(to left, #F2709C, #FF9472);
        }
        </style>
        """
        let eventListeners = """
        <script>
        document.addEventListener('WASMLoadingStarted', (event) => {
            const progress = document.querySelector('.progress-bar');
            progress.classList.add("progress-bar-determinate");
        });
        document.addEventListener('WASMLoadingStartedWithoutProgress', (event) => {
            const progress = document.querySelector('.progress-bar');
            progress.classList.add("progress-bar-indeterminate");
        });
        document.addEventListener('WASMLoadingProgress', (event) => {
            const bar = document.querySelector('.progress-bar');
            bar.style.width = '' + event.detail + '%';
            const label = document.querySelector('h4');
            label.innerText = event.detail + '%';
        });
        document.addEventListener('WASMLoadingError', (event) => {
            const label = document.querySelector('h4');
            label.classList.add("error");
            label.innerText = 'Unable to load application, please try to reload page';
        });
        </script>
        """
        return """
        <!DOCTYPE html>
        <html lang="en-US">
            <head>
                \(headlines.joined(separator: "\n"))
            </head>
            <body>
                \(style)
                <h3>Loading</h3>
                <h4></h4>
                <div class="progress">
                    <div class="progress-bar"></div>
                </div>
                \(eventListeners)
            </body>
        </html>
        """
    }
}
