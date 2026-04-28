! ============================================================
! FILE: bench_assumed_shape_stress.f90
! DESC: BENCHMARK — Stress test for assumed-shape descriptor
!       checks. Passes large array (50000 elem) through multiple
!       subroutine layers. Valid reduce, then OOB at final layer.
!       Measures sanitizer cost through call-chain depth.
! EXPECTED: Valid reductions complete; OOB ERROR inside leaf()
!           at line 55 (index size(Z)+1 > upper bound)
! ============================================================
program bench_assumed_shape_stress
  implicit none
  integer, parameter :: N = 50000
  real :: A(N)
  integer :: i

  do i = 1, N
    A(i) = real(i) * 0.5
  end do

  print *, "Starting multi-layer subroutine stress test (N =", N, ")..."
  call level1(A)
  print *, "bench_assumed_shape_stress: SHOULD NOT REACH HERE"

contains

  ! Level 1: receives full array, passes slice to level 2
  subroutine level1(X)
    real, intent(in) :: X(:)   ! size N
    real(kind=8) :: s
    integer :: k
    s = 0.0d0
    do k = 1, size(X)
      s = s + X(k)             ! EXPECTED: VALID — N iterations
    end do
    print *, "level1 sum =", s
    ! Pass middle slice to level 2
    call level2(X(1001:49000))  ! 48000 elements
  end subroutine level1

  ! Level 2: receives slice, passes smaller slice to level 3
  subroutine level2(Y)
    real, intent(in) :: Y(:)   ! size 48000
    real(kind=8) :: s
    integer :: k
    s = 0.0d0
    do k = 1, size(Y)
      s = s + Y(k)             ! EXPECTED: VALID — 48000 iterations
    end do
    print *, "level2 sum =", s
    ! Pass further sub-slice to leaf
    call leaf(Y(101:47900))    ! 47800 elements
  end subroutine level2

  ! Leaf: valid reduction, then intentional OOB
  subroutine leaf(Z)
    real, intent(in) :: Z(:)   ! size 47800
    real(kind=8) :: s
    integer :: k
    s = 0.0d0
    do k = 1, size(Z)
      s = s + Z(k)             ! EXPECTED: VALID — 47800 iterations
    end do
    print *, "leaf sum =", s
    ! OOB: one past upper bound
    print *, "leaf: Attempting Z(size(Z)+1)..."
    print *, "Z(oob) =", Z(size(Z) + 1)  ! EXPECTED: OOB ERROR at this line
  end subroutine leaf

end program bench_assumed_shape_stress
