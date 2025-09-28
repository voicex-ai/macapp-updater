#!/bin/bash

echo "🔑 Setting up fresh Sparkle keys..."

# Remove old keys if they exist
rm -f eddsa_key_*.private generate_keys sign_update

# Download Sparkle tools
echo "📥 Downloading Sparkle tools..."
curl -L -o sparkle-tools.zip "https://github.com/sparkle-project/Sparkle/releases/latest/download/Sparkle-for-Swift-Package-Manager.zip"

# Extract tools
unzip -j sparkle-tools.zip "bin/generate_keys" "bin/sign_update" -d ./
chmod +x generate_keys sign_update

# Generate new keys
echo "🔐 Generating new EdDSA key pair..."
./generate_keys

echo "✅ Setup complete!"
echo ""
echo "IMPORTANT: Copy the public key from above into your VoiceX app's Info.plist:"
echo "<key>SUPublicEDKey</key>"
echo "<string>YOUR_PUBLIC_KEY_HERE</string>"

# Clean up
rm -f sparkle-tools.zip
