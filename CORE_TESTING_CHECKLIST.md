# RAGMLCore: Core Pipeline Manual Testing Checklist

**Version:** 1.0  
**Date:** October 10, 2025  
**Purpose:** Validate the RAG pipeline from absolute fundamentals before enabling Apple Intelligence features

---

## 🎯 Testing Philosophy

**Build from the inside out.** Test each layer thoroughly before moving to the next:

1. ✅ Document Processing (files → chunks)
2. ✅ Embedding Generation (chunks → vectors)
3. ✅ Vector Storage & Search (vectors → retrieval)
4. ✅ End-to-End RAG Pipeline (query → response)
5. ✅ UI/UX Polish & Error Handling

---

## 📋 Pre-Testing Setup

### Required Test Documents

Ensure the following files exist in `TestDocuments/`:

- [x] `sample_1page.txt` - Basic functionality
- [x] `sample_technical.md` - Markdown with code blocks
- [x] `sample_unicode.txt` - International characters & emoji
- [x] `sample_empty.txt` - Edge case: empty file
- [x] `sample_special_chars.txt` - Edge case: special characters only
- [x] `sample_whitespace.txt` - Edge case: excessive whitespace

### Optional (Real-World Testing)

- [ ] 1-page PDF
- [ ] 10-page PDF  
- [ ] 100-page PDF
- [ ] Technical documentation (your own)

---

## Phase 1: Document Processing Validation

### Test 1.1: Basic Text Import

**Steps:**
1. Open app → Navigate to **Documents** tab
2. Tap **+ Add Document**
3. Select `sample_1page.txt`
4. Observe processing overlay

**Expected Results:**
- ✅ File picker opens
- ✅ "Processing..." overlay appears
- ✅ Processing completes in <2 seconds
- ✅ Document appears in list
- ✅ Chunk count displayed (~1 chunk per 400 words)

**Console Validation:**
```
📄 [DocumentProcessor] Processing document: sample_1page.txt
   Document type: text
   Text extraction: ✓ (0.01s)
   Characters: 1523
   Words: 228
   Lines: 25
   Chunking: ✓ (0.00s)
   Chunks created: 1
   Average chunk size: 228 words
✅ [DocumentProcessor] Complete: sample_1page.txt (0.02s total)
```

**Pass Criteria:**
- [ ] No crashes
- [ ] Processing time <3s
- [ ] Chunk count makes sense (1 chunk for 228 words)
- [ ] No error messages in console

---

### Test 1.2: Markdown with Code Blocks

**Steps:**
1. Documents tab → Add Document
2. Select `sample_technical.md`
3. Check console logs

**Expected Results:**
- ✅ Markdown parsed correctly
- ✅ Code blocks preserved in chunks
- ✅ Multiple chunks created (~3-5 chunks)

**Console Validation:**
```
📄 [DocumentProcessor] Processing document: sample_technical.md
   Chunks created: 4
   Average chunk size: 350 words
```

**Pass Criteria:**
- [ ] No parse errors
- [ ] Code blocks readable in chunks
- [ ] Processing time <2s

---

### Test 1.3: Unicode & Special Characters

**Steps:**
1. Documents tab → Add Document
2. Select `sample_unicode.txt`
3. Query: "What languages are mentioned?"

**Expected Results:**
- ✅ Unicode characters preserved
- ✅ Emoji handled correctly
- ✅ RAG query returns relevant chunks with unicode

**Console Validation:**
```
   Characters: 3247 (includes multi-byte unicode)
   Chunks created: 2
```

**Pass Criteria:**
- [ ] No encoding errors
- [ ] Chinese/Arabic/Hebrew text readable
- [ ] Emoji display correctly in chunks

---

### Test 1.4: Edge Case - Empty Document

**Steps:**
1. Documents tab → Add Document
2. Select `sample_empty.txt`

**Expected Results:**
- ❌ Error message displayed
- ✅ App does not crash
- ✅ User-friendly error: "Document contains no text"

**Console Validation:**
```
❌ [DocumentProcessor] Document is empty or contains only whitespace
```

**Pass Criteria:**
- [ ] Graceful error handling
- [ ] No crash
- [ ] Clear error message to user

---

### Test 1.5: Edge Case - Special Characters Only

**Steps:**
1. Documents tab → Add Document
2. Select `sample_special_chars.txt`

**Expected Results:**
- ✅ Document imported (special chars are valid content)
- ✅ Chunks created
- ⚠️ Warning: Low embedding coverage expected

**Console Validation:**
```
⚠️  [EmbeddingService] Low coverage: 15/450 words have embeddings
```

**Pass Criteria:**
- [ ] No crash
- [ ] Graceful handling of limited embeddings
- [ ] Warning logged but processing continues

---

### Test 1.6: Whitespace Edge Case

**Steps:**
1. Documents tab → Add Document
2. Select `sample_whitespace.txt`

**Expected Results:**
- ✅ Excessive whitespace normalized
- ✅ Chunks contain readable text
- ✅ No blank chunks created

**Pass Criteria:**
- [ ] Text extraction handles whitespace
- [ ] No empty chunks
- [ ] Content still retrievable

---

## Phase 2: Embedding Quality Validation

### Test 2.1: Embedding Dimensionality

**Steps:**
1. Run automated validation: **Tests** tab → "Run Core Validation Tests"
2. Check "EmbeddingService - Dimension Check"

**Expected Results:**
- ✅ Test passes
- ✅ All embeddings are 512 dimensions

**Console Validation:**
```
🔢 [EmbeddingService] Generating embeddings for 5 chunks...
✅ [EmbeddingService] Complete: 5 embeddings in 0.45s
   Average: 90ms per embedding
```

**Pass Criteria:**
- [ ] All embeddings exactly 512 dimensions
- [ ] No NaN or Inf values
- [ ] Processing time <100ms per chunk

---

### Test 2.2: Embedding Similarity Test

**Steps:**
1. Import `sample_1page.txt` (about RAG)
2. Query: "What is RAG?"
3. Check retrieved chunk similarity scores

**Expected Results:**
- ✅ Top result has similarity >0.7
- ✅ Chunks ranked correctly (descending score)

**Console Validation:**
```
🔍 [VectorDatabase] Searching 1 chunks for top 3...
✅ [VectorDatabase] Search complete in 15ms
   Top result: score=0.823
```

**Pass Criteria:**
- [ ] Similar queries return high scores (>0.7)
- [ ] Unrelated queries return lower scores (<0.4)
- [ ] Ranking is correct

---

### Test 2.3: Edge Case - Empty Embedding

**Steps:**
1. Run automated test: "EmbeddingService - Edge Case (Empty)"

**Expected Results:**
- ✅ Test passes (error correctly thrown)

**Pass Criteria:**
- [ ] Empty input throws EmbeddingError.emptyInput
- [ ] No crash
- [ ] Clear error message

---

## Phase 3: Vector Database Validation

### Test 3.1: Storage & Retrieval

**Steps:**
1. Import 3 different documents
2. Check console for storage confirmations
3. Query each document's topic

**Expected Results:**
- ✅ All chunks stored successfully
- ✅ Total chunk count accurate
- ✅ Retrieval returns correct documents

**Console Validation:**
```
💾 [VectorDatabase] Storing 5 chunks...
✅ [VectorDatabase] Stored 5 chunks in 0.01s
   Total chunks in database: 15
```

**Pass Criteria:**
- [ ] Storage time <50ms for 10 chunks
- [ ] Count matches expected
- [ ] No duplicate IDs

---

### Test 3.2: Search Performance

**Steps:**
1. Import documents until 100+ chunks stored
2. Run query
3. Measure search time

**Expected Results:**
- ✅ Search completes in <50ms for 100 chunks
- ✅ Returns topK results correctly

**Console Validation:**
```
🔍 [VectorDatabase] Searching 127 chunks for top 3...
✅ [VectorDatabase] Search complete in 23ms
```

**Pass Criteria:**
- [ ] Search time <50ms for <1000 chunks
- [ ] Scales reasonably (O(n) is acceptable for in-memory)

---

### Test 3.3: Edge Case - Search Empty Database

**Steps:**
1. Clear all documents (or fresh install)
2. Try to run query

**Expected Results:**
- ⚠️ Error: "No documents in knowledge base"
- ✅ No crash

**Console Validation:**
```
⚠️  [RAGService] No documents in knowledge base
```

**Pass Criteria:**
- [ ] Clear error message
- [ ] No crash
- [ ] User prompted to add documents

---

### Test 3.4: Edge Case - topK > Total Chunks

**Steps:**
1. Import 1 document (1 chunk)
2. Query with topK=5

**Expected Results:**
- ⚠️ Warning: Only 1 chunk returned
- ✅ No crash

**Console Validation:**
```
⚠️  [VectorDatabase] Requested topK=5 but only 1 chunks available
```

**Pass Criteria:**
- [ ] Returns available chunks (not error)
- [ ] Warning logged
- [ ] No crash

---

## Phase 4: End-to-End RAG Pipeline

### Test 4.1: Basic RAG Query

**Steps:**
1. Import `sample_1page.txt`
2. Chat tab → Ask: "What is RAG?"
3. Observe response

**Expected Results:**
- ✅ Response generated in <5s
- ✅ Retrieved chunks displayed
- ✅ Response uses MockLLMService

**Console Validation:**
```
🤖 [RAGService] Starting RAG query...
   Query: What is RAG?
   TopK: 3
   Step 1: Generating query embedding...
   ✓ Query embedded in 87ms
   Step 2: Retrieving relevant chunks...
✅ [RAGService] RAG pipeline complete in 1.23s

📊 RAG Query Statistics:
  Retrieved chunks: 1
  Retrieval time: 0.12s
  Generation time: 1.05s
  Model: MockLLMService
  Total time: 1.17s
```

**Pass Criteria:**
- [ ] Total time <5s
- [ ] Chunks retrieved correctly
- [ ] Response generated
- [ ] No errors

---

### Test 4.2: Multi-Document Query

**Steps:**
1. Import 3+ documents on different topics
2. Ask query spanning multiple docs
3. Check retrieved chunks

**Expected Results:**
- ✅ Chunks from multiple documents retrieved
- ✅ Most relevant chunks ranked first

**Pass Criteria:**
- [ ] Cross-document retrieval works
- [ ] Ranking correct across documents
- [ ] Response synthesizes information

---

### Test 4.3: Edge Case - Empty Query

**Steps:**
1. Chat tab → Send empty message

**Expected Results:**
- ❌ Error: "Query cannot be empty"
- ✅ No crash

**Pass Criteria:**
- [ ] Input validation prevents empty query
- [ ] User-friendly error
- [ ] No backend call made

---

### Test 4.4: Performance - Large Document Set

**Steps:**
1. Import 10 documents (aim for 1000+ chunks)
2. Run multiple queries
3. Monitor memory usage

**Expected Results:**
- ✅ Memory stable <500MB
- ✅ No memory leaks
- ✅ UI remains responsive

**Validation:**
- Use Xcode Instruments → Leaks
- Monitor memory graph over 10 queries
- Check for retain cycles

**Pass Criteria:**
- [ ] Memory stays <500MB
- [ ] No leaks detected
- [ ] No UI freezing

---

## Phase 5: UI/UX Validation

### Test 5.1: Chat View - Message Display

**Steps:**
1. Send 10+ messages
2. Scroll through history
3. Check retrieved chunks display

**Expected Results:**
- ✅ Messages display correctly
- ✅ Auto-scroll to newest
- ✅ Retrieved chunks expandable
- ✅ Smooth scrolling

**Pass Criteria:**
- [ ] No layout issues
- [ ] Scrolling smooth
- [ ] Chunks readable

---

### Test 5.2: Document Library - Visual Feedback

**Steps:**
1. Add multiple documents
2. Check progress indicators
3. Try swipe-to-delete

**Expected Results:**
- ✅ Processing overlay shown
- ✅ Chunk count displayed
- ✅ Delete confirmation works

**Pass Criteria:**
- [ ] Clear visual feedback
- [ ] No UI freezing during import
- [ ] Delete updates database

---

### Test 5.3: Model Manager - Device Info

**Steps:**
1. Navigate to Models tab
2. Check device capabilities display

**Expected Results:**
- ✅ Current model shown (MockLLMService)
- ✅ Device capabilities accurate
- ✅ Foundation Models badge (if available)

**Pass Criteria:**
- [ ] Accurate information displayed
- [ ] UI reflects device capabilities

---

### Test 5.4: Core Validation - Automated Tests

**Steps:**
1. Tests tab → "Run Core Validation Tests"
2. Watch test execution
3. Check results

**Expected Results:**
- ✅ All tests complete
- ✅ Pass/fail clearly indicated
- ✅ Timing displayed

**Pass Criteria:**
- [ ] All tests pass on capable device
- [ ] Results clear and actionable
- [ ] Tests complete in <30s

---

## Success Criteria Summary

**Core Pipeline (Must Pass)**

- [x] ✅ 5+ documents imported without errors
- [ ] ✅ 100+ test queries return relevant results
- [ ] ✅ Zero crashes in 30-minute stress test
- [ ] ✅ Memory stable (<500MB with 10 documents)
- [ ] ✅ All edge cases handled gracefully
- [ ] ✅ UI responsive (no freezing during imports)
- [ ] ✅ Performance metrics accurate
- [ ] ✅ Console logs clear and helpful

**Performance Benchmarks**

- [ ] Document import: <1s per page
- [ ] Embedding generation: <100ms per chunk
- [ ] Vector search (1000 chunks): <50ms
- [ ] End-to-end query: <5s total

**Quality Indicators**

- [ ] Retrieval accuracy: Top-1 relevant >80% of time
- [ ] Embedding coverage: >50% of words have vectors
- [ ] Similarity scores: Relevant chunks >0.6

---

## Next Steps After Core Validation

Once ALL tests pass:

1. ✅ **Core is bulletproof** - Foundation is solid
2. 🚀 **Enable Apple Foundation Models**
   - Uncomment `AppleFoundationLLMService`
   - Update `RAGService.init()` to use real model
   - Test on A17 Pro+ or M-series device
3. 🌐 **Add Private Cloud Compute fallback**
4. 🎨 **Polish UI/UX** with final touches
5. 📦 **Production deployment** ready

---

## Troubleshooting

### Common Issues

**Issue:** "Embedding model unavailable"  
**Solution:** NLEmbedding requires iOS 15+, runs on A13+ chips

**Issue:** Very slow performance  
**Solution:** Check for debug build, use Release for accurate benchmarks

**Issue:** Chunks not retrieved  
**Solution:** Check embedding similarity scores in console

**Issue:** Memory spike during import  
**Solution:** Process documents sequentially, not in parallel

---

## Test Execution Log

**Tester:**  
**Date:**  
**Device:** (e.g., iPhone 15 Pro, iOS 26.0 simulator)  
**Build:** (e.g., Debug, Release)

| Test ID | Test Name | Result | Time | Notes |
|---------|-----------|--------|------|-------|
| 1.1 | Basic Text Import | ⬜️ | | |
| 1.2 | Markdown Import | ⬜️ | | |
| 1.3 | Unicode Handling | ⬜️ | | |
| 1.4 | Empty Document | ⬜️ | | |
| 1.5 | Special Chars | ⬜️ | | |
| 1.6 | Whitespace | ⬜️ | | |
| 2.1 | Embedding Dim | ⬜️ | | |
| 2.2 | Similarity Test | ⬜️ | | |
| 2.3 | Empty Embedding | ⬜️ | | |
| 3.1 | Storage & Retrieval | ⬜️ | | |
| 3.2 | Search Performance | ⬜️ | | |
| 3.3 | Empty DB Search | ⬜️ | | |
| 3.4 | topK Edge Case | ⬜️ | | |
| 4.1 | Basic RAG Query | ⬜️ | | |
| 4.2 | Multi-Doc Query | ⬜️ | | |
| 4.3 | Empty Query | ⬜️ | | |
| 4.4 | Large Doc Set | ⬜️ | | |
| 5.1 | Chat UI | ⬜️ | | |
| 5.2 | Document Library | ⬜️ | | |
| 5.3 | Model Manager | ⬜️ | | |
| 5.4 | Automated Tests | ⬜️ | | |

**Overall Status:** ⬜️ Not Started / 🔄 In Progress / ✅ Passed / ❌ Failed

---

**Sign-off:**  
Core pipeline validated and ready for Apple Intelligence integration: ________

---

_Last Updated: October 10, 2025_  
_Next Update: After full test execution_
