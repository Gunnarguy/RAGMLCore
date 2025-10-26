#!/bin/bash
# Clean and rebuild RAGMLCore to force UI updates

echo "🧹 Cleaning build artifacts..."
cd "$(dirname "$0")"

# Clean Xcode build folder
xcodebuild -project RAGMLCore.xcodeproj -scheme RAGMLCore clean

# Remove derived data
echo "🗑️  Removing derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/RAGMLCore-*

echo "✅ Clean complete! Now:"
echo "   1. DELETE the app from your simulator/device"
echo "   2. Run: ⌘R in Xcode"
echo ""
echo "The OpenAI Configuration section should appear in Settings"
echo "right after 'Private Cloud Compute Settings'"
