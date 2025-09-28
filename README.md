# VoiceX macOS App Updater

A professional Sparkle-based update system for VoiceX macOS application, providing seamless automatic updates for users.

## 🚀 Features

- **Automatic Updates**: Seamless background updates using Sparkle framework
- **Secure Signing**: EdDSA cryptographic signatures for update integrity
- **Professional Workflow**: Streamlined scripts for DMG processing and deployment
- **GitHub Integration**: Automated release management with GitHub Releases

## 📋 Prerequisites

- macOS development environment
- GitHub repository with releases enabled
- VoiceX app configured with Sparkle framework

## 🛠️ Setup

### 1. Initial Configuration

Run the setup script to download Sparkle tools and generate cryptographic keys:

```bash
./setup_sparkle_keys.sh
```

This script will:
- Download the latest Sparkle tools
- Generate EdDSA key pair for signing updates
- Display the public key for integration into your app

### 2. App Integration

Add the public key to your VoiceX app's `Info.plist`:

```xml
<key>SUPublicEDKey</key>
<string>YOUR_PUBLIC_KEY_HERE</string>
```

## 📦 Release Process

### Processing DMG Files

Use the processing script to prepare your DMG for release:

```bash
./process_dmg_for_sparkle.sh <version> "<release_notes>" <path_to_dmg>
```

**Example:**
```bash
./process_dmg_for_sparkle.sh 1.2.0 "Bug fixes and performance improvements" ./VoiceX-notarized.dmg
```

This script will:
- Sign the DMG with your private key
- Generate a complete `appcast.xml`
- Create a properly named release file
- Provide next steps for GitHub release

### GitHub Release

1. Create a new release on GitHub
2. Tag: `v<version>` (e.g., `v1.2.0`)
3. Upload the signed DMG file
4. Commit and push the updated `appcast.xml`

## 🔗 Appcast Configuration

**Appcast URL:** `https://raw.githubusercontent.com/voicex-ai/macapp-updater/main/appcast.xml`

Configure this URL in your VoiceX app's Sparkle settings.

## 📁 Repository Structure

```
macapp-updater/
├── setup_sparkle_keys.sh          # Initial setup and key generation
├── process_dmg_for_sparkle.sh     # DMG processing and signing
├── appcast.xml                    # Sparkle update feed
├── releases/                      # Release artifacts
└── .gitignore                    # Excludes generated files and keys
```

## 🔒 Security

- Private keys are excluded from version control
- All updates are cryptographically signed
- Generated tools are automatically ignored by git
- DMG files are processed locally and uploaded separately

## 🚨 Important Notes

- **Never commit private keys** to the repository
- Always use notarized DMG files for releases
- Test updates in a development environment first
- Keep the public key synchronized between app and updater

## 📚 Documentation

- [Sparkle Framework Documentation](https://sparkle-project.org/documentation/)
- [macOS App Notarization](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

## 🤝 Contributing

This repository is maintained for VoiceX application updates. For issues or improvements, please contact the development team.

---

**VoiceX** - Professional macOS Application Updates