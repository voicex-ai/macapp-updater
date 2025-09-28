# VoiceX macOS App Updater

A public repository hosting the Sparkle appcast for VoiceX macOS application automatic updates.

## 🚀 About

This repository provides the update feed for VoiceX macOS application using the Sparkle framework. It hosts the `appcast.xml` file that enables seamless automatic updates for VoiceX users.

## 🔗 Appcast Configuration

**Appcast URL:** `https://raw.githubusercontent.com/voicex-ai/macapp-updater/main/appcast.xml`

Configure this URL in your VoiceX app's Sparkle settings to enable automatic updates.

## 📁 Repository Structure

```
macapp-updater/
├── appcast.xml                    # Sparkle update feed
├── releases/                      # Release artifacts directory
├── .gitignore                    # Security and privacy protection
└── README.md                     # This documentation
```

## 🔒 Security & Privacy

This public repository is designed with security in mind:

- **No sensitive data**: Private keys, certificates, and personal information are excluded
- **Minimal footprint**: Only essential files for the update system are public
- **Secure updates**: All releases are cryptographically signed and verified
- **Clean structure**: Professional appearance with no internal tooling exposed

## 📦 How Updates Work

1. **Release Creation**: New versions are released through GitHub Releases
2. **Appcast Update**: The `appcast.xml` is updated with new version information
3. **User Notification**: VoiceX automatically checks for updates and notifies users
4. **Secure Download**: Updates are downloaded and verified using cryptographic signatures

## 🚨 Important Notes

- This repository contains only the public update feed
- All DMG files and signing tools are managed privately
- Updates are automatically distributed to users within 1 hour of release
- The appcast follows Sparkle framework standards for security and reliability

## 📚 Documentation

- [Sparkle Framework Documentation](https://sparkle-project.org/documentation/)
- [macOS App Notarization](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution)

## 🤝 Support

This repository is maintained for VoiceX application updates. For technical support or questions about VoiceX, please contact the development team.

---

**VoiceX** - Professional macOS Application Updates