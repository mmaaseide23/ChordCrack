# ChordCrack

<div align="center">
  <img src="https://raw.githubusercontent.com/mmaaseide23/ChordCrack_Assets/main/logo.png" alt="ChordCrack Logo" width="120" height="120">
  
  **Guitar Chord Ear Training Made Simple**
  
  [![iOS](https://img.shields.io/badge/iOS-18.0+-blue.svg)](https://developer.apple.com/ios/)
  [![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org/)
  [![License](https://img.shields.io/badge/License-Proprietary-red.svg)](LICENSE)
  [![App Store](https://img.shields.io/badge/App%20Store-Coming%20Soon-green.svg)](https://apps.apple.com)
</div>

## About

ChordCrack is a comprehensive guitar chord ear training app designed to help guitarists develop their ability to identify chords by sound. Through progressive difficulty levels and intelligent hint systems, users can improve their musical ear while tracking their progress.

### Key Features

- **Daily Challenges**: Practice basic chords with 5-round daily sessions
- **Multiple Difficulty Levels**: Power chords, barre chords, blues chords, and mixed practice
- **Progressive Hint System**: Audio hints that gradually reveal more information
- **Apple Sign-In Integration**: Secure authentication with privacy-focused options
- **Cross-Device Sync**: Progress saved and synchronized across all your devices
- **Biometric Security**: Face ID / Touch ID support for secure access
- **Achievement System**: Unlock milestones as you improve
- **Statistics Tracking**: Detailed progress analytics and performance metrics

## Technical Overview

### Architecture
- **Frontend**: SwiftUI with MVVM architecture
- **Backend**: Supabase for authentication and data storage
- **Audio**: Custom AudioManager with progressive hint system
- **Authentication**: Apple Sign-In, email/password with secure validation

### Requirements
- iOS 18.0+
- Xcode 15.0+
- Swift 5.9+
- Apple Developer Account (for Apple Sign-In)

## License

This project is proprietary software. See [LICENSE](LICENSE) for details.

### Usage Rights
- **Viewing**: Code may be viewed for educational purposes only
- **Distribution**: No distribution or commercial use permitted without permission
- **Contributions**: Contributions welcome via pull requests (become property of project owner)
- **Contact**: For licensing inquiries, email chordcrackhelp@gmail.com

## Development Setup

### Prerequisites
1. Apple Developer Account
2. Supabase account
3. Xcode 15.0 or later

### Installation
1. Clone the repository
```bash
git clone https://github.com/mmaaseide23/ChordCrack.git
cd ChordCrack
```

2. Configure your environment
```bash
cp ChordCrack/Config-Template.plist ChordCrack/Config.plist
# Edit Config.plist with your Supabase credentials
```

3. Set up Apple Sign-In
- Configure Service ID in Apple Developer Console
- Generate JWT token for Supabase
- Configure Apple provider in Supabase Authentication settings

4. Open in Xcode and build
```bash
open ChordCrack.xcodeproj
```

### Configuration Required
- Supabase project URL and publishable key
- Apple Developer Apple Sign-In configuration
- Privacy policy and terms of service URLs

## Privacy & Security

ChordCrack prioritizes user privacy and data security:

- **Minimal Data Collection**: Only collects necessary information for app functionality
- **Secure Authentication**: Industry-standard encryption and secure password handling
- **Privacy Controls**: Users can export or delete their data at any time
- **Compliance**: Meets GDPR, CCPA, and Apple App Store privacy requirements

See our [Privacy Policy](https://mmaaseide23.github.io/ChordCrack-Legal/privacy.html) for complete details.

## Support

For technical support or general inquiries:
- **Email**: chordcrackhelp@gmail.com
- **Response Time**: Within 48 hours

## Copyright

Copyright (c) 2025 Michael Maaseide. All rights reserved.

ChordCrack and associated trademarks are property of Michael Maaseide.
