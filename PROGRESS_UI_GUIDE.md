# Progress UI Guide - Real-Time Document Processing Display

## What You Should See When Adding Documents

When you press the **+** button in the Documents tab and select a file, you'll now see a beautiful **glassmorphic overlay** with real-time progress updates.

### Visual Elements

1. **Overlay Background**
   - Semi-transparent dark background (50% opacity)
   - Blurs the content behind it

2. **Processing Card**
   - Glassmorphic material effect (frosted glass appearance)
   - Rounded corners with subtle shadow
   - Centered on screen

3. **Animated Progress Indicator**
   - Circular spinner with white tint
   - Continuously animating while processing

4. **Two-Line Status Display**
   - **Line 1 (Filename)**: Bold, white text showing the document name
   - **Line 2 (Progress Details)**: Pill-shaped badge with icon + status

### Progress Messages You'll See

The overlay updates in real-time as the document moves through the RAG pipeline:

#### Phase 1: Loading
```
filename.pdf
📄 reading file
```

#### Phase 2: Extraction (varies by file type)

**For PDFs:**
```
filename.pdf
🔍 page 1/5
```

**For PDFs with images:**
```
filename.pdf
👁️ page 3/5, OCR
```

**For Images:**
```
photo.jpg
👁️ OCR scanning
```

**For Text/Code Files:**
```
document.txt
📄 reading file
```

#### Phase 3: Chunking
```
filename.pdf
✂️ chunking text
```
(Shows after extraction, brief display before embedding)

#### Phase 4: Embedding (most visible, takes longest)
```
filename.pdf
🧠 Embedding (1/47)

filename.pdf
🧠 Embedding (2/47)

filename.pdf
🧠 Embedding (3/47)
...
```
Each chunk gets its own embedding - you'll see the counter increment in real-time!

#### Phase 5: Storing
```
filename.pdf
💾 Storing
```
(Brief final step before completion)

### Context-Aware Icons

The progress overlay uses smart icons based on the status message:

| Icon | Meaning | When Shown |
|------|---------|------------|
| 📥 `arrow.down.circle.fill` | Loading | Initial file access |
| 🔍 `doc.text.magnifyingglass` | Extracting/Pages | PDF page extraction |
| 👁️ `text.viewfinder` | OCR | Optical character recognition |
| ✂️ `scissors` | Chunking | Text segmentation |
| 🧠 `brain.head.profile` | Embedding | Vector generation |
| 💾 `cylinder.fill` | Storing | Database insertion |
| ✨ `sparkles` | Default | Any other status |

## Console Logging (Xcode Debug Area)

While the UI shows user-friendly progress, the console displays detailed technical information:

### Document Processing
```
╔══════════════════════════════════════════════════════════════╗
║ DOCUMENT INGESTION                                           ║
╚══════════════════════════════════════════════════════════════╝
Processing: filename.pdf (1.2 MB)
   Document type: pdf
   ✓ Extracted 15,234 characters (2,456 words)
   ⏱️  Extraction took 0.43s
```

### Page-by-Page Progress
```
   ✓ Page 1: 1,234 chars (0.05s)
   ✓ Page 2: 1,567 chars (0.06s)
   ✓ Page 3: OCR extracted 892 chars (1.23s)
```

### Chunking Statistics
```
🔢 [RAGService] Chunking complete:
   47 chunks, 15,234 chars, 2,456 words
```

### Embedding Progress
```
🧠 [RAGService] Generating embeddings...
   ✓ Chunk 1/47: 512-dim vector (23ms)
   ✓ Chunk 2/47: 512-dim vector (19ms)
   ...
   ✅ All embeddings generated in 2.34s (avg 50ms/chunk)
```

### Final Summary
```
╔══════════════════════════════════════════════════════════════╗
║ INGESTION COMPLETE ✓                                         ║
╚══════════════════════════════════════════════════════════════╝
Document stored: filename.pdf
   • 47 chunks embedded and indexed
   • Total time: 3.12s
```

## Timing Improvements

The UI now includes **small delays (50-100ms)** after each progress update to ensure:
- The UI has time to refresh before the next update
- You actually see intermediate steps (like "page 1/5")
- The processing doesn't appear to jump directly to "Embedding"

### Delay Points:
- **100ms** after "reading file"
- **100ms** after "chunking text"  
- **100ms** after "OCR scanning"
- **50ms** after each PDF page extraction
- **50ms** after each PDF OCR operation

These delays are short enough to not impact performance but long enough to make progress visible.

## Testing the Progress UI

### Quick Test (Small File)
1. Documents tab → Press **+**
2. Select a small PDF (1-3 pages) or text file
3. **Expected**: You should see 4-5 status changes in ~1-2 seconds

### Full Test (Large File)
1. Documents tab → Press **+**
2. Select a multi-page PDF (10+ pages)
3. **Expected**: 
   - Clear progression through pages: "page 1/12", "page 2/12"...
   - Long embedding phase: "Embedding (1/47)", "Embedding (2/47)"...
   - Total time: 5-15 seconds depending on file size

### OCR Test (Image-Based PDF)
1. Find a scanned PDF or screenshot PDF
2. Documents tab → Press **+**
3. **Expected**:
   - See "page 1/5, OCR" messages
   - Much slower per page (~1-2s each with OCR)
   - Console shows "OCR extracted X chars"

## Troubleshooting

### "I only see 'Loading' then 'Embedding'"
- **Issue**: File processes too fast
- **Solution**: Try a larger multi-page PDF (10+ pages)
- The delays ensure intermediate steps are visible

### "Progress overlay doesn't appear"
- **Check**: Is `ragService.isProcessing` being set to `true`?
- **Check**: Open Xcode console - are processing logs appearing?
- **Solution**: The overlay only shows when actively processing

### "Overlay freezes on one message"
- **Issue**: Processing might have thrown an error
- **Check**: Look for error alert dialog
- **Check**: Xcode console for error messages

### "Processing is slow"
- **Expected**: Embedding 50 chunks takes 2-5 seconds (normal!)
- **Expected**: OCR adds 1-2 seconds per page (normal!)
- Each embedding call: ~20-100ms
- Each OCR call: ~500-2000ms

## Performance Notes

### Speed by File Type
- **Plain Text**: Fastest (instant extraction + chunking)
- **Native PDF**: Fast (0.05s per page extraction)
- **Scanned PDF/Images**: Slower (1-2s per page with OCR)
- **Large Files**: Linear with size (more pages = more time)

### Bottlenecks
1. **OCR** (slowest): Vision framework processes each image
2. **Embedding**: NLEmbedding averages 20-100ms per chunk
3. **File I/O**: Usually negligible (<100ms)

### Optimization Tips
- Files under 5 pages: Processing completes in 1-3 seconds
- Files with 10-20 pages: Processing completes in 5-10 seconds
- Scanned PDFs: Add 1-2s per page for OCR
- Text files of any size: Usually under 1 second total

---

## Summary

**The progress UI is now fully functional and displays:**
- ✅ Real-time filename display
- ✅ Context-aware icons (PDF extraction, OCR, embedding, etc.)
- ✅ Page-by-page progress for multi-page documents
- ✅ Chunk-by-chunk embedding counters
- ✅ Glassmorphic overlay design
- ✅ Smooth transitions with timed delays
- ✅ Comprehensive console logging for debugging

**Try it now!** Press the **+** button and add a PDF to see the beautiful progress display in action.
