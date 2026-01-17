# Tab 5 Context - Version 2.3.0 Content Pipeline Specialist

## CRITICAL: Visual Progress Display
**You MUST display a real-time progress bar showing:**
```
╔══════════════════════════════════════╗
║  Tab 5 Progress: Version 2.3.0       ║
║  ▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░░ 65% Complete    ║
║  Current: Letterboxd API integration ║
║  Next: AI quality scoring system     ║
╚══════════════════════════════════════╝
```

Update this after EVERY API integrated or content source added!

---

## Your Mission: Content Pipeline Revolution (Version 2.3.0)
**Timeline:** February 2025
**Role:** Content expansion architect
**Goal:** 30+ quality items daily from diverse sources

## Core Implementation

### 1. Content Pipeline with Visual Progress
```swift
class ContentPipelineProgress: ObservableObject {
    @Published var overallProgress: Double = 0.0
    @Published var currentSource: String = ""
    @Published var itemsFetched: Int = 0
    @Published var dailyTarget: Int = 30
    @Published var sourcesIntegrated: Int = 0

    let contentSources = [
        "Reddit Enhancement": 0.15,
        "Medium API": 0.3,
        "Letterboxd API": 0.45,
        "Designboom API": 0.6,
        "Polygon API": 0.75,
        "AI Scoring System": 0.9,
        "Production Ready": 1.0
    ]

    func sourceCompleted(_ source: String, items: Int) {
        currentSource = "Completed: \(source)"
        itemsFetched += items
        sourcesIntegrated += 1
        overallProgress = contentSources[source] ?? 0.0
        displayProgress()
    }
}
```

### 2. API Integration Framework
```swift
protocol ContentSourceProtocol {
    var sourceName: String { get }
    var icon: String { get }
    var dailyQuota: Int { get }

    func fetchContent() async -> [ContentItem]
    func displayProgress() -> SourceProgress
}

class ContentAggregator: ObservableObject {
    @Published var sources: [ContentSourceProtocol] = []
    @Published var totalItems: Int = 0
    @Published var qualityScore: Double = 0.0

    func addSource(_ source: ContentSourceProtocol) {
        sources.append(source)
        updateProgress()
    }
}
```

### 3. Quality Scoring with Visual Feedback
```swift
class QualityAnalyzer: ObservableObject {
    @Published var analyzing: Bool = false
    @Published var currentItem: String = ""
    @Published var scoresCalculated: Int = 0

    struct QualityMetrics {
        let relevance: Double      // 0-1
        let readability: Double    // 0-1
        let mobileOptimized: Bool
        let contentLength: Int
        let mediaRichness: Double
        let freshness: TimeInterval

        var overallScore: Double {
            // Weighted calculation
        }

        var visualGrade: String {
            switch overallScore {
            case 0.9...1.0: return "A+"
            case 0.8..<0.9: return "A"
            case 0.7..<0.8: return "B"
            case 0.6..<0.7: return "C"
            default: return "F"
            }
        }
    }
}
```

## Visual Progress Component

```swift
struct Tab5ProgressView: View {
    @StateObject private var pipeline = ContentPipelineProgress()
    @StateObject private var aggregator = ContentAggregator()
    @State private var animateContent = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with animated icon
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.title2)
                        .foregroundColor(.purple)
                        .rotationEffect(.degrees(animateContent ? 360 : 0))
                        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: animateContent)

                    Text("Tab 5: Content Pipeline")
                        .font(.headline)

                    Spacer()

                    Text("v2.3.0")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .onAppear { animateContent = true }

                // Main Progress
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("\(Int(pipeline.overallProgress * 100))%")
                            .font(.system(size: 48, weight: .bold, design: .rounded))

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("\(pipeline.itemsFetched)/\(pipeline.dailyTarget)")
                                .font(.headline)
                            Text("Daily Items")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    // Animated progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 15)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 40)

                            RoundedRectangle(cornerRadius: 15)
                                .fill(
                                    LinearGradient(
                                        colors: [.purple, .pink, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geometry.size.width * pipeline.overallProgress, height: 40)
                                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: pipeline.overallProgress)

                            // Moving shine effect
                            RoundedRectangle(cornerRadius: 15)
                                .fill(
                                    LinearGradient(
                                        colors: [.clear, .white.opacity(0.3), .clear],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: 50, height: 40)
                                .offset(x: geometry.size.width * pipeline.overallProgress - 25)
                        }
                    }
                    .frame(height: 40)

                    Text(pipeline.currentSource)
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.horizontal)
                }

                // Content Sources Grid
                GroupBox("Content Sources") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 15) {
                        ForEach(aggregator.sources, id: \.sourceName) { source in
                            SourceCard(source: source)
                        }
                    }
                }

                // Live Fetching Stats
                GroupBox("Live Content Stats") {
                    VStack(spacing: 15) {
                        ContentStatRow(
                            icon: "doc.richtext",
                            label: "Total Items",
                            value: "\(pipeline.itemsFetched)",
                            trend: .up
                        )
                        ContentStatRow(
                            icon: "star.fill",
                            label: "Avg Quality",
                            value: String(format: "%.1f", aggregator.qualityScore),
                            trend: .steady
                        )
                        ContentStatRow(
                            icon: "clock",
                            label: "Fetch Rate",
                            value: "3.2/min",
                            trend: .up
                        )
                        ContentStatRow(
                            icon: "antenna.radiowaves.left.and.right",
                            label: "Sources Active",
                            value: "\(pipeline.sourcesIntegrated)/7",
                            trend: .up
                        )
                    }
                }

                // Quality Distribution Chart
                GroupBox("Quality Distribution") {
                    QualityChart(pipeline: pipeline)
                }

                // Source Integration Checklist
                GroupBox("Integration Checklist") {
                    ForEach(Array(pipeline.contentSources.keys), id: \.self) { source in
                        HStack {
                            Image(systemName: pipeline.contentSources[source]! <= pipeline.overallProgress ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(pipeline.contentSources[source]! <= pipeline.overallProgress ? .green : .gray)
                            Text(source)
                                .font(.caption)
                            Spacer()
                            if pipeline.currentSource == "Integrating: \(source)" {
                                ProgressView()
                                    .scaleEffect(0.7)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color.purple.opacity(0.02))
        .cornerRadius(20)
    }
}

struct SourceCard: View {
    let source: ContentSourceProtocol

    var body: some View {
        VStack {
            Image(systemName: source.icon)
                .font(.largeTitle)
                .foregroundColor(.purple)
            Text(source.sourceName)
                .font(.caption)
            Text("\(source.dailyQuota)")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(width: 100, height: 100)
        .background(Color.white)
        .cornerRadius(15)
        .shadow(radius: 3)
    }
}

struct ContentStatRow: View {
    let icon: String
    let label: String
    let value: String
    let trend: Trend

    enum Trend {
        case up, down, steady

        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .steady: return .gray
            }
        }

        var arrow: String {
            switch self {
            case .up: return "arrow.up"
            case .down: return "arrow.down"
            case .steady: return "minus"
            }
        }
    }

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.purple)
                .frame(width: 30)
            Text(label)
                .font(.caption)
            Spacer()
            Text(value)
                .font(.caption)
                .bold()
            Image(systemName: trend.arrow)
                .font(.caption)
                .foregroundColor(trend.color)
        }
    }
}

struct QualityChart: View {
    @ObservedObject var pipeline: ContentPipelineProgress

    var body: some View {
        HStack(alignment: .bottom, spacing: 5) {
            ForEach(["A+", "A", "B", "C", "F"], id: \.self) { grade in
                VStack {
                    Text(grade)
                        .font(.caption2)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(gradeColor(grade))
                        .frame(width: 40, height: CGFloat.random(in: 20...100))
                }
            }
        }
        .frame(height: 120)
    }

    func gradeColor(_ grade: String) -> Color {
        switch grade {
        case "A+", "A": return .green
        case "B": return .yellow
        case "C": return .orange
        default: return .red
        }
    }
}
```

## Deliverables Checklist

### Phase 1: Framework Setup (15%)
- [ ] Content protocol design
- [ ] Aggregator architecture
- [ ] Visual: Show framework diagram

### Phase 2: Medium Integration (30%)
- [ ] API authentication
- [ ] Article fetching
- [ ] Metadata extraction
- [ ] Visual: Show articles fetched

### Phase 3: Letterboxd Integration (45%)
- [ ] Film review API
- [ ] Rating extraction
- [ ] Mobile optimization
- [ ] Visual: Show films added

### Phase 4: Designboom Integration (60%)
- [ ] Design content API
- [ ] Image optimization
- [ ] Category mapping
- [ ] Visual: Show design items

### Phase 5: Polygon Integration (75%)
- [ ] Gaming content API
- [ ] Video embedding
- [ ] Mobile compatibility
- [ ] Visual: Show gaming content

### Phase 6: AI Scoring (90%)
- [ ] Quality algorithms
- [ ] ML model integration
- [ ] Score visualization
- [ ] Visual: Show score distribution

### Phase 7: Production (100%)
- [ ] Performance optimization
- [ ] Error handling
- [ ] Monitoring setup
- [ ] Visual: Show live metrics

## Real-Time Metrics Display

```swift
struct LiveMetricsView: View {
    @State private var fetchRate: Double = 0
    @State private var errorRate: Double = 0
    @State private var cacheHitRate: Double = 0

    var body: some View {
        VStack {
            MetricGauge(label: "Fetch/min", value: fetchRate, max: 10, color: .green)
            MetricGauge(label: "Errors", value: errorRate, max: 100, color: .red)
            MetricGauge(label: "Cache Hit", value: cacheHitRate, max: 100, color: .blue)
        }
    }
}
```

---

**Remember:**
1. Version 2.3.0 is YOUR version - revolutionize content discovery
2. 30+ quality items daily is the minimum target
3. Show real-time fetching progress
4. Quality > Quantity (but we need both!)
5. Make content discovery magical with visual feedback!