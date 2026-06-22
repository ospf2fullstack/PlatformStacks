#!/bin/bash
# Roboflow Supervision - Validation Script
# Validates that the supervision library is installed and functional

set -e

echo "=== Roboflow Supervision Validation ==="
echo ""

# Check Python version
echo "[1/5] Checking Python version..."
python3 --version
PYTHON_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')")
echo "  ✓ Python $PYTHON_VERSION detected"

# Check supervision install
echo "[2/5] Checking supervision installation..."
SV_VERSION=$(python3 -c "import supervision; print(supervision.__version__)")
echo "  ✓ supervision v$SV_VERSION installed"

# Check OpenCV
echo "[3/5] Checking OpenCV..."
CV_VERSION=$(python3 -c "import cv2; print(cv2.__version__)")
echo "  ✓ OpenCV v$CV_VERSION available"

# Check core functionality
echo "[4/5] Testing core Detections API..."
python3 -c "
import supervision as sv
import numpy as np

# Create sample detections
detections = sv.Detections(
    xyxy=np.array([[100, 100, 200, 200], [300, 300, 400, 400]]),
    confidence=np.array([0.9, 0.8]),
    class_id=np.array([0, 1])
)
assert len(detections) == 2
print('  ✓ Detections API functional')
"

# Check annotators
echo "[5/5] Testing annotators..."
python3 -c "
import supervision as sv
import numpy as np

# Create a blank image and test annotation
image = np.zeros((480, 640, 3), dtype=np.uint8)
detections = sv.Detections(
    xyxy=np.array([[100, 100, 200, 200]]),
    confidence=np.array([0.95]),
    class_id=np.array([0])
)
annotator = sv.BoxAnnotator()
result = annotator.annotate(scene=image.copy(), detections=detections)
assert result.shape == (480, 640, 3)
print('  ✓ BoxAnnotator functional')
"

echo ""
echo "=== All validation checks passed ✓ ==="
