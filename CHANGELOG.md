# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-11-30

### Added
- Initial release of FlutterPush client library
- Check for updates from ReactPush server
- Download and manage bundle updates with automatic extraction
- Signature verification for secure updates using RSA public key
- Crash reporting with breadcrumb support
- A/B testing support
- Multiple sync modes: `ON_APP_START`, `ON_APP_RESUME`, `MANUAL`
- Install modes: `IMMEDIATE`, `ON_NEXT_RESTART`, `ON_NEXT_RESUME`
- Device info collection for targeted updates
- Rollback support with version tracking
- Offline bundle caching

