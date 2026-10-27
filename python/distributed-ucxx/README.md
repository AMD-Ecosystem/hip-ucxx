# hip-ucxx Communication Backend for Dask Distributed

`amd-distributed-hipucxx` is the UCX-based communication backend for
[Dask Distributed](https://distributed.dask.org/), providing high-performance,
GPU-direct communication on AMD GPUs using HIP/ROCm. It enables efficient
GPU-to-GPU transfers over ROCm-IPC/XGMI, InfiniBand, shared memory, and TCP.

It is part of [hip-ucxx](https://github.com/AMD-Ecosystem/hip-ucxx), derived from
the [UCXX](https://github.com/rapidsai/ucxx) project by NVIDIA Corporation, and
belongs to the [AMD Data Science](https://github.com/AMD-Ecosystem/datascience)
ecosystem. The Python module is imported as `distributed_ucxx`.

For full documentation, see the
[hip-ucxx documentation](https://rocm.docs.amd.com/projects/hip-ucxx/en/latest/).

## Installation

If you have the hip-ucxx source repository, build and install this package with
the provided `build.hip.sh` script. Otherwise, install the pre-built wheel
directly from AMD PyPI:

```bash
pip install amd-distributed-hipucxx --extra-index-url=https://pypi.amd.com/rocm-10.0.0/simple/
```

Installing `amd-distributed-hipucxx` pulls in `amd-hipucxx` (and, transitively, a
ROCm-enabled `amd-libucx`). Adjust the `rocm-10.0.0` index to match your ROCm
version. See the
[installation guide](https://rocm.docs.amd.com/projects/hip-ucxx/en/latest/install/install.html)
for details.

## Configuration

This package provides its own configuration namespace (`distributed-ucxx`).
Configuration can be supplied via:

1. **YAML files**: `distributed-ucxx.yaml`
2. **Environment variables**: using the `DASK_DISTRIBUTED_UCXX__` prefix
3. **Programmatically**: via Dask's configuration system

The schema for the YAML file is defined in `distributed_ucxx/distributed-ucxx-schema.yaml`,
available in the source repository.

### Transports and options

Some common options are:

- `tcp` — enable TCP over UCX.
- `rocm-copy` — enable ROCm copy support over UCX (GPU memory over any transport,
  including TCP). The AMD analogue of `cuda-copy`.
- `rocm-ipc` — enable UCX over ROCm-IPC/XGMI for direct GPU-to-GPU transfers;
  implies `tcp=true`. The AMD analogue of `nvlink`.
- `infiniband` — enable UCX over InfiniBand; implies `tcp=true`.
- `multi-buffer` — enable the multi-buffer send/recv interface for many small
  messages.
- `environment` — set arbitrary UCX environment variables (`some-option: value`
  becomes `UCX_SOME_OPTION=value`; run `ucx_info -f` for the full list).
- `rmm.pool-size` — [hipMM](https://github.com/AMD-Ecosystem/hipMM) memory-pool
  size for GPU allocations (e.g. `"1GB"`).

### Example (YAML)

```yaml
distributed-ucxx:
  tcp: true
  rocm-ipc: true       # direct GPU-to-GPU over ROCm-IPC/XGMI
  rocm-copy: true
  infiniband: false
  multi-buffer: false
  environment:
    log-level: "info"
  rmm:
    pool-size: "1GB"
```

### Environment variables

```bash
export DASK_DISTRIBUTED_UCXX__TCP=true
export DASK_DISTRIBUTED_UCXX__ROCM_IPC=true
export DASK_DISTRIBUTED_UCXX__ROCM_COPY=true
export DASK_DISTRIBUTED_UCXX__RMM__POOL_SIZE=1GB
```

Nested keys use `__`; hyphens become underscores and names are uppercased, so
`distributed-ucxx.rocm-ipc` maps to `DASK_DISTRIBUTED_UCXX__ROCM_IPC`.

### Python

```python
import dask

dask.config.set({
    "distributed-ucxx.tcp": True,
    "distributed-ucxx.rocm-ipc": True,
    "distributed-ucxx.rmm.pool-size": "1GB",
})
```

## Usage

The package registers itself as a Distributed communication backend on install,
under both the `ucxx` and `ucx` protocol prefixes. Specify the protocol when
connecting:

```python
from distributed import Client

client = Client("ucxx://scheduler-address:8786")
```

Or when starting a scheduler/worker:

```bash
dask scheduler --protocol ucxx
dask worker ucxx://scheduler-address:8786
```

With [dask-hip](https://github.com/AMD-AIOSS/dask-hip)'s
`LocalCUDACluster`, select it via `protocol="ucxx"`.

## See Also

- [hip-ucxx documentation](https://rocm.docs.amd.com/projects/hip-ucxx/en/latest/)
- [hip-ucxx on GitHub](https://github.com/AMD-Ecosystem/hip-ucxx)
- [Dask Distributed Documentation](https://distributed.dask.org/)
- [UCX Project Documentation](https://openucx.readthedocs.io/en/master/index.html)

## License

hip-ucxx is licensed under a combination of the BSD 3-Clause License (for code
derived from NVIDIA UCXX) and the MIT License (for AMD additions). See the
`LICENSE` and `NOTICE.txt` files for the full license texts.
