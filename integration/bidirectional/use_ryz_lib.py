#!/usr/bin/env python3
# Bi-directional proof: a FOREIGN language (Python) runs RYZ code by loading a ryz-built
# shared library (libmathlib.so) via the C ABI. No ryz toolchain needed to CONSUME ryz.
# This is the "easy to install with the shared-libs half" direction.
import ctypes, sys, os

so = sys.argv[1] if len(sys.argv) > 1 else os.path.expanduser(
    "/mnt/c/Users/Fixxia/developing-mind-reproduction/ryz/dist/libmathlib.so")
lib = ctypes.CDLL(so)
for name in ("add", "mul", "fib"):
    fn = getattr(lib, name)
    fn.restype = ctypes.c_longlong
    fn.argtypes = [ctypes.c_longlong] * (1 if name == "fib" else 2)

print("python -> ryz .so:  add(20,22) =", lib.add(20, 22),
      "| mul(6,7) =", lib.mul(6, 7), "| fib(20) =", lib.fib(20))
assert lib.add(20, 22) == 42 and lib.mul(6, 7) == 42 and lib.fib(20) == 6765
print("OK: Python executed RYZ code through the shared library (bi-directional outward).")
