Place the generated app icon files here before running the launcher icon tool:

Required files (recommended filenames):
- bus_icon_1024.png                <- full icon with blue gradient background (used as image_path)
- bus_icon_1024_transparent.png    <- transparent foreground (optional, used for adaptive foreground)
- bus_icon_background.png          <- optional background-only image (if you want an image background)

How to get the images:
- Open `web/bus_icon_preview.html` in your browser
- Use "Scarica PNG" to download the blue-background version (`bus_icon_1024.png`)
- Use "Scarica PNG (trasparente)" to download the transparent foreground (`bus_icon_1024_transparent.png`)

When the above files are placed here, come back and tell me and I will run:
  flutter pub get
  flutter pub run flutter_launcher_icons:main

This will overwrite generated icons for Android and iOS using the files above.
