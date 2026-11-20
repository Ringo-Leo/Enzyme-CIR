// RUN: %eopt --cir-raise-enzyme-calls %s | FileCheck %s

// ClangIR emits memmove, and __builtin_memmove, as a call to the C library.
// It is raised to cir.libc.memmove, whose derivative is known, and the call's
// result is its destination.

!u64i = !cir.int<u, 64>
!void = !cir.void
module {
  cir.func private @memmove(!cir.ptr<!void>, !cir.ptr<!void>, !u64i) -> !cir.ptr<!void>
  cir.func @move(%d: !cir.ptr<!void>, %s: !cir.ptr<!void>, %n: !u64i) -> !cir.ptr<!void> {
    %r = cir.call @memmove(%d, %s, %n) : (!cir.ptr<!void>, !cir.ptr<!void>, !u64i) -> !cir.ptr<!void>
    cir.return %r : !cir.ptr<!void>
  }
}

// CHECK-LABEL: cir.func{{.*}} @move(
// CHECK-SAME:      %[[D:[^:]+]]: !cir.ptr<!void>, %[[S:[^:]+]]: !cir.ptr<!void>, %[[N:[^:]+]]: !u64i)
// CHECK-NEXT:    cir.libc.memmove %[[N]] bytes from %[[S]] to %[[D]] : !cir.ptr<!void>, !u64i
// CHECK-NEXT:    cir.return %[[D]] : !cir.ptr<!void>
