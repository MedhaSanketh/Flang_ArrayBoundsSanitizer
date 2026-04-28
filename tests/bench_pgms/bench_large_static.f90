! ============================================================
! FILE: bench_large_static.f90
! DESC: BENCHMARK — Large static array (100000 elements).
!       Repeated valid read loop, then one OOB write access.
!       Used to measure sanitizer overhead on hot valid paths.
! EXPECTED: Valid loop completes; OOB ERROR at line 36
!           (index 100001 > upper bound 100000)
! ============================================================
program bench_large_static
  implicit none
  integer, parameter :: N = 100000
  integer :: A(N)
  integer :: i, bad_idx
  integer(kind=8) :: total

  ! Initialize
  do i = 1, N
    A(i) = i
  end do

  ! ---- VALID PHASE: sum all elements (hot path for sanitizer) ----
  total = 0
  do i = 1, N
    total = total + A(i)   ! EXPECTED: VALID — repeated N times
  end do
  print *, "Sum of A(1:", N, ") =", total   ! Should be N*(N+1)/2

  ! ---- VALID EDGE: access exact boundaries ----
  print *, "A(1)      =", A(1)      ! EXPECTED: VALID (lower bound)
  print *, "A(100000) =", A(N)      ! EXPECTED: VALID (upper bound)

  ! ---- OOB PHASE: one access beyond upper bound ----
  print *, "Attempting A(100001) — one beyond upper bound..."
  bad_idx = N + 1
  A(bad_idx) = 999                    ! EXPECTED: OOB ERROR at this line (write, index N+1 > N)

  print *, "bench_large_static: SHOULD NOT REACH HERE"
end program bench_large_static
