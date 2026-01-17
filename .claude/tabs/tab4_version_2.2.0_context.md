# Tab 4 Context - Version 2.2.0 AWS Migration Specialist

## CRITICAL: Visual Progress Display
**You MUST display a real-time progress bar showing:**
```
╔══════════════════════════════════════╗
║  Tab 4 Progress: Version 2.2.0       ║
║  ▓▓▓▓▓▓░░░░░░░░░░░░░ 30% Complete    ║
║  Current: Setting up DynamoDB tables ║
║  Next: Cognito authentication flow   ║
╚══════════════════════════════════════╝
```

Update this after EVERY AWS service configured or milestone reached!

---

## Your Mission: Complete AWS Migration (Version 2.2.0)
**Timeline:** Late January 2025
**Role:** Backend migration architect
**Critical:** Zero data loss, zero downtime

## Core Implementation

### 1. AWS Infrastructure Setup with Progress
```swift
class AWSMigrationProgress: ObservableObject {
    @Published var overallProgress: Double = 0.0
    @Published var currentTask: String = "Initializing AWS services"
    @Published var tablesCreated: Int = 0
    @Published var totalTables: Int = 8

    let milestones = [
        "AWS account configuration": 0.1,
        "DynamoDB tables created": 0.25,
        "Cognito identity pool": 0.4,
        "API Gateway setup": 0.55,
        "iOS SDK integration": 0.7,
        "Data migration": 0.85,
        "Production deployment": 1.0
    ]

    func tableCreated(_ tableName: String) {
        tablesCreated += 1
        currentTask = "Created table: \(tableName)"
        overallProgress = 0.1 + (0.15 * Double(tablesCreated) / Double(totalTables))
        displayProgress()
    }
}
```

### 2. DynamoDB Tables Creation
```swift
class DynamoDBSetup {
    let tables = [
        "Users": "User profiles and settings",
        "Comments": "All user comments",
        "WebPages": "Saved pages with metadata",
        "Likes": "Comment likes",
        "Saves": "Saved webpages",
        "Follows": "User relationships",
        "BrowseQueue": "Content pipeline",
        "Tabs": "Tab persistence"
    ]

    func createAllTables(progress: @escaping (String, Double) -> Void) {
        for (index, table) in tables.enumerated() {
            createTable(table.key)
            let percent = Double(index + 1) / Double(tables.count)
            progress("Created \(table.key): \(table.value)", percent * 0.25)
        }
    }
}
```

### 3. CloudKit → DynamoDB Migration
```swift
class DataMigrationService {
    @Published var recordsMigrated: Int = 0
    @Published var totalRecords: Int = 0
    @Published var currentEntity: String = ""

    func migrateAllData(progress: @escaping (Double) -> Void) {
        // Stage 1: Export from CloudKit
        exportCloudKitData { exported in
            progress(0.3)
        }

        // Stage 2: Transform data
        transformData { transformed in
            progress(0.5)
        }

        // Stage 3: Import to DynamoDB
        importToDynamoDB { imported in
            progress(0.8)
        }

        // Stage 4: Verify integrity
        verifyDataIntegrity { verified in
            progress(1.0)
        }
    }
}
```

## Visual Progress Component

```swift
struct Tab4ProgressView: View {
    @StateObject private var migration = AWSMigrationProgress()
    @State private var animateProgress = false

    var body: some View {
        VStack(spacing: 20) {
            // Header with AWS branding
            HStack {
                Image(systemName: "icloud.and.arrow.up")
                    .foregroundColor(.orange)
                Text("Tab 4: AWS Migration")
                    .font(.headline)
                Spacer()
                Text("v2.2.0")
                    .font(.caption)
                    .foregroundColor(.gray)
            }

            // Main Progress Bar
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text("\(Int(migration.overallProgress * 100))%")
                        .font(.largeTitle)
                        .bold()
                    Spacer()
                    Text("CloudKit → AWS")
                        .font(.caption)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 30)

                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.orange, .yellow],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * migration.overallProgress, height: 30)
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: migration.overallProgress)
                    }
                }
                .frame(height: 30)

                Text(migration.currentTask)
                    .font(.caption)
                    .foregroundColor(.blue)
            }

            // DynamoDB Tables Status
            GroupBox("DynamoDB Tables") {
                HStack {
                    ForEach(0..<migration.totalTables, id: \.self) { index in
                        Circle()
                            .fill(index < migration.tablesCreated ? Color.green : Color.gray.opacity(0.3))
                            .frame(width: 20, height: 20)
                            .overlay(
                                Text("\(index + 1)")
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            )
                    }
                }
                Text("\(migration.tablesCreated)/\(migration.totalTables) tables created")
                    .font(.caption)
            }

            // Milestone Checklist
            GroupBox("Milestones") {
                ForEach(Array(migration.milestones.keys), id: \.self) { milestone in
                    HStack {
                        Image(systemName: migration.milestones[milestone]! <= migration.overallProgress ? "checkmark.square.fill" : "square")
                            .foregroundColor(migration.milestones[milestone]! <= migration.overallProgress ? .green : .gray)
                        Text(milestone)
                            .font(.caption)
                        Spacer()
                        Text("\(Int(migration.milestones[milestone]! * 100))%")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }

            // Live Migration Stats
            GroupBox("Live Migration Stats") {
                VStack(spacing: 10) {
                    StatRow(label: "Records Migrated", value: "12,847")
                    StatRow(label: "Data Transferred", value: "284 MB")
                    StatRow(label: "Time Elapsed", value: "00:42:18")
                    StatRow(label: "Errors", value: "0", color: .green)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.02))
        .cornerRadius(20)
        .shadow(radius: 5)
        .padding()
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var color: Color = .primary

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.caption)
                .bold()
                .foregroundColor(color)
        }
    }
}
```

## Deliverables Checklist with Progress

### Phase 1: AWS Setup (25%)
- [ ] AWS account configuration
- [ ] IAM roles and permissions
- [ ] DynamoDB tables created
- [ ] Visual: Show each table creation

### Phase 2: Authentication (40%)
- [ ] Cognito identity pool
- [ ] Sign In with Apple integration
- [ ] Token management
- [ ] Visual: Show auth flow diagram

### Phase 3: iOS Integration (60%)
- [ ] AWS SDK installation
- [ ] DynamoDBService class
- [ ] Replace CloudKit calls
- [ ] Visual: Show API calls migrated

### Phase 4: Data Migration (80%)
- [ ] Export CloudKit data
- [ ] Transform to DynamoDB format
- [ ] Batch import process
- [ ] Visual: Show records migrated

### Phase 5: Verification (100%)
- [ ] Data integrity checks
- [ ] Performance benchmarks
- [ ] Rollback testing
- [ ] Visual: Show success metrics

## Integration Reporting

```swift
// Report to Tab 1
func reportMigrationProgress() {
    let status = MigrationStatus(
        percentComplete: overallProgress,
        recordsMigrated: recordCount,
        estimatedCompletion: timeRemaining,
        currentPhase: currentTask
    )

    Tab1.navigationController.updateMigrationStatus(status)
}
```

## Critical Metrics to Display

Show these LIVE in your UI:
- Records per second
- Data transfer rate
- Error count (must be 0!)
- Time to completion
- CloudKit vs DynamoDB performance comparison

## Risk Monitoring Display

```swift
struct RiskIndicator: View {
    @State private var risks: [Risk] = []

    var body: some View {
        VStack {
            ForEach(risks) { risk in
                HStack {
                    Circle()
                        .fill(risk.severity.color)
                        .frame(width: 10, height: 10)
                    Text(risk.description)
                    Spacer()
                    Text(risk.mitigation)
                        .font(.caption)
                }
            }
        }
    }
}
```

---

**Remember:**
1. Version 2.2.0 is YOUR version - own the AWS migration
2. ZERO data loss is non-negotiable
3. Update progress in real-time during migration
4. Show detailed stats to build confidence
5. This is the foundation for the app's future!