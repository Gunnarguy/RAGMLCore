# CoreML Framework Reference Guide

The `raw/` folder contains the full JSON dump from Apple's CoreML documentation. For RAGMLCore's optional custom model inference pathway, start with the `essentials/` folder and sections below – it highlights APIs for running `.mlpackage` models on-device.

| Topic | Why it matters for RAGMLCore | Primary JSON file |
| --- | --- | --- |
| MLModel | Load and execute compiled models | `essentials/documentation_coreml_mlmodel.json` |
| Model Loading | Initialize ML models from bundles | `essentials/documentation_coreml_mlmodel_init(contentsof:).json` |
| Model Prediction | Run inference with MLMultiArray input | `essentials/documentation_coreml_mlmodel_prediction(from:).json` |
| MLMultiArray | Tensor-like data structure for I/O | `essentials/documentation_coreml_mlmultiarray.json` |
| Feature Provider | Input/output protocol for models | `essentials/documentation_coreml_mlfeatureprovider.json` |

## Related Files Per Topic

- **MLModel:** `essentials/documentation_coreml_mlmodel_init(contentsof:).json`, `essentials/documentation_coreml_mlmodel_compilemodel(at:).json`
- **Model Loading:** `essentials/documentation_coreml_mlmodel_load(contentsof:configuration:).json`, `essentials/documentation_coreml_mlmodel_load(contentsof:configuration:completionhandler:).json`
- **Model Prediction:** `essentials/documentation_coreml_mlmodel_prediction(from:).json`, `essentials/documentation_coreml_mlmodel_prediction(from:options:).json`
- **MLMultiArray:** `essentials/documentation_coreml_mlmultiarray_init(shape:datatype:).json`, `essentials/documentation_coreml_mlmultiarray_init(datapointer:shape:datatype:strides:deallocator:).json`

## Working With The Dump

- **Need a missing symbol?** Search the `raw/` directory. Every JSON filename mirrors the slug in Apple's documentation portal.
- **Want diffable updates?** Re-run the scraper and drop new files into `raw/`; `essentials/` only mirrors the subset above.
- **Parsing tips:**
  - Titles live under the `title` key.
  - Code samples and field docs sit in `topics[*].content` arrays.
  - `jq '.abstract' raw/<file>.json` gives a quick summary.

## Updating The Essentials List

1. Add or remove filenames in `Docs/coreml/essentials/` (copy from `raw/`).
2. Update the table above so the cheat sheet stays in sync.

With this layout, the firehose stays inside `raw/`, while the custom model inference code paths remain one click away.
