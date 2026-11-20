// RUN: %eopt --enzyme --canonicalize --remove-unnecessary-enzyme-ops --canonicalize %s | FileCheck %s

// The adjoint of memmove(dst, src, n) of doubles is dsrc[i] += ddst[i];
// ddst[i] = 0 over n bytes, as a memcpy's is, but the two ranges can overlap:
// ddst is first moved to a buffer of its own and zeroed, and the buffer is
// then added to dsrc and freed.

!u64i = !cir.int<u, 64>
!void = !cir.void
module {
  cir.func @move(%dst: !cir.ptr<!cir.double>, %src: !cir.ptr<!cir.double>, %n: !u64i) {
    %d = cir.cast bitcast %dst : !cir.ptr<!cir.double> -> !cir.ptr<!void>
    %s = cir.cast bitcast %src : !cir.ptr<!cir.double> -> !cir.ptr<!void>
    cir.libc.memmove %n bytes from %s to %d : !cir.ptr<!void>, !u64i
    cir.return
  }
  cir.func @rev(%dst: !cir.ptr<!cir.double>, %ddst: !cir.ptr<!cir.double>, %src: !cir.ptr<!cir.double>, %dsrc: !cir.ptr<!cir.double>, %n: !u64i) {
    enzyme.autodiff @move(%dst, %ddst, %src, %dsrc, %n) <{ activity=[#enzyme.activity<enzyme_dup>, #enzyme.activity<enzyme_dup>, #enzyme.activity<enzyme_const>], ret_activity=[] }> : (!cir.ptr<!cir.double>, !cir.ptr<!cir.double>, !cir.ptr<!cir.double>, !cir.ptr<!cir.double>, !u64i) -> ()
    cir.return
  }
}

// CHECK-LABEL: cir.func private @diffemove(
// CHECK-SAME:      %[[DST:[^:]+]]: !cir.ptr<!cir.double>, %[[DDST:[^:]+]]: !cir.ptr<!cir.double>, %[[SRC:[^:]+]]: !cir.ptr<!cir.double>, %[[DSRC:[^:]+]]: !cir.ptr<!cir.double>, %[[N:[^:]+]]: !u64i)
// CHECK-DAG:     %[[ZERO:.*]] = cir.const #cir.fp<0.000000e+00> : !cir.double
// CHECK-DAG:     %[[EIGHT:.*]] = cir.const #cir.int<8> : !u64i
// CHECK-DAG:     %[[BYTE:.*]] = cir.const #cir.int<0> : !u8i
// CHECK-DAG:     %[[IDX:.*]] = cir.alloca "memcpy.idx"
// CHECK-DAG:     %[[DDSTV:.*]] = cir.cast bitcast %[[DDST]] : !cir.ptr<!cir.double> -> !cir.ptr<!void>
// CHECK-DAG:     %[[DSRCV:.*]] = cir.cast bitcast %[[DSRC]] : !cir.ptr<!cir.double> -> !cir.ptr<!void>
// CHECK:         cir.libc.memmove %[[N]] bytes
// CHECK:         %[[SAVED:.*]] = cir.call @malloc(%[[N]])
// CHECK-NEXT:    cir.libc.memcpy %[[N]] bytes from %[[DDSTV]] to %[[SAVED]]
// CHECK-NEXT:    cir.libc.memset %[[N]] bytes at %[[DDSTV]] to %[[BYTE]]
// CHECK-DAG:     %[[SAVEDD:.*]] = cir.cast bitcast %[[SAVED]] : !cir.ptr<!void> -> !cir.ptr<!cir.double>
// CHECK-DAG:     %[[DSRCD:.*]] = cir.cast bitcast %[[DSRCV]] : !cir.ptr<!void> -> !cir.ptr<!cir.double>
// CHECK:         %[[COUNT:.*]] = cir.div %[[N]], %[[EIGHT]] : !u64i
// CHECK:         cir.for : cond {
// CHECK:           %[[I:.*]] = cir.load %[[IDX]]
// CHECK:           cir.cmp lt %[[I]], %[[COUNT]]
// CHECK:         } body {
// CHECK:           %[[D:.*]] = cir.ptr_stride %[[SAVEDD]]
// CHECK:           %[[S:.*]] = cir.ptr_stride %[[DSRCD]]
// CHECK:           %[[DADJ:.*]] = cir.load %[[D]]
// CHECK:           %[[SADJ:.*]] = cir.load %[[S]]
// CHECK:           %[[SUM:.*]] = cir.fadd %[[SADJ]], %[[DADJ]]
// CHECK:           cir.store %[[SUM]], %[[S]]
// CHECK:           cir.store %[[ZERO]], %[[D]]
// CHECK:         } step {
// CHECK:         cir.call @free(%[[SAVED]])
// CHECK-NEXT:    cir.return
