#!/bin/bash

# Simple script to update the appcast (no signatures)
# Usage: ./update_appcast.sh 1.2.0 "New features added"

VERSION=$1
NOTES=$2

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> [notes]"
    echo "Example: $0 1.2.0 'Bug fixes and improvements'"
    exit 1
fi

if [ -z "$NOTES" ]; then
    NOTES="Updates and improvements"
fi

# Get current date
PUB_DATE=$(date -R)

# Update the appcast (no signature)
cat > appcast.xml << XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>VoiceX Updates</title>
        <description>VoiceX App Updates</description>
        <language>en</language>
        
        <item>
            <title>VoiceX $VERSION - Critical Update</title>
            <description><![CDATA[
                <h2>Important Update Available</h2>
                <p>$NOTES</p>
                <p><strong>This update is required for continued use of VoiceX.</strong></p>
            ]]></description>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:version>$VERSION</sparkle:version>
            <sparkle:shortVersionString>$VERSION</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>12.0</sparkle:minimumSystemVersion>
            <sparkle:criticalUpdate/>
            <enclosure url="https://github.com/voicex-ai/macapp-updater/releases/download/v$VERSION/VoiceX-$VERSION.dmg"
                       sparkle:version="$VERSION"
                       sparkle:shortVersionString="$VERSION"
                       length="52428800"
                       type="application/octet-stream"/>
        </item>
    </channel>
</rss>
XML

echo "✅ Updated appcast.xml to version $VERSION (no signature required)"
echo "📝 Next steps:"
echo "1. Create GitHub release: https://github.com/voicex-ai/macapp-updater/releases/new"
echo "2. Tag: v$VERSION"
echo "3. Upload VoiceX-$VERSION.dmg"
echo "4. Commit and push appcast.xml"
echo ""
echo "🔗 Your appcast URL:"
echo "https://raw.githubusercontent.com/voicex-ai/macapp-updater/main/appcast.xml"
