# 🚀 RAGMLCore: Quick Start Guide (Core Validation)

**Goal:** Test the core RAG pipeline in 15 minutes before enabling Apple Intelligence.

---

## ✅ Prerequisites

- Xcode 15+
- iOS Simulator or iPhone (iOS 15+)
- 5 minutes

---

## 🏃 Step 1: Build & Run (2 minutes)

```bash
# Open project
cd ~/Documents/GitHub/RAGMLCore
open RAGMLCore.xcodeproj

# In Xcode:
# 1. Select target: RAGMLCore
# 2. Select device: iPhone 15 Pro simulator
# 3. Press ⌘+R to build and run
```

**Expected:** App launches with 4 tabs: Chat, Documents, Tests, Models

---

## 🧪 Step 2: Run Automated Tests (3 minutes)

1. **Tap "Tests" tab** (3rd tab, checkmark icon)
2. **Tap "Run Core Validation Tests"** button
3. **Watch the magic** ✨

**Expected Results:**
- 9 tests execute automatically
- All tests show ✅ green checkmarks
- Total time: <30 seconds
- Overall status: "All tests passed ✅"

**If any test fails:**
- Check console output in Xcode
- Verify NLEmbedding is available (requires iOS 15+, A13+ chip)

---

## 📄 Step 3: Import Test Documents (5 minutes)

1. **Tap "Documents" tab** (2nd tab)
2. **Tap "+ Add Document"**
3. **Select** `TestDocuments/sample_1page.txt`
4. **Observe** processing overlay
5. **Check Xcode console** for detailed logs

**Expected Console Output:**
```
📄 [DocumentProcessor] Processing document: sample_1page.txt
   Document type: text
   Text extraction: ✓ (0.01s)
   Characters: 1523
   Words: 228
   Chunks created: 1
✅ [DocumentProcessor] Complete: sample_1page.txt (0.02s total)

🔢 [EmbeddingService] Generating embeddings for 1 chunks...
✅ [EmbeddingService] Complete: 1 embeddings in 0.09s

💾 [VectorDatabase] Storing 1 chunks...
✅ [VectorDatabase] Stored 1 chunks in 0.01s
```

**Repeat** for:
- `sample_technical.md`
- `sample_unicode.txt`

---

## 💬 Step 4: Test RAG Queries (5 minutes)

1. **Tap "Chat" tab** (1st tab)
2. **Type query:** "What is RAG?"
3. **Send** (tap paper plane icon)
4. **Check console** for pipeline execution

**Expected Console Output:**
```
🤖 [RAGService] Starting RAG query...
   Query: What is RAG?
   TopK: 3
   Step 1: Generating query embedding...
   ✓ Query embedded in 87ms
   Step 2: Retrieving relevant chunks...
🔍 [VectorDatabase] Searching 3 chunks for top 3...
✅ [VectorDatabase] Search complete in 15ms
   Top result: score=0.823
   ✓ Retrieved 3 chunks
   Context size: 1247 characters
   Step 3: Generating LLM response...
   ✓ Response generated in 1.05s
✅ [RAGService] RAG pipeline complete in 1.23s

📊 RAG Query Statistics:
  Retrieved chunks: 3
  Retrieval time: 0.12s
  Generation time: 1.05s
  Model: MockLLMService
  Total time: 1.17s
```

**Try more queries:**
- "What are the benefits of RAG?"
- "How does chunking work?"
- "What is the technical architecture?"

**Expected:** 
- Responses generated in <5s
- Retrieved chunks displayed below response
- Similarity scores >0.6 for relevant chunks

---

## ✅ Success Criteria

You're ready to enable Apple Foundation Models if:

- [ ] ✅ All 9 automated tests passed
- [ ] ✅ 3+ documents imported successfully
- [ ] ✅ Queries return relevant responses
- [ ] ✅ Console logs are clean (no errors)
- [ ] ✅ Processing times are reasonable (<5s per query)
- [ ] ✅ Memory stable (check Xcode debug navigator)

---

## 🚀 Next: Enable Foundation Models

**If all tests pass:**

1. **Open** `Services/LLMService.swift`
2. **Scroll to line 100-110**
3. **Uncomment** `AppleFoundationLLMService` implementation
4. **Open** `Services/RAGService.swift`
5. **Line 32:** Change `MockLLMService()` → `AppleFoundationLLMService()`
6. **Build for device** (requires A17 Pro+ or M-series Mac)
7. **Retest** with real Apple Intelligence

---

## 🐛 Troubleshooting

### "Embedding model unavailable"
- **Cause:** NLEmbedding requires iOS 15+, A13+ chip
- **Solution:** Use newer simulator or device

### Tests fail on "Device Capabilities"
- **Cause:** Expected - MockLLMService is placeholder
- **Solution:** Ignore this test for now, will pass with real model

### Very slow performance
- **Cause:** Debug build + simulator overhead
- **Solution:** Test on device with Release build for accurate benchmarks

### No documents appear after import
- **Cause:** File picker issue in simulator
- **Solution:** Use test documents in `TestDocuments/` folder

---

## 📚 More Resources

- **Detailed Testing:** See `CORE_TESTING_CHECKLIST.md`
- **Architecture:** See `ARCHITECTURE.md`
- **Implementation:** See `IMPLEMENTATION_STATUS.md`
- **Enhancements:** See `ENHANCEMENTS.md`

---

## 🎯 Quick Validation Checklist

```
✅ Step 1: Build & Run            [ ]
✅ Step 2: Automated Tests         [ ]
✅ Step 3: Import Documents        [ ]
✅ Step 4: Test Queries            [ ]
✅ Step 5: Check Console Logs      [ ]
✅ Step 6: Verify Performance      [ ]
```

**Time:** ~15 minutes  
**Result:** Core pipeline validated ✅  
**Next:** Enable Apple Intelligence 🚀

---

_The foundation is solid. Now add the intelligence._
