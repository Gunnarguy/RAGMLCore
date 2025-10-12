# Apple Intelligence Integration Guide

**Last Updated:** October 11, 2025  
**iOS 26 Status:** Released with full Apple Intelligence support

## Overview

RAGMLCore now features comprehensive integration with Apple's AI ecosystem, with proper device capability detection and framework support across iOS 18.1 - 26.0+.

---

## Supported Apple Frameworks

### 🧠 Foundation Models (iOS 26.0+)
**Status:** ✅ Fully Integrated  
**Import:** `import FoundationModels`  
**Requirements:** A17 Pro+, A18, or M-series chip

**Capabilities:**
- On-device language model (~3B parameters)
- Automatic Private Cloud Compute fallback
- 8K context window
- Zero data retention
- End-to-end encryption

**Implementation:**
- `AppleFoundationLLMService` - Primary LLM service
- `LanguageModelSession` for streaming responses
- Hybrid RAG+LLM instructions for dual-mode operation

**Code Location:** `Services/LLMService.swift` (lines 40-235)

---

### ☁️ Private Cloud Compute (iOS 18.1+)
**Status:** ✅ Available (Automatic in Foundation Models)  
**Requirements:** iOS 18.1+, any device

**Capabilities:**
- Apple Silicon servers (same architecture as device)
- Cryptographically enforced zero data retention
- Seamless fallback for complex queries
- Higher token limits than on-device

**Implementation:**
- Automatic in `AppleFoundationLLMService`
- Optional user preference in Settings
- `@AppStorage("preferPrivateCloudCompute")`

**User Control:** Settings → Private Cloud Compute toggle

---

### ✍️ Writing Tools (iOS 18.1+)
**Status:** 📋 Framework Available (Not Yet Integrated)  
**Import:** `import WritingTools`  
**Requirements:** iOS 18.1+, any device

**Planned Use Cases:**
1. Proofreading user queries before RAG execution
2. Summarizing retrieved chunks for better context
3. Rewriting LLM responses for clarity
4. Integration in chat input field

**Integration Path:**
```swift
.writingToolsEnabled(true)
.onWritingToolsAction { action in
    switch action {
    case .proofread(let corrected): /* Apply corrections */
    case .rewrite(let alternatives): /* Show options */
    case .summarize(let summary): /* Use in RAG */
    }
}
```

---

### 📱 App Intents (Siri Integration)
**Status:** 📋 Framework Available (Not Yet Integrated)  
**Import:** `import AppIntents`  
**Requirements:** All iOS versions

**Planned Use Cases:**
1. "Hey Siri, query my documents about quarterly revenue"
2. "Add this document to my knowledge base"
3. "Summarize all documents about project X"

**Integration Path:**
```swift
struct QueryDocumentsIntent: AppIntent {
    static var title: LocalizedStringResource = "Query Documents"
    @Parameter(title: "Question") var question: String
    
    func perform() async throws -> some IntentResult {
        let ragService = RAGService()
        let response = try await ragService.query(question)
        return .result(value: response.generatedResponse)
    }
}
```

---

### 🎨 Image Playground (iOS 18.1+)
**Status:** 🔍 Detected (Not Applicable for RAG)  
**Import:** `import ImagePlayground`  
**Requirements:** A17 Pro+, A18, or M-series + iOS 18.1+

**Capabilities:**
- On-device image generation
- Animation, Illustration, Sketch styles
- Could be used for document visualization

**Currently:** Detected in Model Manager but not actively used

---

### 🧮 NaturalLanguage Framework
**Status:** ✅ Fully Integrated  
**Import:** `import NaturalLanguage`  
**Requirements:** All iOS versions

**Current Usage:**
1. **Embeddings** - `NLEmbedding` for 512-dim semantic vectors
2. **On-Device Analysis** - `NLTagger` for extractive QA
3. **Query Analysis** - Intent detection and keyword extraction
4. **Language Recognition** - Multi-language support

**Implementation:**
- `EmbeddingService.swift` - Embedding generation
- `OnDeviceAnalysisService` in `LLMService.swift`

---

### 🤖 Core ML
**Status:** ✅ Fully Integrated  
**Import:** `import CoreML`  
**Requirements:** All iOS versions (performance varies)

**Current Usage:**
- Neural Engine optimization
- Framework for custom model execution
- `CoreMLLLMService` for .mlpackage models

**Ready For:**
- Custom quantized models
- Llama, Phi, Mistral integration
- KV-cache optimizations

---

### 👁️ Vision & VisionKit
**Status:** ✅ Available (Detected)  
**Import:** `import Vision`, `import VisionKit`  
**Requirements:** All iOS versions

**Potential Use Cases:**
1. Enhanced OCR for scanned documents
2. Table detection in PDFs
3. Handwriting recognition
4. Document scanning UI

**Currently:** Detected in capabilities but not actively used

---

## Device Capability Detection

### Comprehensive Detection System

**Location:** `Services/RAGService.swift` - `checkDeviceCapabilities()`

**Detects:**
1. **iOS Version** - Major, minor, patch
2. **Device Chip** - A13 through A18, M-series
3. **Apple Intelligence** - A17 Pro+/M-series check
4. **Foundation Models** - iOS 26 API availability
5. **Private Cloud Compute** - iOS 18.1+ check
6. **Writing Tools** - iOS 18.1+ check
7. **Image Playground** - Chip + iOS check
8. **Framework Availability** - All AI frameworks

### Device Chip Detection

**Method:** `detectDeviceChip()` uses `uname()` system call

**Chip Categories:**
- **M-series** - Mac Silicon (M1, M2, M3, M4)
- **A17 Pro / A18** - Full Apple Intelligence support
- **A16 Bionic** - Good AI performance, no Apple Intelligence
- **A15 Bionic** - Standard AI support
- **A14 Bionic** - Basic AI support
- **A13 Bionic** - Minimal AI support
- **Older** - Limited capabilities

### Device Tiers

**High (Premium)**
- A17 Pro+, A18, or M-series
- Full Apple Intelligence support
- Foundation Models capable (iOS 26+)
- Best performance for on-device AI

**Medium (Standard)**
- A13-A16 chips
- Good embeddings support
- Core ML execution
- No Apple Intelligence

**Low (Basic)**
- Pre-A13 chips
- Limited AI features
- Basic document processing only

---

## UI Integration

### Model Manager View

**Path:** `Views/ModelManagerView.swift`

**Now Shows:**
1. **Device Information Section**
   - Chip model and performance rating
   - iOS version
   - Device tier with color coding
   - Apple Intelligence status

2. **Apple Intelligence Features**
   - Foundation Models (iOS 26)
   - Apple Intelligence platform (iOS 18.1)
   - Private Cloud Compute
   - Writing Tools
   - Image Playground
   - Each with availability badge

3. **Core AI Frameworks**
   - NaturalLanguage Embeddings
   - Core ML
   - Vision Framework
   - VisionKit
   - App Intents (Siri)

4. **Active Model Status**
   - Current LLM service
   - Availability status
   - Visual indicators

5. **Available Models List**
   - Foundation Models (if supported)
   - OpenAI Direct
   - On-Device Analysis
   - Custom models (future)

### Settings View

**Path:** `Views/SettingsView.swift`

**Enhanced With:**
1. **Smart Model Selection**
   - Foundation Models option (iOS 26+)
   - Apple Intelligence option (iOS 18.1+)
   - Always shows OpenAI Direct and On-Device Analysis

2. **Private Cloud Compute Toggle**
   - Only shown when PCC is available
   - User preference for complex queries
   - Explanation of zero data retention

3. **Model Info Cards**
   - Device-aware capability display
   - Unavailability reasons shown
   - Detailed feature lists

4. **Enhanced About View**
   - Device capabilities summary
   - AI features availability
   - Complete technology stack

---

## Color Coding System

### Device Tier Colors
- 🟢 **Green** - High tier (full capabilities)
- 🔵 **Blue** - Medium tier (good support)
- 🟠 **Orange** - Low tier (limited support)

### Feature Availability
- 🟢 **Green checkmark** - Available and working
- 🔴 **Red X** - Not available (hardware/OS limitation)
- 🟠 **Orange warning** - Available but not configured

### Badges
- **Blue badges** - Version indicators (iOS 26, iOS 18.1+)
- **Green badges** - Availability status
- **Orange badges** - Warnings or requirements

---

## Testing on Different Devices

### iOS 26+ with A17 Pro+ / M-series
**Expected:**
- ✅ Foundation Models available
- ✅ Full Apple Intelligence support
- ✅ All features green checkmarks
- 🟢 High tier device

### iOS 18.1+ with A17 Pro+ / M-series
**Expected:**
- ❌ Foundation Models (requires iOS 26)
- ✅ Apple Intelligence available
- ✅ Private Cloud Compute available
- ✅ Writing Tools available
- 🟢 High tier device

### iOS 18.0+ with A15/A16
**Expected:**
- ❌ Foundation Models
- ❌ Apple Intelligence (chip limitation)
- ❌ Writing Tools (requires 18.1)
- ✅ Core frameworks available
- 🔵 Medium tier device

### iOS 18.0 with A13/A14
**Expected:**
- ❌ All Apple Intelligence features
- ✅ NaturalLanguage embeddings
- ✅ Core ML available
- 🟠 Medium/Low tier device

### Simulator
**Expected:**
- Simulates A17 Pro capabilities
- All frameworks shown as available
- Good for UI testing
- May not accurately reflect hardware limitations

---

## Performance Expectations

| Feature | A17 Pro+ | A15-A16 | A13-A14 |
|---------|----------|---------|---------|
| Foundation Models | 10+ tok/s | N/A | N/A |
| Private Cloud Compute | 20+ tok/s | N/A | N/A |
| Embeddings (512-dim) | <50ms | <100ms | <150ms |
| Vector Search (1K chunks) | <50ms | <75ms | <100ms |
| Document Processing | Fast | Good | Moderate |
| Core ML Inference | Excellent | Very Good | Good |

---

## Future Enhancements

### Priority 1 (Next Sprint)
1. **Writing Tools Integration**
   - Add to chat input field
   - Context summarization before LLM
   - Query proofreading

2. **App Intents for Siri**
   - Voice-activated document queries
   - Document import via voice
   - Status queries

### Priority 2 (Following Sprint)
1. **Enhanced PCC Control**
   - Query complexity estimation
   - Manual PCC routing
   - Performance metrics

2. **Vision Framework Integration**
   - Better OCR for scanned documents
   - Table extraction from PDFs
   - Handwriting support

### Priority 3 (Future)
1. **Image Playground Integration**
   - Visualize document concepts
   - Generate diagrams from text
   - Document thumbnails

2. **Custom Model Import**
   - .mlpackage file browser
   - GGUF model support
   - Model performance benchmarking

---

## Troubleshooting

### "Apple Intelligence not available"
**Possible Causes:**
1. Device is not A17 Pro+, A18, or M-series
2. iOS version < 18.1
3. Apple Intelligence disabled in Settings
4. Region restrictions

**Solution:** Check Settings → Apple Intelligence & Siri

### "Foundation Models not available"
**Possible Causes:**
1. iOS version < 26.0
2. Device not compatible
3. SDK not yet available

**Solution:** Update to iOS 26.0 or use Apple Intelligence mode

### "Red X marks in Model Manager"
**This is Normal** if:
- Device doesn't meet hardware requirements
- iOS version too old
- Feature not yet available in region

**Not a Bug** - Accurate reflection of capabilities

---

## Key Files Reference

| File | Purpose | Lines of Interest |
|------|---------|------------------|
| `Services/RAGService.swift` | Device detection | 597-800 |
| `Services/LLMService.swift` | Foundation Models | 40-235 |
| `Views/ModelManagerView.swift` | Capabilities UI | 1-300 |
| `Views/SettingsView.swift` | Model selection | 1-440 |
| `Models/LLMModel.swift` | Model types | 1-70 |

---

## Summary

RAGMLCore now provides:
- ✅ Comprehensive device capability detection
- ✅ Accurate iOS version and chip detection
- ✅ All Apple Intelligence frameworks detected
- ✅ Clear visual indicators (no more red X confusion)
- ✅ Device tier classification
- ✅ Framework-specific feature flags
- ✅ User-friendly explanations for unavailable features
- ✅ Ready for iOS 26 Foundation Models
- ✅ Smart model selection based on capabilities

The app accurately reflects what's available on each device, making it clear why certain features are or aren't available.

---

_For implementation details, see `ARCHITECTURE.md` and `IMPLEMENTATION_STATUS.md`_
