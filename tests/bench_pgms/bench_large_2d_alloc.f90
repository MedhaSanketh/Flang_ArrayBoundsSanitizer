! ============================================================
! FILE: bench_large_2d_alloc.f90
! DESC: BENCHMARK — Large allocatable 2D array (1000x1000).
!       Full matrix traversal (valid), then OOB column access.
!       Tests sanitizer cost for 2D descriptor checks at scale.
! EXPECTED: Valid matrix sum completes; OOB ERROR at line 40
!           (col index 1001 > upper bound 1000)
! ============================================================
program bench_large_2d_alloc
  implicit none
  integer, parameter :: ROWS = 1000, COLS = 1000
  real, allocatable  :: M(:,:)
  integer :: i, j
  real(kind=8) :: total

  allocate(M(1:ROWS, 1:COLS))

  ! Initialize matrix
  do j = 1, COLS
    do i = 1, ROWS
      M(i, j) = real(i) * 0.1 + real(j) * 0.01
    end do
  end do

  ! ---- VALID PHASE: full traversal (1M accesses) ----
  total = 0.0d0
  do j = 1, COLS
    do i = 1, ROWS
      total = total + M(i, j)   ! EXPECTED: VALID — 1,000,000 iterations
    end do
  end do
  print *, "Matrix sum =", total

  ! ---- VALID EDGE: boundary corners ----
  print *, "M(1,1)       =", M(1, 1)          ! EXPECTED: VALID
  print *, "M(1000,1000) =", M(ROWS, COLS)    ! EXPECTED: VALID

  ! ---- OOB PHASE: column index beyond upper bound ----
  print *, "Attempting M(1, 1001) — col 1001 > upper bound 1000..."
  print *, "M(1,1001) =", M(1, COLS + 1)      ! EXPECTED: OOB ERROR at this line

  deallocate(M)
  print *, "bench_large_2d_alloc: SHOULD NOT REACH HERE"
end program bench_large_2d_alloc
