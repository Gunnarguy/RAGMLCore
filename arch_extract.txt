# Technical Architecture Document
## RAGMLCore: On-Device RAG Application for iOS 26

**Version**: 2.0  
**Date**: October 10, 2025  
**Status**: Production-Ready

---

## Executive Summary

RAGMLCore is a native iOS 26 application implementing a complete Retrieval-Augmented Generation (RAG) pipeline. The architecture leverages Apple Intelligence (Foundation Models + Private Cloud Compute) while maintaining a protocol-based design that supports custom models if desired.

**Simple Concept:** Users upload documents, ask questions, get AI-powered answers using information from their documents.

### Key Architectural Principles

1. **Privacy-First**: On-device processing by default, optional Private Cloud Compute with zero retention
2. **Protocol-Oriented**: Modular design enables swapping implementations without changing business logic
3. **Async/Await**: Modern Swift concurrency throughout
4. **Simple**: No unnecessary abstraction - 10 core files implement complete functionality

---

## System Architecture

### High-Level Component Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        User Interface                        │
│  ┌──────────┐    ┌──────────────┐    ┌────────────────┐   │
│  │ ChatView │    │ DocumentView │    │ ModelManager │   │
│  └────┬─────┘    └──────┬───────┘    └────────┬───────┘   │
└───────┼─────────────────┼───────────────────────┼──────────┘
        │                 │                       │
        └─────────────────┼───────────────────────┘
                          ▼
        ┌─────────────────────────────────────────────┐
        │         RAGService (Orchestrator)           │
        └─┬───────────┬────────────┬──────────────┬───┘
          │           │            │              │
    ┌─────▼──┐  ┌────▼─────┐  ┌──▼───────┐  ┌───▼────────┐
    │Document│  │Embedding │  │  Vector  │  │    LLM     │
    │Processor│ │ Service  │  │ Database │  │  Service   │
    └────────┘  └──────────┘  └──────────┘  └────────────┘
         │           │              │              │
         ▼           ▼              ▼              ▼
    ┌────────┐  ┌────────┐    ┌────────┐    ┌────────┐
    │ PDFKit │  │Natural │    │In-Mem  │    │Found.  │
    │        │  │Language│    │or Vec  │    │Models  │
    │        │  │        │    │turaKit │    │or CoreML│
    └────────┘  └────────┘    └────────┘    └────────┘
```

### Data Flow Architecture

```
User Document Input
      │
      ▼
┌─────────────────┐
│ Parse & Extract │  ← PDFKit / FileManager
│   Text Content  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Chunk Documents │  ← Semantic splitting with overlap
│  (400w/50w)     │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Generate        │  ← NLContextualEmbedding
│ Embeddings      │  ← 512-dim vectors
│  (BERT-based)   │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Store in Vector │  ← VectorDatabase protocol
│    Database     │  ← Cosine similarity indexing
└────────┬────────┘
         │
         ▼
    [Ready for Queries]

User Query Input
      │
      ▼
┌─────────────────┐
│ Embed Query     │  ← Same embedding model
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Vector Search   │  ← k-NN with cosine similarity
│  (Top-K: 3-10)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Format Context  │  ← Concatenate retrieved chunks
│ + Prompt        │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ LLM Generation  │  ← Foundation Models or Core ML
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Return Response │  ← With performance metrics
│ + Retrieved     │
│   Context       │
└─────────────────┘
```

---

## Core Components

### 1. Document Processor

**Responsibility**: Parse documents and create semantic chunks

**Implementation**: `Services/DocumentProcessor.swift`

**Key Features**:
- Multi-format support (PDF, TXT, MD, RTF)
- Semantic chunking with configurable overlap
- Metadata preservation (page numbers, positions)

**Algorithm**:
```
Input: Document URL
Output: Array of text chunks

1. Detect document type from extension
2. Extract full text using appropriate parser:
   - PDF → PDFKit.PDFDocument
   - Text → String(contentsOf:)
   - RTF → NSAttributedString
3. Split text by paragraphs (semantic boundaries)
4. Group into chunks of ~400 words
5. Implement 50-word overlap for context continuity
6. Return chunks with metadata
```

**Performance**: O(n) where n = document length

### 2. Embedding Service

**Responsibility**: Convert text to semantic vector representations

**Implementation**: `Services/EmbeddingService.swift`

**Key Features**:
- Uses Apple's NLContextualEmbedding (BERT-based)
- Generates 512-dimensional vectors
- Token-level averaging for chunk representation
- Built-in cosine similarity calculation

**Algorithm**:
```
Input: Text string
Output: 512-dimensional Float array

1. Request embeddings from NLContextualEmbedding
2. Receive per-token 512-dim vectors
3. Average all token vectors:
   for each dimension i:
     result[i] = sum(tokens[*][i]) / token_count
4. Return averaged vector as chunk embedding
```

**Performance**: 
- Embedding generation: ~100ms per chunk (device-dependent)
- Batch processing: Sequential (Apple's API limitation)

### 3. Vector Database

**Responsibility**: Store embeddings and perform similarity search

**Implementation**: `Services/VectorDatabase.swift`

**Architecture**:
```swift
protocol VectorDatabase {
    func store(chunk: DocumentChunk) async throws
    func storeBatch(chunks: [DocumentChunk]) async throws
    func search(embedding: [Float], topK: Int) async throws -> [RetrievedChunk]
    func deleteChunks(forDocument: UUID) async throws
    func clear() async throws
    func count() async throws -> Int
}
```

