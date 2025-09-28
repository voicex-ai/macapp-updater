#!/bin/bash

# Update appcast to single version
# Usage: ./update_version.sh 1.3.0 "New features and bug fixes"

VERSION=$1
NOTES=$2

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> [release_notes]"
    echo "Example: $0 1.3.0 'Major update with new features'"
    exit 1
fi

if [ -z "$NOTES" ]; then
    NOTES="Updates and improvements in version $VERSION"
fi

# Get current date
PUB_DATE=$(date -R)

# Replace entire appcast with single version
cat > appcast.xml << XML
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
    <channel>
        <title>VoiceX Updates</title>
        <description>VoiceX automatic updates</description>
        <language>en</language>
        
        <!-- Only ONE version - the current latest -->
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
                       sparkle:edSignature="REPLACE_WITH_SIGNATURE"
                       length="52428800"
                       type="application/octet-stream"/>
        </item>
    </channel>
</rss>
XML

echo "✅ Updated appcast to single version: $VERSION"
echo ""
echo "📝 Next steps:"
echo "1. Build VoiceX with version $VERSION in Info.plist"
echo "2. Create DMG: VoiceX-$VERSION.dmg"
echo "3. Create GitHub release:"
echo "   - Tag: v$VERSION"
echo "   - Upload: VoiceX-$VERSION.dmg"
echo "4. Replace signature in appcast.xml (if using signing)"
echo "5. Commit and push:"
echo "   git add appcast.xml"
echo "   git commit -m 'Update to v$VERSION'"
echo "   git push"
echo ""
echo "🔄 How it works:"
echo "   - Users with version < $VERSION will auto-update"
echo "   - Users with version = $VERSION will see no updates"
echo "   - Users with version > $VERSION will see no updates"
