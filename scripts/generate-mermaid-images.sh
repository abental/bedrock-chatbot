#!/bin/bash
# Generate PNG images from Mermaid diagrams in markdown files

set -e

DOCS_DIR="/Users/israelbental/my_code/bedrock-chatbot/docs"
IMAGES_DIR="$DOCS_DIR/images"
TEMP_DIR="/tmp/mermaid-temp"

# Create directories
mkdir -p "$IMAGES_DIR"
mkdir -p "$TEMP_DIR"

echo "🎨 Generating Mermaid diagram images..."

# Check if mermaid-cli is installed
if ! command -v mmdc &> /dev/null; then
    echo "❌ Error: mermaid-cli (mmdc) is not installed"
    echo "Install it with: npm install -g @mermaid-js/mermaid-cli"
    exit 1
fi

# Extract mermaid blocks and convert to images
cd "$DOCS_DIR"

# Process ARCHITECTURE.md
if [ -f "ARCHITECTURE.md" ]; then
    echo "📄 Processing ARCHITECTURE.md..."
    
    # Extract the main architecture diagram (first mermaid block)
    sed -n '/```mermaid/,/```/p' ARCHITECTURE.md | sed '1d;$d' > "$TEMP_DIR/architecture-main.mmd"
    if [ -s "$TEMP_DIR/architecture-main.mmd" ]; then
        mmdc -i "$TEMP_DIR/architecture-main.mmd" -o "$IMAGES_DIR/architecture-main.png" -b transparent
        echo "✅ Generated: architecture-main.png"
    fi
fi

# Process ARCHITECTURE_DIAGRAM.md
if [ -f "ARCHITECTURE_DIAGRAM.md" ]; then
    echo "📄 Processing ARCHITECTURE_DIAGRAM.md..."
    
    # This file has multiple diagrams - extract each one
    awk '/```mermaid/{flag=1; count++; next} /```/{flag=0} flag' ARCHITECTURE_DIAGRAM.md > "$TEMP_DIR/all-diagrams.txt"
    
    # Split into individual diagram files
    csplit -f "$TEMP_DIR/diagram-" -b "%02d.mmd" "$TEMP_DIR/all-diagrams.txt" '/^graph\|^sequenceDiagram\|^mindmap\|^flowchart/' '{*}' 2>/dev/null || true
    
    # Convert each diagram
    for diagram_file in "$TEMP_DIR"/diagram-*.mmd; do
        if [ -f "$diagram_file" ] && [ -s "$diagram_file" ]; then
            basename=$(basename "$diagram_file" .mmd)
            mmdc -i "$diagram_file" -o "$IMAGES_DIR/$basename.png" -b transparent
            echo "✅ Generated: $basename.png"
        fi
    done
fi

# Clean up temp directory
rm -rf "$TEMP_DIR"

echo ""
echo "🎉 Done! Generated images are in: $IMAGES_DIR"
echo ""
echo "To use in markdown, add:"
echo '![Diagram Description](./images/diagram-name.png)'

