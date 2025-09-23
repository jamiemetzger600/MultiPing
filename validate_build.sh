#!/bin/bash

# MultiPing Build Validation Script
# This script ensures all potential compilation issues are resolved

echo "🔍 MultiPing Build Validation Script"
echo "=================================="

# Clean build directory
echo "🧹 Cleaning build directory..."
cd /Users/jamie/Documents/Multiping_1.7_BRANCH/MultiPing
xcodebuild -project MultiPing.xcodeproj -scheme MultiPing clean > /dev/null 2>&1

# Check for duplicate dictionary keys in EnhancedNetworkScanner.swift
echo "🔍 Checking for duplicate dictionary keys..."
if grep -n "enhancedVendorLookup" MultiPing/EnhancedNetworkScanner.swift | head -1 > /dev/null; then
    echo "✅ EnhancedNetworkScanner.swift found"
    
    # Check for potential duplicate keys (basic check)
    duplicates=$(grep -o '"[A-F0-9]\{6\}":' MultiPing/EnhancedNetworkScanner.swift | sort | uniq -d)
    if [ -n "$duplicates" ]; then
        echo "❌ Found potential duplicate keys:"
        echo "$duplicates"
    else
        echo "✅ No duplicate dictionary keys found"
    fi
else
    echo "❌ EnhancedNetworkScanner.swift not found or missing vendor lookup"
fi

# Check for concurrency issues
echo "🔍 Checking for concurrency issues..."
if grep -r "isCompleted" MultiPing/ --include="*.swift"; then
    echo "⚠️  Found 'isCompleted' variable - checking for concurrency issues"
else
    echo "✅ No 'isCompleted' variable found (good)"
fi

# Check for proper imports in FindDevicesWindowController.swift
echo "🔍 Checking imports in FindDevicesWindowController.swift..."
if grep -q "import SwiftUI" MultiPing/FindDevicesWindowController.swift; then
    echo "✅ SwiftUI import found"
else
    echo "❌ SwiftUI import missing"
fi

# Attempt to build the project
echo "🔨 Attempting to build project..."
build_result=$(xcodebuild -project MultiPing.xcodeproj -scheme MultiPing -configuration Debug build 2>&1)

if echo "$build_result" | grep -q "BUILD SUCCEEDED"; then
    echo "✅ Build succeeded!"
    
    # Check for warnings
    warning_count=$(echo "$build_result" | grep -c "warning:")
    if [ "$warning_count" -gt 0 ]; then
        echo "⚠️  Found $warning_count warning(s)"
        echo "$build_result" | grep "warning:" | head -5
    else
        echo "✅ No warnings found"
    fi
    
    # Check for errors
    error_count=$(echo "$build_result" | grep -c "error:")
    if [ "$error_count" -gt 0 ]; then
        echo "❌ Found $error_count error(s)"
        echo "$build_result" | grep "error:"
    else
        echo "✅ No errors found"
    fi
    
else
    echo "❌ Build failed!"
    echo "$build_result" | grep -E "(error:|warning:)" | head -10
fi

echo ""
echo "🏁 Validation complete!"
