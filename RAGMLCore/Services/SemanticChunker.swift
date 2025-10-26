//
//  SemanticChunker.swift
//  RAGMLCore
//
//  Advanced semantic chunking with topic detection and metadata enrichment
//

import Foundation
import NaturalLanguage

/// Enhanced chunking with semantic boundaries and metadata
class SemanticChunker {
    
    struct ChunkingConfig {
        var targetSize: Int = 400  // Target words per chunk
        var minSize: Int = 100     // Minimum chunk size
        var maxSize: Int = 800     // Maximum chunk size
        var overlap: Int = 75      // Overlap in words (increased from 50)
        var useTopicDetection: Bool = true
        var preserveStructure: Bool = true
    }
    
    struct EnhancedChunk {
        let content: String
        let metadata: ChunkMetadata
        let embedding: [Float]?
        
        struct ChunkMetadata {
            let documentId: UUID
            let chunkIndex: Int
            let totalChunks: Int
            let pageNumber: Int?
            let sectionTitle: String?
            let wordCount: Int
            let characterCount: Int
            let topKeywords: [String]
            let semanticDensity: Float  // How information-dense this chunk is
            let hasNumericData: Bool
            let hasListStructure: Bool
        }
    }
    
    /// Chunk text with semantic boundaries and rich metadata
    func chunkText(
        _ text: String,
        documentId: UUID,
        config: ChunkingConfig = ChunkingConfig(),
        pageNumbers: [Int: Range<String.Index>]? = nil
    ) -> [EnhancedChunk] {
        print("\n📊 [SemanticChunker] Starting advanced chunking...")
        print("   📏 Target: \(config.targetSize)w, Min: \(config.minSize)w, Max: \(config.maxSize)w")
        print("   🔄 Overlap: \(config.overlap)w")
        
        // Safety check: if text is too small, just return one chunk
        let wordCount = text.split(separator: " ").count
        if wordCount < config.minSize {
            print("   ⚠️  Text too small (\(wordCount) words), creating single chunk")
            return [createSingleChunk(text, documentId: documentId, pageNumbers: pageNumbers)]
        }
        
        // 1. Detect sections and structure
        let sections = detectSections(text)
        print("   📑 Detected \(sections.count) sections")
        
        // 2. Detect topic boundaries if enabled
        let topicBoundaries = config.useTopicDetection ? detectTopicBoundaries(text) : []
        print("   🎯 Detected \(topicBoundaries.count) topic boundaries")
        
        // 3. Chunk with semantic awareness
        var chunks: [EnhancedChunk] = []
        var currentPosition = text.startIndex
        var chunkIndex = 0
        let maxChunks = 100 // Safety limit to prevent infinite loops
        
        while currentPosition < text.endIndex && chunkIndex < maxChunks {
            print("   📝 Processing chunk \(chunkIndex + 1)...")
            
            // Safety check: if we're too close to the end, create final chunk and stop
            let remainingDistance = text.distance(from: currentPosition, to: text.endIndex)
            if remainingDistance < 10 {
                // Less than 10 characters remaining - create final micro-chunk if needed
                if remainingDistance > 0 {
                    let finalText = String(text[currentPosition..<text.endIndex])
                    let wordCount = finalText.split(separator: " ").count
                    if wordCount > 0 {
                        print("      ✓ Final chunk \(chunkIndex + 1): \(wordCount) words")
                        let metadata = extractMetadata(
                            chunkText: finalText,
                            chunkIndex: chunkIndex,
                            documentId: documentId,
                            range: currentPosition..<text.endIndex,
                            sections: sections,
                            pageNumbers: pageNumbers
                        )
                        chunks.append(EnhancedChunk(
                            content: finalText,
                            metadata: metadata,
                            embedding: nil
                        ))
                    }
                }
                break
            }
            
            // Find optimal chunk end
            let chunkRange = findOptimalChunkRange(
                in: text,
                from: currentPosition,
                config: config,
                topicBoundaries: topicBoundaries,
                sections: sections
            )
            
            // Safety check: ensure range is valid and not empty
            guard chunkRange.lowerBound < chunkRange.upperBound else {
                print("   ⚠️  Empty range detected, stopping chunking")
                break
            }
            
            let chunkText = String(text[chunkRange])
            print("      ✓ Chunk \(chunkIndex + 1): \(chunkText.split(separator: " ").count) words")
            
            // Extract metadata
            let metadata = extractMetadata(
                chunkText: chunkText,
                chunkIndex: chunkIndex,
                documentId: documentId,
                range: chunkRange,
                sections: sections,
                pageNumbers: pageNumbers
            )
            
            chunks.append(EnhancedChunk(
                content: chunkText,
                metadata: metadata,
                embedding: nil  // Will be added later
            ))
            
            // Move to next chunk with overlap
            let nextPosition = advancePosition(
                from: currentPosition,
                chunkEnd: chunkRange.upperBound,
                overlap: config.overlap,
                in: text
            )
            
            // Safety check: ensure we're making progress
            if nextPosition <= currentPosition {
                print("   ⚠️  No progress made, advancing by 1 character to prevent infinite loop")
                currentPosition = text.index(after: currentPosition)
            } else {
                currentPosition = nextPosition
            }
            
            chunkIndex += 1
        }
        
        print("   ✅ Created \(chunks.count) semantically-aware chunks")
        printChunkStatistics(chunks)
        
        return chunks
    }
    
    /// Detect section headers and boundaries
    private func detectSections(_ text: String) -> [(title: String, range: Range<String.Index>)] {
        var sections: [(String, Range<String.Index>)] = []
        
        // Common section patterns
        let patterns = [
            #"^[A-Z][A-Z\s]+:?\s*$"#,  // ALL CAPS HEADERS
            #"^\d+\.\s+[A-Z].*$"#,      // 1. Numbered sections
            #"^[IVX]+\.\s+[A-Z].*$"#,   // I. Roman numerals
            #"^#{1,3}\s+.*$"#           // ## Markdown headers
        ]
        
        let lines = text.components(separatedBy: .newlines)
        var currentIndex = text.startIndex
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            for pattern in patterns {
                if let _ = trimmed.range(of: pattern, options: .regularExpression) {
                    if let lineRange = text.range(of: line, range: currentIndex..<text.endIndex) {
                        sections.append((trimmed, lineRange))
                        break
                    }
                }
            }
            
            // Advance index
            if let lineRange = text.range(of: line + "\n", range: currentIndex..<text.endIndex) {
                currentIndex = lineRange.upperBound
            }
        }
        
        return sections
    }
    
    /// Detect topic boundaries using linguistic cues
    private func detectTopicBoundaries(_ text: String) -> [String.Index] {
        var boundaries: [String.Index] = []
        
        // Transition words that indicate topic changes
        let transitionPhrases = [
            "However,", "Moreover,", "Furthermore,", "In contrast,", "On the other hand,",
            "Additionally,", "Nevertheless,", "Consequently,", "In conclusion,", "To summarize,"
        ]
        
        for phrase in transitionPhrases {
            var searchRange = text.startIndex..<text.endIndex
            while let range = text.range(of: phrase, range: searchRange) {
                boundaries.append(range.lowerBound)
                searchRange = range.upperBound..<text.endIndex
            }
        }
        
        return boundaries.sorted()
    }
    
    /// Find optimal chunk range respecting semantic boundaries
    private func findOptimalChunkRange(
        in text: String,
        from start: String.Index,
        config: ChunkingConfig,
        topicBoundaries: [String.Index],
        sections: [(title: String, range: Range<String.Index>)]
    ) -> Range<String.Index> {
        let remainingText = text[start..<text.endIndex]
        let words = remainingText.split(separator: " ", omittingEmptySubsequences: true)
        
        // Ideal end position
        let targetEnd = min(config.targetSize, words.count)
        
        // Safety check: if no words remaining, return minimal range
        guard targetEnd > 0 else {
            // No words left - return a minimal range of 1 character if possible
            if start < text.endIndex {
                let oneCharAfter = text.index(after: start)
                return start..<oneCharAfter
            } else {
                // Already at end - return empty range to signal completion
                return start..<start
            }
        }
        
        // Simplified approach: use pre-split words array for better performance
        var targetIndex = text.endIndex
        
        if targetEnd <= words.count {
            // Take the first targetEnd words and find their total length
            let targetWords = words.prefix(targetEnd)
            let approximateLength = targetWords.reduce(0) { $0 + $1.count + 1 } - 1 // -1 for the last space
            
            // Calculate target position more safely
            let maxOffset = text.distance(from: start, to: text.endIndex)
            let safeOffset = min(approximateLength, maxOffset)
            
            if safeOffset > 0 {
                targetIndex = text.index(start, offsetBy: safeOffset, limitedBy: text.endIndex) ?? text.endIndex
            } else {
                targetIndex = start
            }
        }
        
        // Adjust to nearest sentence boundary
        if let sentenceEnd = findNearestSentenceEnd(in: text, near: targetIndex, within: 100) {
            targetIndex = sentenceEnd
        }
        
        return start..<targetIndex
    }
    
    /// Find nearest sentence boundary
    private func findNearestSentenceEnd(in text: String, near index: String.Index, within distance: Int) -> String.Index? {
        let searchStart = text.index(index, offsetBy: -distance, limitedBy: text.startIndex) ?? text.startIndex
        let searchEnd = text.index(index, offsetBy: distance, limitedBy: text.endIndex) ?? text.endIndex
        
        // Validate range before creating it
        guard searchStart < searchEnd else {
            // Invalid range - return nil or the index itself
            return nil
        }
        
        let searchRange = searchStart..<searchEnd
        
        // Look for sentence endings
        let sentenceEnders = CharacterSet(charactersIn: ".!?")
        var nearestDistance = Int.max
        var nearestIndex: String.Index?
        
        for i in text[searchRange].indices {
            if sentenceEnders.contains(text[i].unicodeScalars.first!) {
                let dist = text.distance(from: index, to: i)
                if abs(dist) < nearestDistance {
                    nearestDistance = abs(dist)
                    nearestIndex = text.index(after: i)
                }
            }
        }
        
        return nearestIndex
    }
    
    /// Extract rich metadata for chunk
    private func extractMetadata(
        chunkText: String,
        chunkIndex: Int,
        documentId: UUID,
        range: Range<String.Index>,
        sections: [(title: String, range: Range<String.Index>)],
        pageNumbers: [Int: Range<String.Index>]?
    ) -> EnhancedChunk.ChunkMetadata {
        let wordCount = chunkText.split(separator: " ").count
        let keywords = extractKeywords(chunkText, topN: 5)
        
        // Find section title
        let sectionTitle = sections.first { $0.range.contains(range.lowerBound) }?.title
        
        // Find page number
        let pageNumber = pageNumbers?.first { $0.value.contains(range.lowerBound) }?.key
        
        // Detect structure
        let hasNumeric = chunkText.rangeOfCharacter(from: .decimalDigits) != nil
        let hasList = chunkText.contains(where: { $0 == "•" || $0 == "-" || $0 == "*" })
        
        // Calculate semantic density (information richness)
        let uniqueWords = Set(chunkText.lowercased().split(separator: " "))
        let density = Float(uniqueWords.count) / Float(max(wordCount, 1))
        
        return EnhancedChunk.ChunkMetadata(
            documentId: documentId,
            chunkIndex: chunkIndex,
            totalChunks: 0,  // Will be updated
            pageNumber: pageNumber,
            sectionTitle: sectionTitle,
            wordCount: wordCount,
            characterCount: chunkText.count,
            topKeywords: keywords,
            semanticDensity: density,
            hasNumericData: hasNumeric,
            hasListStructure: hasList
        )
    }
    
    /// Extract top keywords using TF-IDF approximation
    private func extractKeywords(_ text: String, topN: Int) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lexicalClass])
        tagger.string = text
        
        var wordCounts: [String: Int] = [:]
        
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if tag == .noun || tag == .verb {
                let word = String(text[range]).lowercased()
                if word.count > 3 {  // Filter short words
                    wordCounts[word, default: 0] += 1
                }
            }
            return true
        }
        
        return wordCounts.sorted { $0.value > $1.value }
            .prefix(topN)
            .map { $0.key }
    }
    
    /// Advance position with intelligent overlap
    private func advancePosition(
        from start: String.Index,
        chunkEnd: String.Index,
        overlap: Int,
        in text: String
    ) -> String.Index {
        // Move back by overlap words from chunk end
        let overlapRange = text[start..<chunkEnd]
        let words = overlapRange.split(separator: " ")
        
        if words.count > overlap {
            let overlapWords = words.suffix(overlap)
            let overlapText = overlapWords.joined(separator: " ")
            if let overlapStart = text.range(of: overlapText, range: start..<chunkEnd) {
                return overlapStart.lowerBound
            }
        }
        
        return chunkEnd
    }
    
    /// Print chunk statistics
    private func printChunkStatistics(_ chunks: [EnhancedChunk]) {
        let avgWords = chunks.map { $0.metadata.wordCount }.reduce(0, +) / max(chunks.count, 1)
        let avgDensity = chunks.map { $0.metadata.semanticDensity }.reduce(0, +) / Float(max(chunks.count, 1))
        let withSections = chunks.filter { $0.metadata.sectionTitle != nil }.count
        let withNumeric = chunks.filter { $0.metadata.hasNumericData }.count
        
        print("   📊 Avg words/chunk: \(avgWords)")
        print("   🎯 Avg semantic density: \(String(format: "%.2f", avgDensity))")
        print("   📑 Chunks with sections: \(withSections)")
        print("   🔢 Chunks with numeric data: \(withNumeric)")
    }
    
    /// Create a single chunk for very small documents
    private func createSingleChunk(
        _ text: String,
        documentId: UUID,
        pageNumbers: [Int: Range<String.Index>]? = nil
    ) -> EnhancedChunk {
        let wordCount = text.split(separator: " ").count
        
        // Extract basic metadata
        let keywords = extractKeywords(text, topN: 5)
        let hasNumeric = text.range(of: #"\d+"#, options: .regularExpression) != nil
        let hasList = text.contains("•") || text.range(of: #"^\d+\."#, options: .regularExpression) != nil
        
        let metadata = EnhancedChunk.ChunkMetadata(
            documentId: documentId,
            chunkIndex: 0,
            totalChunks: 1,
            pageNumber: nil,
            sectionTitle: nil,
            wordCount: wordCount,
            characterCount: text.count,
            topKeywords: keywords,
            semanticDensity: 0.5, // Default for single chunk
            hasNumericData: hasNumeric,
            hasListStructure: hasList
        )
        
        return EnhancedChunk(
            content: text,
            metadata: metadata,
            embedding: nil // Will be added later by RAGService
        )
    }
}
