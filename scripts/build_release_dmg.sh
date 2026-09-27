#!/bin/bash
set -e

VERSION="1.0.0"
APP_NAME="Macbeth"
DIST_DIR="build/dist"
STAGING_DIR="build/staging"

echo "======================================================================"
echo " Building Macbeth v${VERSION} Release Packages (arm64 + x86_64)"
echo "======================================================================"

rm -rf "${DIST_DIR}" "${STAGING_DIR}"
mkdir -p "${DIST_DIR}" "${STAGING_DIR}"

# 1. Compile release binaries for arm64
echo "==> Compiling arm64 release binaries..."
swift build -c release --triple arm64-apple-macosx14.0 --scratch-path .build/arm64 --product MacbethApp
swift build -c release --triple arm64-apple-macosx14.0 --scratch-path .build/arm64 --product macbeth
mkdir -p "${STAGING_DIR}/arm64" "${STAGING_DIR}/x86_64" "${STAGING_DIR}/universal"
cp ".build/arm64/release/MacbethApp" "${STAGING_DIR}/arm64/MacbethApp"
cp ".build/arm64/release/macbeth" "${STAGING_DIR}/arm64/macbeth"

# 2. Compile release binaries for x86_64
echo "==> Compiling x86_64 release binaries..."
swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path .build/x86_64 --product MacbethApp
swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path .build/x86_64 --product macbeth
cp ".build/x86_64/release/MacbethApp" "${STAGING_DIR}/x86_64/MacbethApp"
cp ".build/x86_64/release/macbeth" "${STAGING_DIR}/x86_64/macbeth"

# 3. Create Universal 2 Fat Binaries via lipo
echo "==> Merging architectures via lipo..."
lipo -create -output "${STAGING_DIR}/universal/MacbethApp" "${STAGING_DIR}/arm64/MacbethApp" "${STAGING_DIR}/x86_64/MacbethApp"
lipo -create -output "${STAGING_DIR}/universal/macbeth" "${STAGING_DIR}/arm64/macbeth" "${STAGING_DIR}/x86_64/macbeth"

echo "Verifying Universal 2 slice headers:"
lipo -info "${STAGING_DIR}/universal/MacbethApp"
lipo -info "${STAGING_DIR}/universal/macbeth"

create_bundle() {
    local target_dir="$1"
    local app_bin="$2"
    local cli_bin="$3"
    local bundle_path="${target_dir}/${APP_NAME}.app"

    mkdir -p "${bundle_path}/Contents/MacOS"
    mkdir -p "${bundle_path}/Contents/Resources"
    
    cp "${app_bin}" "${bundle_path}/Contents/MacOS/MacbethApp"
    chmod +x "${bundle_path}/Contents/MacOS/MacbethApp"
    
    cp "${cli_bin}" "${bundle_path}/Contents/MacOS/macbeth"
    chmod +x "${bundle_path}/Contents/MacOS/macbeth"

    if [ -f "Resources/AppIcon.icns" ]; then
        cp "Resources/AppIcon.icns" "${bundle_path}/Contents/Resources/AppIcon.icns"
    fi

    echo "APPL????" > "${bundle_path}/Contents/PkgInfo"

    cat <<EOF > "${bundle_path}/Contents/Info.plist"
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
    <string>${VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

    # Ad-hoc sign bundle for local Gatekeeper compliance
    codesign --force --deep --sign - "${bundle_path}" 2>/dev/null || true
}

build_dmg() {
    local arch_name="$1"
    local source_bundle="$2"
    local dmg_out="${DIST_DIR}/${APP_NAME}-${VERSION}-${arch_name}.dmg"
    local temp_dmg_root="${STAGING_DIR}/dmg_${arch_name}"
    
    echo "==> Packaging DMG for ${arch_name}..."
    rm -rf "${temp_dmg_root}"
    mkdir -p "${temp_dmg_root}"
    
    cp -R "${source_bundle}" "${temp_dmg_root}/"
    ln -s /Applications "${temp_dmg_root}/Applications"

    hdiutil create \
        -volname "${APP_NAME}" \
        -srcfolder "${temp_dmg_root}" \
        -ov \
        -format UDZO \
        "${dmg_out}"
        
    echo "Generated: ${dmg_out}"
}

# Build App Bundles
create_bundle "${STAGING_DIR}/universal" "${STAGING_DIR}/universal/MacbethApp" "${STAGING_DIR}/universal/macbeth"
create_bundle "${STAGING_DIR}/arm64" "${STAGING_DIR}/arm64/MacbethApp" "${STAGING_DIR}/arm64/macbeth"
create_bundle "${STAGING_DIR}/x86_64" "${STAGING_DIR}/x86_64/MacbethApp" "${STAGING_DIR}/x86_64/macbeth"

# Build DMGs
build_dmg "Universal" "${STAGING_DIR}/universal/${APP_NAME}.app"
build_dmg "AppleSilicon" "${STAGING_DIR}/arm64/${APP_NAME}.app"
build_dmg "Intel" "${STAGING_DIR}/x86_64/${APP_NAME}.app"

# Build Standalone CLI Tarball
echo "==> Packaging standalone CLI tool..."
mkdir -p "${STAGING_DIR}/cli"
cp "${STAGING_DIR}/universal/macbeth" "${STAGING_DIR}/cli/macbeth"
cp LICENSE README.md "${STAGING_DIR}/cli/"
tar -czf "${DIST_DIR}/macbeth-${VERSION}-darwin-universal.tar.gz" -C "${STAGING_DIR}/cli" .

# Generate Checksums
echo "==> Generating SHA-256 checksums..."
cd "${DIST_DIR}"
shasum -a 256 *.dmg *.tar.gz > SHA256SUMS.txt
cat SHA256SUMS.txt
cd - >/dev/null

echo "======================================================================"
echo " Release Build Complete! Artifacts in ${DIST_DIR}:"
ls -lh "${DIST_DIR}"
echo "======================================================================"
