/**
 * SPDX-FileCopyrightText: Copyright (c) 2022-2026, NVIDIA CORPORATION & AFFILIATES.
 * SPDX-FileCopyrightText: Copyright (c) 2026 Advanced Micro Devices, Inc.
 * SPDX-License-Identifier: BSD-3-Clause AND MIT
 */
#include <memory>
#include <stdexcept>
#include <utility>

#include <ucxx/buffer.h>
#include <ucxx/log.h>

#include <cuda/buffer>
#include <cuda/memory_resource>

#include <ucxx/cuda_runtime.h>

namespace ucxx {

/**
 * @brief Minimal CCCL synchronous memory resource backed by cudaMalloc/cudaFree.
 *
 * cuda::device_default_memory_pool() returns a stream-ordered pool and allocates VMEM
 * memory (HSA_EXT_POINTER_TYPE_HSA_VMEM), which is not IPC-shareable via the API used
 * by UCX's rocm_ipc and makes its rocm_ipc export fail. This resource instead
 * allocates plain device-local memory (HSA_EXT_POINTER_TYPE_HSA, coarse-grained)
 * that legacy rocm_ipc can export, matching what the RMM path already does with
 * rmm::mr::cuda_memory_resource. It satisfies
 * cuda::mr::synchronous_resource_with<..., device_accessible>.
 */
struct rocm_device_memory_resource {
  void* allocate_sync(size_t bytes, size_t /*alignment*/ = 256)
  {
    void* ptr = nullptr;
    if (cudaMalloc(&ptr, bytes) != cudaSuccess) { throw std::bad_alloc(); }
    return ptr;
  }

  void deallocate_sync(void* ptr, size_t /*bytes*/, size_t /*alignment*/ = 256) noexcept
  {
    static_cast<void>(cudaFree(ptr));
  }

  bool operator==(const rocm_device_memory_resource&) const noexcept { return true; }
  bool operator!=(const rocm_device_memory_resource&) const noexcept { return false; }

  friend constexpr void get_property(const rocm_device_memory_resource&,
                                     ::cuda::mr::device_accessible) noexcept
  {
  }

  using default_queries = ::cuda::mr::properties_list<::cuda::mr::device_accessible>;
};

static_assert(::cuda::mr::synchronous_resource_with<
              rocm_device_memory_resource, ::cuda::mr::device_accessible>);

/**
 * @brief Concrete CCCL buffer implementation.
 */
struct CCCLBufferImpl {
  using cccl_buffer_type = ::cuda::buffer<::cuda::std::byte, ::cuda::mr::device_accessible>;
  cccl_buffer_type buffer;

  static auto get_device_pool()
  {
    static_cast<void>(cudaFree(0));  // Ensure CUDA primary context is initialized
    return rocm_device_memory_resource{};
  }

  explicit CCCLBufferImpl(const size_t size)
    : buffer{::cudaStream_t{0}, get_device_pool(), size, ::cuda::no_init}
  {
  }
};

CCCLBuffer::CCCLBuffer(const size_t size)
  : Buffer(BufferType::CCCL, size), _impl{std::make_unique<CCCLBufferImpl>(size)}
{
  ucxx_trace_data("ucxx::CCCLBuffer created: %p, impl: %p, size: %lu", this, _impl.get(), size);
}

CCCLBuffer::~CCCLBuffer() = default;

void* CCCLBuffer::data()
{
  ucxx_trace_data("ucxx::CCCLBuffer::%s, CCCLBuffer: %p, impl: %p", __func__, this, _impl.get());
  if (!_impl) throw std::runtime_error("Invalid object or already released");

  // Explicit cast required: cuda::buffer::data() returns cuda::std::byte*, not void*.
  // RMMBuffer::data() needs no cast since rmm::device_buffer::data() returns void* directly.
  return static_cast<void*>(_impl->buffer.data());
}

}  // namespace ucxx
