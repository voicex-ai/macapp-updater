#!/usr/bin/env bash
# VoiceX Complete Release Script - Notarization + Sparkle Signing + Appcast Generation
# Usage: ./release_complete.sh <version> "<release_notes>" [path-to-xcarchive | path-to-app | path-to-dir]
# Example: ./release_complete.sh 1.2.0 "Bug fixes and new features" ./VoiceX.xcarchive
set -euo pipefail
IFS=$'\n\t'

# ---------------- Configuration ----------------
APPLE_ID="dnishchit@gmail.com"
TEAM_ID="MPGLBH9FVN"
APP_PASSWORD="xbup-qoks-gpbe-cids"
DEVELOPER_ID_NAME="Developer ID Application: Nishchit Dhanani (MPGLBH9FVN)"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly BOLD='\033[1m'
readonly NC='\033[0m'

log_info()    { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*" >&2; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*" >&2; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()    { echo -e "${CYAN}${BOLD}[STEP $1]${NC} $2" >&2; }
log_header()  { echo -e "${BOLD}$*${NC}" >&2; }

# ---------------- Temp files (safe with spaces) ----------------
TEMP_FILES=()
add_temp_file() { TEMP_FILES+=("$1"); }
cleanup() {
    local exit_code=$?
    if [[ "${#TEMP_FILES[@]}" -gt 0 ]]; then
        for f in "${TEMP_FILES[@]}"; do
            [[ -e "$f" ]] && rm -rf -- "$f" || true
        done
    fi
    exit "$exit_code"
}
trap cleanup EXIT

# ---------------- Helpers ----------------
# Resolve and normalize a path to absolute
abs_path() {
    # usage: abs_path somepath
    local p="$1"
    if [[ -d "$p" ]] || [[ -f "$p" ]]; then
        (cd "$(dirname "$p")" && printf "%s/%s\n" "$(pwd -P)" "$(basename "$p")")
    else
        # fallback to pwd if it's not a file/dir (let caller handle)
        (cd "$p" 2>/dev/null && pwd -P) || echo "$p"
    fi
}

# Step 1: prerequisites + decide working dir
check_prerequisites() {
    log_step 1 "Checking prerequisites"

    local input_path="${1:-.}"
    if [[ -z "$input_path" ]]; then
        input_path="."
    fi

    if [[ ! -e "$input_path" ]]; then
        log_error "Path does not exist: $input_path"
        exit 1
    fi

    # If user gave a file inside archive like /path/to/MyApp.xcarchive, use that dir
    local working_dir
    if [[ -d "$input_path" ]]; then
        working_dir="$input_path"
    else
        # if a file provided (rare), use its directory
        working_dir="$(dirname "$input_path")"
    fi
    working_dir="$(cd "$working_dir" && pwd -P)"
    log_info "Working directory: $working_dir"

    if ! command -v create-dmg >/dev/null 2>&1; then
        log_error "create-dmg not found. Install with: brew install create-dmg"
        exit 1
    fi

    echo "$working_dir"
}

# Step 2: find .app bundle(s)
# Returns: prints newline-separated full paths to .app bundles (first line used automatically)
find_app_bundles() {
    local base="$1"
    log_step 2 "Searching for .app bundles under: $base"

    # If user passed a path that is itself an .app, return it
    if [[ "${base##*.}" == "app" && -d "$base" ]]; then
        printf '%s\n' "$(cd "$(dirname "$base")" && pwd -P)/$(basename "$base")"
        return 0
    fi

    # Common .xcarchive location
    if [[ -d "$base/Products/Applications" ]]; then
        # return all .app bundles under Products/Applications (null-safe)
        local -a found=()
        while IFS= read -r -d '' p; do found+=("$p"); done < <(find "$base/Products/Applications" -type d -name "*.app" -print0 2>/dev/null)
        if [[ "${#found[@]}" -gt 0 ]]; then
            for p in "${found[@]}"; do printf '%s\n' "$p"; done
            return 0
        fi
    fi

    # Look for any .app under the given base (limit depth to avoid scanning whole FS accidentally)
    # We'll do a reasonably bounded search: depth 6
    local -a found_any=()
    while IFS= read -r -d '' p; do found_any+=("$p"); done < <(find "$base" -type d -name "*.app" -maxdepth 6 -print0 2>/dev/null || true)

    if [[ "${#found_any[@]}" -gt 0 ]]; then
        for p in "${found_any[@]}"; do printf '%s\n' "$p"; done
        return 0
    fi

    # No app bundles found
    return 1
}

# Step 3: sign app (if needed)
sign_app() {
    local app_path="$1"
    log_step 3 "Verifying/signing app with forced entitlements: $app_path"

    # Create the entitlements file if it doesn't exist
    local entitlements_file="VoiceX_Production.entitlements"
    
    cat > "$entitlements_file" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.security.device.audio-input</key>
    <true/>
    
    <key>com.apple.security.network.client</key>
    <true/>
    
    <key>com.apple.security.files.user-selected.read-only</key>
    <true/>
    
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    
    <key>com.apple.security.automation.apple-events</key>
    <true/>
    
    <key>com.apple.security.cs.allow-jit</key>
    <false/>
    
    <key>com.apple.security.cs.allow-unsigned-executable-memory</key>
    <false/>
    
    <key>com.apple.security.cs.allow-dyld-environment-variables</key>
    <false/>
    
    <key>com.apple.security.cs.disable-library-validation</key>
    <false/>
    
    <key>com.apple.security.temporary-exception.files.absolute-path.read-write</key>
    <array>
        <string>/tmp/</string>
        <string>/var/tmp/</string>
        <string>/private/tmp/</string>
    </array>
</dict>
</plist>
EOF

    add_temp_file "$entitlements_file"
    log_info "Created production entitlements file: $entitlements_file"

    # Remove existing signature first
    log_info "Removing existing signature..."
    codesign --remove-signature "$app_path" 2>/dev/null || true

    # Sign with our entitlements
    log_info "Signing app with Developer ID and production entitlements..."
    codesign --sign "$DEVELOPER_ID_NAME" \
             --timestamp \
             --deep \
             --force \
             --options runtime \
             --entitlements "$entitlements_file" \
             "$app_path"

    # Verify entitlements are embedded
    log_info "Verifying entitlements are embedded..."
    if codesign -d --entitlements - "$app_path" | grep -q "com.apple.security.device.audio-input"; then
        log_success "✅ Audio input entitlement confirmed in signed app"
    else
        log_error "❌ Audio input entitlement MISSING from signed app"
        return 1
    fi

    log_success "App signed successfully with production entitlements"
    
    # Show embedded entitlements for verification
    log_info "Embedded entitlements:"
    codesign -d --entitlements - "$app_path" | head -20
}

# Step 4: create zip for notarization - sanitize zip name but preserve uniqueness
create_app_zip() {
    local app_path="$1"
    local app_name="$2"
    # replace spaces with underscores but allow dots/versions
    local safe_name
    safe_name="${app_name// /_}"
    local zip_name="${safe_name}_notarization_$(date +%s).zip"
    log_step 4 "Creating zip for app notarization: $zip_name"
    ditto -c -k --keepParent "$app_path" "$zip_name"
    add_temp_file "$PWD/$zip_name"
    log_success "Zip created: $zip_name"
    printf '%s\n' "$PWD/$zip_name"
}

# Step 5: submit for notarization (wait)
submit_for_notarization() {
    local file_path="$1"
    local description="$2"
    local step_num="${3:-5}"

    log_step "$step_num" "Submitting $description for notarization: $file_path"
    local out
    out=$(mktemp)
    add_temp_file "$out"

    if xcrun notarytool submit "$file_path" \
        --apple-id "$APPLE_ID" \
        --team-id "$TEAM_ID" \
        --password "$APP_PASSWORD" \
        --wait >"$out" 2>&1; then
        cat "$out"
        # notarytool output varies; look for Accepted or success indication
        if grep -q -E '"status":\s*"Accepted"|status: Accepted' "$out" 2>/dev/null; then
            log_success "$description notarization accepted"
            return 0
        fi
    fi

    log_error "$description notarization failed. Full output:"
    cat "$out" >&2
    return 1
}

# Step 6: attempt stapling (ok to continue if stapler fails)
attempt_stapling() {
    local file_path="$1"
    local description="$2"
    local step_num="$3"
    log_step "$step_num" "Attempting to staple $description: $file_path"

    if xcrun stapler staple "$file_path" >/dev/null 2>&1; then
        log_success "$description stapled successfully"
        return 0
    fi

    log_warning "Stapling failed for $description — will verify via spctl instead"
    # verify online notarization if possible
    if spctl -a -vvv -t install "$file_path" 2>&1 | grep -q "source=Notarized Developer ID"; then
        log_success "$description is notarized (online verification)"
        return 0
    fi
    log_warning "Stapling/online verification did not confirm notarization — continuing anyway"
    return 1
}

# Step 7: create DMG (uses create-dmg)
create_dmg() {
    local app_path="$1"
    local app_name="$2"
    log_step 7 "Creating DMG for $app_name"

    # Remove similarly named DMGs only in cwd (safe)
    find . -maxdepth 1 -type f -name "${app_name}*.dmg" -print0 2>/dev/null | xargs -0 -I{} rm -f {} 2>/dev/null || true

    local out
    out=$(mktemp)
    add_temp_file "$out"

    # Fixed for sindresorhus/create-dmg - much simpler syntax
    if ! create-dmg \
        --overwrite \
        --dmg-title="$app_name" \
        "$app_path" \
        . >"$out" 2>&1; then
        log_error "create-dmg failed. Output:"
        cat "$out" >&2
        return 1
    fi

    # Show output to user but don't capture it as return value
    cat "$out" >&2

    # sindresorhus/create-dmg creates DMG with app name and version
    # Look for the created DMG file
    local -a candidates=()
    while IFS= read -r -d '' f; do candidates+=("$f"); done < <(find . -maxdepth 1 -type f -name "${app_name}*.dmg" -print0 2>/dev/null || true)

    if [[ "${#candidates[@]}" -eq 0 ]]; then
        # Fallback: find any new dmg
        while IFS= read -r -d '' f; do candidates+=("$f"); done < <(find . -maxdepth 1 -type f -name "*.dmg" -print0 2>/dev/null || true)
    fi

    if [[ "${#candidates[@]}" -eq 0 ]]; then
        log_error "No DMG produced/found in current directory"
        return 1
    fi

    # Choose newest by mtime
    local newest=""
    local newest_mtime=0
    for f in "${candidates[@]}"; do
        local m
        m=$(stat -f %m -- "$f" 2>/dev/null || stat -c %Y -- "$f" 2>/dev/null || echo 0)
        if [[ "$m" -gt "$newest_mtime" ]]; then
            newest_mtime="$m"
            newest="$f"
        fi
    done

    if [[ -z "$newest" || ! -f "$newest" ]]; then
        log_error "Failed to determine created DMG"
        return 1
    fi

    log_success "DMG created: $(basename "$newest")"
    # Return absolute path only (clean)
    printf '%s\n' "$(cd "$(dirname "$newest")" && pwd -P)/$(basename "$newest")"
}

# Step 8: sign DMG
sign_dmg() {
    local dmg_path="$1"
    log_step 8 "Signing DMG: $dmg_path"
    
    # Ensure the path exists
    if [[ ! -f "$dmg_path" ]]; then
        log_error "DMG file not found: $dmg_path"
        return 1
    fi
    
    # Try to sign (force if already signed)
    if codesign --sign "$DEVELOPER_ID_NAME" --timestamp --force -- "$dmg_path" 2>/dev/null; then
        log_success "DMG signed successfully"
    else
        # If signing fails, check if it's already properly signed
        if codesign --verify --verbose=4 -- "$dmg_path" >/dev/null 2>&1; then
            local current_identity
            current_identity=$(codesign -dv -- "$dmg_path" 2>&1 | awk -F'=' '/Authority=/ {print $2; exit}')
            if [[ -n "$current_identity" && "$current_identity" == "$DEVELOPER_ID_NAME" ]]; then
                log_success "DMG already properly signed with correct identity"
            else
                log_warning "DMG signed with different identity: $current_identity"
                log_info "Continuing anyway - DMG is signed"
            fi
        else
            log_error "DMG signing failed and verification failed"
            return 1
        fi
    fi
}

# Step 9/11: verification
verify_dmg() {
    local dmg_path="$1"
    log_step 11 "Verifying DMG: $dmg_path"

    if hdiutil verify "$dmg_path" >/dev/null 2>&1; then
        log_success "DMG integrity verified"
    else
        log_warning "DMG integrity verification reported issues"
    fi

    local spctl_out
    spctl_out=$(spctl -a -vvv -t install "$dmg_path" 2>&1 || true)
    echo "Verification details:" >&2
    echo "$spctl_out" | sed -n '1,200p' >&2

    if echo "$spctl_out" | grep -qi "accepted"; then
        log_success "DMG accepted by Gatekeeper"
        if echo "$spctl_out" | grep -q "source=Notarized Developer ID"; then
            log_success "DMG properly notarized"
        fi
        return 0
    fi

    log_error "DMG verification failed (spctl did not accept it)"
    return 1
}

# ---------------- Sparkle Functions ----------------

# Setup Sparkle tools and keys
setup_sparkle() {
    log_step 12 "Setting up Sparkle tools and keys"

    # Check if Sparkle tools already exist
    if [ -f "./generate_keys" ] && [ -f "./sign_update" ] && [ -f "./eddsa_key_VoiceX.private" ]; then
        log_info "Sparkle tools and keys already exist, skipping setup"
    else
        log_info "Setting up fresh Sparkle tools and keys..."
        
        # Remove old keys if they exist
        rm -f eddsa_key_*.private generate_keys sign_update

        # Download Sparkle tools
        log_info "📥 Downloading Sparkle tools..."
        curl -L -o sparkle-tools.zip "https://github.com/sparkle-project/Sparkle/releases/latest/download/Sparkle-for-Swift-Package-Manager.zip"

        # Extract tools
        unzip -j sparkle-tools.zip "bin/generate_keys" "bin/sign_update" -d ./
        chmod +x generate_keys sign_update

        # Generate new keys
        log_info "🔐 Generating new EdDSA key pair..."
        ./generate_keys

        # Clean up
        rm -f sparkle-tools.zip
    fi

    # Verify Sparkle setup
    if [ ! -f "./generate_keys" ] || [ ! -f "./sign_update" ] || [ ! -f "./eddsa_key_VoiceX.private" ]; then
        log_error "Sparkle setup failed - required files missing"
        exit 1
    fi

    log_success "✅ Sparkle tools and keys ready"
}

# Extract semantic version from app bundle Info.plist
extract_semantic_version() {
    local app_path="$1"
    local info_plist="$app_path/Contents/Info.plist"
    
    if [[ ! -f "$info_plist" ]]; then
        log_error "Info.plist not found in app bundle: $app_path"
        return 1
    fi
    
    # Extract CFBundleShortVersionString (semantic version)
    local semantic_version
    semantic_version=$(defaults read "$info_plist" CFBundleShortVersionString 2>/dev/null)
    
    if [[ -z "$semantic_version" ]]; then
        log_error "Could not extract CFBundleShortVersionString from Info.plist"
        return 1
    fi
    
    log_info "📦 Extracted semantic version: $semantic_version"
    echo "$semantic_version"
}

# Create appcast using existing Sparkle signature
process_sparkle() {
    local dmg_path="$1"
    local version="$2"
    local release_notes="$3"
    local signature="$4"
    
    log_step 13 "Creating appcast for Sparkle updates"
    
    log_info "🚀 Creating appcast for Sparkle..."
    log_info "📦 Version: $version"
    log_info "📝 Notes: $release_notes"
    log_info "📁 Input DMG: $dmg_path"
    log_info "🔑 Using existing Sparkle signature"
    
    # Extract semantic version from the app bundle (if available)
    local semantic_version="$version"
    if [[ -d "$dmg_path" ]]; then
        # If DMG is mounted, try to extract version from the app inside
        local mounted_apps
        mounted_apps=$(find "$dmg_path" -name "*.app" -type d 2>/dev/null | head -1)
        if [[ -n "$mounted_apps" ]]; then
            local extracted_version
            extracted_version=$(extract_semantic_version "$mounted_apps")
            if [[ -n "$extracted_version" ]]; then
                semantic_version="$extracted_version"
                log_info "📦 Using semantic version from app bundle: $semantic_version"
            fi
        fi
    fi

    # Get file size
    log_info "📏 Getting file size..."
    local dmg_size
    dmg_size=$(stat -f%z "$dmg_path" 2>/dev/null || stat -c%s "$dmg_path" 2>/dev/null)
    if [ -z "$dmg_size" ]; then
        dmg_size=$(ls -la "$dmg_path" | awk '{print $5}')
    fi
    log_info "📏 DMG size: $dmg_size bytes"

    log_success "✅ Using existing Sparkle signature"
    log_info "🔑 Signature: $signature"

    # Create output DMG name
    local output_dmg="VoiceX-$version.dmg"
    cp "$dmg_path" "$output_dmg"
    
    # Remove the original DMG to avoid duplicates
    if [ "$dmg_path" != "$output_dmg" ]; then
        log_info "🧹 Removing original DMG: $(basename "$dmg_path")"
        rm -f "$dmg_path"
    fi

    log_info "📄 Creating appcast.xml..."

    # Create single-version appcast
    local pub_date
    pub_date=$(date -R)

    # Clean and validate signature
    local clean_signature="$signature"
    # Remove any whitespace/newlines from signature
    clean_signature=$(echo "$clean_signature" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Validate signature format (should be base64-like)
    if [[ ! "$clean_signature" =~ ^[A-Za-z0-9+/=]+$ ]]; then
        log_error "Invalid signature format: $clean_signature"
        return 1
    fi
    
    log_info "Using cleaned signature: $clean_signature"
    
    cat > appcast.xml << XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>VoiceX Updates</title>
        <description>VoiceX automatic updates</description>
        <language>en</language>
        
        <item>
            <title>VoiceX $version</title>
            <description><![CDATA[
                <h2>VoiceX $version</h2>
                <p>$release_notes</p>
                <ul>
                    <li>Latest features and improvements</li>
                    <li>Performance optimizations</li>
                    <li>Bug fixes and stability updates</li>
                    <li>Enhanced user experience</li>
                </ul>
            ]]></description>
            <pubDate>$pub_date</pubDate>
            <sparkle:version>$semantic_version</sparkle:version>
            <sparkle:shortVersionString>$semantic_version</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>12.0</sparkle:minimumSystemVersion>
            <sparkle:criticalUpdate/>
            <enclosure url="https://github.com/voicex-ai/macapp-updater/releases/download/v$version/VoiceX-$version.dmg"
                       sparkle:version="$semantic_version"
                       sparkle:shortVersionString="$semantic_version"
                       sparkle:edSignature="$clean_signature"
                       length="$dmg_size"
                       type="application/octet-stream"/>
        </item>
    </channel>
</rss>
XML

    log_success "✅ Sparkle processing complete"
    echo "$output_dmg"
}

# Commit appcast to repository
commit_appcast() {
    local version="$1"
    local release_notes="$2"
    
    log_step 14 "Committing appcast to repository"

    # Check git status
    if git diff --quiet appcast.xml; then
        log_warning "No changes to appcast.xml - skipping commit"
    else
        log_info "Committing appcast.xml changes..."
        
        # Add and commit appcast
        git add appcast.xml
        git commit -m "Release v$version: Update appcast

$release_notes"
        
        log_success "✅ Appcast committed to repository"
    fi
}

# ---------------- Main flow ----------------
main() {
    # Check arguments
    if [ $# -lt 3 ]; then
        echo "Usage: $0 <version> \"<release_notes>\" [path-to-xcarchive | path-to-app | path-to-dir]"
        echo "Example: $0 1.2.0 \"Bug fixes and new features\" ./VoiceX.xcarchive"
        echo "Example: $0 1.2.0 \"Bug fixes and new features\" ./VoiceX.app"
        exit 1
    fi

    local version="$1"
    local release_notes="$2"
    local inpath="${3:-.}"
    
    log_header "🚀 VoiceX Complete Release Pipeline"
    log_info "📦 Version: $version"
    log_info "📝 Release Notes: $release_notes"
    log_info "📁 Archive Path: $inpath"
    echo ""

    local workdir
    workdir="$(check_prerequisites "$inpath")"

    # Find apps
    local -a apps=()
    if ! while IFS= read -r line; do apps+=("$line"); done < <(find_app_bundles "$workdir"); then
        # Provide helpful diagnostics
        log_error "No .app bundle found in '$workdir' or expected archive locations."
        log_info "Try one of the following:"
        log_info "  - Pass the path to the .xcarchive directory (e.g. /path/MyApp.xcarchive)"
        log_info "  - Pass the path to the .app bundle directly (e.g. /path/MyApp.app)"
        log_info "  - Ensure the .app is under Products/Applications in the .xcarchive"
        log_info "Debug: listing directories (top levels):"
        find "$workdir" -maxdepth 2 -type d -print | sed -n '1,200p' >&2
        log_info "You can also run: find \"$workdir\" -type d -name \"*.app\""
        exit 1
    fi

    log_info "Found ${#apps[@]} .app bundle(s). Listing (first 20):"
    local idx=0
    for p in "${apps[@]}"; do
        idx=$((idx+1))
        printf '  %2d) %s\n' "$idx" "$p" >&2
        (( idx >= 20 )) && break
    done

    # By default use the first app found
    local app_path="${apps[0]}"
    local app_name
    app_name="$(basename "$app_path" .app)"

    log_info "Using app: $app_path (name: $app_name)"

    # Sign
    sign_app "$app_path"

    # Zip for notarization
    local zip_path
    zip_path="$(create_app_zip "$app_path" "$app_name")"

    if ! submit_for_notarization "$zip_path" "app" 5; then
        log_error "App notarization failed; aborting"
        exit 1
    fi

    attempt_stapling "$app_path" "app" 6

    # Clean up zip file after notarization
    log_info "🧹 Cleaning up notarization zip file..."
    rm -f *notarization*.zip

    # Create DMG
    local dmg_path
    dmg_path="$(create_dmg "$app_path" "$app_name")"

    # Sign DMG with Developer ID first
    sign_dmg "$dmg_path"

    # Setup Sparkle tools
    setup_sparkle

    # Sign DMG with Sparkle BEFORE notarization
    log_step 9 "Signing DMG with Sparkle before notarization"
    local sparkle_signature
    sparkle_signature=$(./sign_update "$dmg_path" "eddsa_key_VoiceX.private")
    
    if [ $? -ne 0 ] || [ -z "$sparkle_signature" ]; then
        log_error "❌ Error: Failed to sign DMG with Sparkle"
        exit 1
    fi
    
    log_success "✅ DMG signed with Sparkle"
    log_info "🔑 Sparkle Signature: $sparkle_signature"

    # Now notarize the Sparkle-signed DMG
    if ! submit_for_notarization "$dmg_path" "DMG" 10; then
        log_error "DMG notarization failed; aborting"
        exit 1
    fi

    attempt_stapling "$dmg_path" "DMG" 11

    if verify_dmg "$dmg_path"; then
        log_header "======================================"
        log_success "NOTARIZATION COMPLETED SUCCESSFULLY!"
        log_header "======================================"
        log_success "Ready for distribution: $dmg_path"
    else
        log_error "Final verification failed"
        exit 1
    fi

    # Process DMG for Sparkle (create appcast without re-signing)
    local final_dmg
    final_dmg="$(process_sparkle "$dmg_path" "$version" "$release_notes" "$sparkle_signature")"

    # Commit appcast
    commit_appcast "$version" "$release_notes"

    # Final summary
    log_header "🎉 COMPLETE RELEASE PIPELINE FINISHED!"
    log_header "======================================="
    log_success "📦 Version: v$version"
    log_success "📄 Appcast: appcast.xml (committed to repository)"
    log_success "📦 DMG: $final_dmg"
    log_success "📝 Release Notes: $release_notes"

    echo ""
    log_header "📋 Next Steps:"
    echo "1. 📤 Upload $final_dmg to GitHub Release:"
    echo "   https://github.com/voicex-ai/macapp-updater/releases/new"
    echo ""
    echo "2. 🏷️  Create release with tag: v$version"
    echo ""
    echo "3. 📝 Use these release notes:"
    echo "   $release_notes"
    echo ""
    echo "4. 🔄 Push repository changes:"
    echo "   git push origin master"
    echo ""
    echo "5. ✅ Verify release:"
    echo "   https://raw.githubusercontent.com/voicex-ai/macapp-updater/main/appcast.xml"
    echo ""
    log_success "🔄 Users will receive automatic updates within 1 hour!"

    # Show appcast preview
    echo ""
    log_header "📄 Appcast Preview:"
    head -20 appcast.xml

    echo ""
    log_success "🎯 Ready for manual GitHub release creation!"
}

# ---------------- Entry ----------------
main "$@"
