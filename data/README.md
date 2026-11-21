# README `./data/`

All data for the repository belongs under `./data/`, which consists of the following sub-directories:

```plaintext
├── data/
  ├── metadata/    # Metadata information e.g. data dictionary, provenance
  └── source-data/ # Source data used as input in the workflow
```

- `source-data/` contains data from third party sources, we do not track this folder in git. If this folder is empty or missing, follow instructions for data download in the `/scripts/` folder.
- `metadata/` contains metadata like data dictionaries or provenance information
