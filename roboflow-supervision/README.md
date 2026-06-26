# Roboflow Supervision - Computer Vision Toolkit

## Overview

[Roboflow Supervision](https://github.com/roboflow/supervision) is an open-source, model-agnostic Python library for building production computer vision applications. It provides a unified `Detections` API with connectors for 15+ model frameworks, 20+ annotators, object tracking, zone counting, dataset management, and evaluation metrics.

- **GitHub Stars**: 44,800+
- **Monthly PyPI Downloads**: 1,000,000+
- **License**: MIT
- **Python**: >=3.9
- **Latest Stable**: v0.27.0

## Prerequisites

| Requirement | Version | Notes |
|-------------|---------|-------|
| Python | >=3.9 | Python 3.13 supported (incl. free-threaded) |
| pip / uv | Latest | Package manager |
| GPU (optional) | CUDA 11.8+ | Only needed for GPU-accelerated inference models |
| Docker (optional) | 20.10+ | For containerized deployments |
| Kubernetes (optional) | 1.25+ | For scaled inference pipelines |

## Quick Start

### Installation

```bash
# Basic install
pip install supervision

# With all optional dependencies
pip install "supervision[desktop]"

# Using uv (faster)
uv pip install supervision
```

### Minimal Example

```python
import supervision as sv
from ultralytics import YOLO

# Load model
model = YOLO("yolov8n.pt")

# Run inference
results = model("image.jpg")

# Convert to unified Detections format
detections = sv.Detections.from_ultralytics(results[0])

# Annotate
annotator = sv.BoxAnnotator()
annotated_image = annotator.annotate(
    scene=results[0].orig_img.copy(),
    detections=detections
)
```

## Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│                  Your Application                     │
├─────────────────────────────────────────────────────┤
│              supervision (unified API)               │
├──────────┬──────────┬──────────┬───────────────────┤
│ Annotators│ Tracking │  Zones   │ Datasets/Metrics  │
├──────────┴──────────┴──────────┴───────────────────┤
│            sv.Detections (core data model)           │
├──────────┬──────────┬──────────┬───────────────────┤
│Ultralytics│ HF Trans│ Inference│ MMDet/Detectron2  │
│ SAM/SAM2  │Florence-2│ YOLO-NAS │ PaddleDet/NCNN   │
└──────────┴──────────┴──────────┴───────────────────┘
```

### Core Concepts

1. **`sv.Detections`** — Unified data container for all detection/segmentation results
2. **Connectors** — `from_ultralytics()`, `from_transformers()`, `from_inference()`, etc.
3. **Annotators** — `BoxAnnotator`, `MaskAnnotator`, `LabelAnnotator`, `TraceAnnotator`, etc.
4. **Trackers** — ByteTrack integration for multi-object tracking
5. **Zones** — `PolygonZone`, `LineZone` for counting and filtering
6. **Datasets** — Load/save YOLO, COCO, Pascal VOC formats
7. **Metrics** — mAP, F1, Precision, Recall, Confusion Matrix

## Configuration Reference

### Key Annotator Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `thickness` | int | 2 | Line thickness for box annotations |
| `color` | Color/ColorPalette | DEFAULT | Color scheme for annotations |
| `text_scale` | float | 0.5 | Label text scale |
| `text_padding` | int | 5 | Padding around label text |

### Tracker Configuration

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `track_activation_threshold` | float | 0.25 | Minimum confidence to start track |
| `lost_track_buffer` | int | 30 | Frames to keep lost tracks |
| `minimum_matching_threshold` | float | 0.8 | Minimum IoU for match |
| `frame_rate` | int | 30 | Video frame rate |

### Zone Configuration

| Parameter | Type | Description |
|-----------|------|-------------|
| `polygon` | np.ndarray | Zone boundary vertices |
| `triggering_anchors` | List[Position] | Which detection anchors trigger zone |
| `frame_resolution_wh` | Tuple[int, int] | Frame dimensions for zone |

## Deployment Patterns

### Pattern 1: Single-Node Inference Service

```bash
# See scripts/deploy-single-node.sh
docker build -t sv-inference -f docker/Dockerfile .
docker run -p 8000:8000 --gpus all sv-inference
```

### Pattern 2: Kubernetes Batch Processing

```bash
# Deploy inference workers
kubectl apply -f kubernetes/inference-deployment.yaml
kubectl apply -f kubernetes/inference-service.yaml
```

### Pattern 3: Real-Time Video Stream Processing

```bash
# Deploy stream processor with GPU
kubectl apply -f kubernetes/stream-processor.yaml
```

## Validation / Testing

```bash
# Run the validation script
./scripts/validate.sh

# Manual checks
python -c "import supervision; print(supervision.__version__)"
python scripts/test-inference.py --image test.jpg --model yolov8n
```

## Troubleshooting

| Issue | Cause | Solution |
|-------|-------|----------|
| `ImportError: cv2` | OpenCV not installed | `pip install opencv-python` |
| CUDA out of memory | Model too large for GPU | Use smaller model or CPU inference |
| Slow annotation | Large images | Resize before annotation |
| Tracker ID resets | Frame gaps | Increase `lost_track_buffer` |
| Zone not triggering | Wrong anchors | Set `triggering_anchors=[Position.BOTTOM_CENTER]` |

## Supported Model Frameworks

| Framework | Connector | Detection | Segmentation | Classification |
|-----------|-----------|-----------|--------------|----------------|
| Ultralytics (YOLO) | `from_ultralytics()` | ✅ | ✅ | ✅ |
| Roboflow Inference | `from_inference()` | ✅ | ✅ | ✅ |
| HF Transformers | `from_transformers()` | ✅ | ✅ | ❌ |
| SAM / SAM2 | `from_sam()` | ❌ | ✅ | ❌ |
| Detectron2 | `from_detectron2()` | ✅ | ✅ | ❌ |
| MMDetection | `from_mmdetection()` | ✅ | ✅ | ❌ |
| YOLO-NAS | `from_yolo_nas()` | ✅ | ❌ | ❌ |
| PaddleDet | `from_paddledet()` | ✅ | ❌ | ❌ |
| Florence-2 | `from_lmm()` | ✅ | ✅ | ❌ |

## Links

- **Documentation**: https://supervision.roboflow.com
- **GitHub**: https://github.com/roboflow/supervision
- **PyPI**: https://pypi.org/project/supervision
- **Blog Post**: https://garyinnerarity.com/blog/?post=roboflow-supervision-cv-toolkit
