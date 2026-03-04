# =================================================================================
# cmake-format: off
# SPDX-FileCopyrightText: Copyright (c) 2025-2026, NVIDIA CORPORATION & AFFILIATES.
# SPDX-License-Identifier: BSD-3-Clause
# cmake-format: on
# =================================================================================

set(cython_sources test_cython.pyx)
# <<<<<<< OLD CODE from c8212ba2 (15cd66cf) - COMMENTED OUT
# set(linked_libraries ucxx::ucxx ucxx::python Python3::Module)
# =======
set(linked_libraries ucxx::ucxx ucxx::python)
# >>>>>>> END NEW CODE (15cd66cf)

rapids_cython_create_modules(
  CXX
  SOURCE_FILES "${cython_sources}"
  LINKED_LIBRARIES "${linked_libraries}" ASSOCIATED_TARGETS ucxx ucxx_python COMPONENT testing
)

target_include_directories(test_cython PRIVATE ".")
