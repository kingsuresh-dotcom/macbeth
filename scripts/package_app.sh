#!/bin/bash
set -e

APP_NAME="Macbeth"
BUILD_DIR=".build/debug"
APP_BUNDLE="${APP_NAME}.app"

echo "Creating .app bundle structure for ${APP_NAME}..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/MacbethApp" "${APP_BUNDLE}/Contents/MacOS/MacbethApp"
chmod +x "${APP_BUNDLE}/Contents/MacOS/MacbethApp"

cp "${BUILD_DIR}/macbeth" "${APP_BUNDLE}/Contents/MacOS/macbeth"
chmod +x "${APP_BUNDLE}/Contents/MacOS/macbeth"

if [ -f "Resources/AppIcon.icns" ]; then
    cp "Resources/AppIcon.icns" "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"
    echo "Copied AppIcon.icns to ${APP_BUNDLE}/Contents/Resources/"
fi

# PkgInfo
echo "APPL????" > "${APP_BUNDLE}/Contents/PkgInfo"

# Info.plist
cat <<EOF > "${APP_BUNDLE}/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacbethApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.macbeth.app</string>
    <key>CFBundleName</key>
    <string>Macbeth</string>
    <key>CFBundleDisplayName</key>
    <string>Macbeth</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "Macbeth.app created successfully at $(pwd)/${APP_BUNDLE}"

if [ -w "/Applications" ] || [ -w "/Applications/Macbeth.app" ]; then
    echo "Syncing updated bundle to /Applications/Macbeth.app..."
    rm -rf "/Applications/Macbeth.app"
    cp -R "${APP_BUNDLE}" "/Applications/Macbeth.app"
    echo "Successfully updated /Applications/Macbeth.app"
fi
