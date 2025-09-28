#!/bin/bash

# Process notarized DMG for Sparkle updates
# Usage: ./process_dmg_for_sparkle.sh 0.2.0 "Release notes" /path/to/notarized.dmg

VERSION=$1
NOTES=$2
DMG_PATH=$3

if [ $# -ne 3 ]; then
    echo "Usage: $0 <version> <release_notes> <notarized_dmg_path>"
    echo "Example: $0 0.2.0 'Bug fixes and improvements' ./VoiceX-notarized.dmg"
    exit 1
fi

if [ ! -f "$DMG_PATH" ]; then
    echo "❌ Error: DMG file not found at $DMG_PATH"
    exit 1
fi

# Check for required files
if [ ! -f "./sign_update" ]; then
    echo "❌ Error: sign_update tool not found. Run ./setup_sparkle_keys.sh first"
    exit 1
fi

PRIVATE_KEY="eddsa_key_VoiceX.private"
if [ ! -f "$PRIVATE_KEY" ]; then
    echo "❌ Error: Private key not found. Run ./setup_sparkle_keys.sh first"
    exit 1
fi

echo "🚀 Processing DMG for Sparkle..."
echo "📦 Version: $VERSION"
echo "📝 Notes: $NOTES"
echo "📁 Input DMG: $DMG_PATH"

# Get file size
echo "📏 Getting file size..."
DMG_SIZE=$(stat -f%z "$DMG_PATH" 2>/dev/null || stat -c%s "$DMG_PATH" 2>/dev/null)
if [ -z "$DMG_SIZE" ]; then
    DMG_SIZE=$(ls -la "$DMG_PATH" | awk '{print $5}')
fi
echo "📏 DMG size: $DMG_SIZE bytes"

# Sign the DMG with Sparkle
echo "🔐 Signing DMG with Sparkle..."
SIGNATURE=$(./sign_update "$DMG_PATH" "$PRIVATE_KEY")

if [ $? -ne 0 ] || [ -z "$SIGNATURE" ]; then
    echo "❌ Error: Failed to sign DMG"
    exit 1
fi

echo "✅ DMG signed successfully"
echo "🔑 Signature: $SIGNATURE"

# Create output DMG name
OUTPUT_DMG="VoiceX-$VERSION.dmg"
cp "$DMG_PATH" "$OUTPUT_DMG"

echo "📄 Creating appcast.xml..."

# Create single-version appcast
PUB_DATE=$(date -R)

cat > appcast.xml << XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>VoiceX Updates</title>
        <description>VoiceX automatic updates</description>
        <language>en</language>
        
        <item>
            <title>VoiceX $VERSION</title>
            <description><![CDATA[
                <h2>VoiceX $VERSION</h2>
                <p>$NOTES</p>
                <ul>
                    <li>Latest features and improvements</li>
                    <li>Performance optimizations</li>
                    <li>Bug fixes and stability updates</li>
                    <li>Enhanced user experience</li>
                </ul>
            ]]></description>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>$VERSION</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>12.0</sparkle:minimumSystemVersion>
            <sparkle:criticalUpdate/>
            <enclosure url="https://github.com/voicex-ai/macapp-updater/releases/download/v$VERSION/VoiceX-$VERSION.dmg"
                       sparkle:version="$VERSION"
                       sparkle:shortVersionString="$VERSION"
                       sparkle:edSignature="$SIGNATURE"
                       length="$DMG_SIZE"
                       type="application/octet-stream"/>
        </item>
    </channel>
</rss>
XML

echo ""
echo "✅ PROCESSING COMPLETE!"
echo ""
echo "📋 Generated files:"
echo "   📦 Signed DMG: $OUTPUT_DMG"
echo "   📄 Appcast: appcast.xml"
echo ""
echo "📝 Next steps:"
echo "1. Create GitHub release: https://github.com/voicex-ai/macapp-updater/releases/new"
echo "2. Tag: v$VERSION"
echo "3. Upload: $OUTPUT_DMG"
echo "4. Commit and push appcast.xml:"
echo "   git add appcast.xml"
echo "   git commit -m 'Release v$VERSION'"
echo "   git push"
echo ""
echo "🔄 Users will auto-update within 1 hour!"
