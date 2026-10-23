# Changelog

hip-ucxx is AMD's port of NVIDIA's UCXX: an object-oriented C++ interface for
UCX with native Python bindings, for GPU-direct communication on AMD GPUs via
the HIP/ROCm platform. It is part of the AMD Data Science ecosystem.

## [Release Version 0.2.0 / AMD Data Science 26.10]

### Features
- Updated to upstream ucxx 0.50 (RAPIDS 26.06), bringing in its new features and bug fixes.

### Platform Support
- Raised the minimum Python version to 3.11 (dropped 3.10); now supports Python 3.11, 3.12, and 3.13.
- Updated to ROCm 10.0.0.

### Known Limitations
- The CCCL buffer allocator was changed to use synchronous memory allocation instead of asynchronous
allocation, because UCX on ROCm does not yet support asynchronously allocated memory. A patched UCX
is planned that adds support for asynchronously allocated memory in `rocm_copy`, along with graceful
failure and fallback for `rocm_ipc`.

## [Initial Release Version 0.1.0 / AMD Data Science 26.03]

### Platform Support
- Initial HIP/ROCm port of ucxx, targeting upstream ucxx from RAPIDS 25.10.
- ROCm 7.2.3.
- Ubuntu 22.04 and 24.04.
- AMD Instinct GPUs: MI355X (gfx950), MI325X / MI300X (gfx942), MI250 / MI210 (gfx90a).
- Python 3.10, 3.11, 3.12, and 3.13.

### Features
- Published as `amd-hipucxx`: a C++ library plus the Python packages `ucxx`, `libucxx`, and `distributed-ucxx`.
- GPU-direct communication on AMD GPUs over InfiniBand, ROCm-IPC/XGMI, shared memory, and TCP.
- Supports tag matching, active messages, and stream-based communication.
- Dask Distributed communication backend (`distributed-ucxx`).
