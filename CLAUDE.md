# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Orbits is a SwiftUI-based contact relationship management (CRM) application designed for iOS and macOS. The project consists of three main targets:
- **orbits**: Main iOS application for managing personal relationships and tracking contact frequency
- **OrbitsHelper**: macOS helper application for syncing contacts and messages from the system
- **iMessageExtension**: iOS Messages app extension for quick note-taking about contacts

## Architecture

### Project Structure
- **OrbitsKit Package**: Shared Swift Package containing data models, services, and authentication logic
  - Models: Person, Orbit, Tag, Note, MessageExcerpt, etc.
  - Services: AuthManager, SupabaseManager, SupabaseService
  - Backend: Supabase (PostgreSQL + Auth)
  
- **Main Apps**: Both iOS and macOS apps follow MVVM architecture with SwiftUI views and ViewModels
- **Authentication**: Shared across all targets using OrbitsKit's AuthManager

### Key Services
- **SyncEngine** (macOS): Syncs contacts and messages from local system to Supabase
- **ContactEnrichmentService**: Normalizes and processes contact data
- **MessageDatabaseService**: Reads iMessage database (requires Full Disk Access)
- **PermissionsManager**: Handles macOS permissions (Contacts, Full Disk Access)

## Development Commands

### Building
```bash
# Build iOS app
xcodebuild -scheme orbits -configuration Debug build

# Build macOS helper
xcodebuild -scheme OrbitsHelper -configuration Debug build

# Build all targets
xcodebuild -alltargets -configuration Debug build
```

### Testing
```bash
# Run iOS tests
xcodebuild test -scheme orbits -destination 'platform=iOS Simulator,name=iPhone 15'

# Run macOS tests
xcodebuild test -scheme OrbitsHelper -destination 'platform=macOS'

# Run package tests
cd Packages/OrbitsKit && swift test
```

### Code Quality
```bash
# Swift format (if swift-format is installed)
swift-format -i -r orbits/ OrbitsHelper/ Packages/

# SwiftLint (if installed)
swiftlint --fix
```

## Key Implementation Details

### Database Schema
- **person** table: Stores contact information with unique constraint on (user_id, contact_identifier)
- **orbit** table: Defines contact frequency intervals
- **note** table: Stores notes about people
- Uses snake_case in database, converted to camelCase in Swift models

### Permissions (macOS)
- Contacts Access: Required for reading system contacts
- Full Disk Access: Required for reading Messages database
- Entitlements: com.apple.security.personal-information.addressbook

### Authentication Flow
1. User signs in/up through AuthenticationView
2. AuthManager (singleton) manages Supabase auth session
3. Apps switch between auth and main views based on session state

### Sync Process (OrbitsHelper)
1. Checks user session and permissions
2. Creates handle-to-contact mapping from Contacts
3. Fetches message threads from Messages.app database
4. Enriches contacts with message data (unread count, last message date)
5. Deduplicates and syncs to Supabase using upsert

## Common Tasks

### Adding a New Model
1. Create model struct in `Packages/OrbitsKit/Sources/OrbitsKit/Models/`
2. Ensure it conforms to Codable, Identifiable, and Sendable
3. Add corresponding service methods in SupabaseService

### Working with Supabase
- Client configured in SupabaseManager.swift with custom JSON encoder/decoder
- Uses ISO8601 date format with fractional seconds
- All database operations go through SupabaseService

### Debugging Sync Issues
1. Check PermissionsManager.getPermissionStatus() for access rights
2. Verify handleToContactMap creation in LocalContactsProvider
3. Check MessageDatabaseService for SQL query issues
4. Look for duplicate contact_identifier entries in sync logs