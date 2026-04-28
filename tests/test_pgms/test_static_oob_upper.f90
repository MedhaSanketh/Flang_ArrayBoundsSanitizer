! ============================================================
! FILE: test_static_oob_upper.f90
! DESC: Static array access beyond the upper bound.
! EXPECTED: OOB ERROR at line 20 (index 11 > upper bound 10)
! ============================================================
program test_static_oob_upper
  implicit none
  integer, parameter :: N = 10
  integer :: A(N)
  integer :: i, idx

  do i = 1, N
    A(i) = i
  end do

  print *, "Accessing A(10) (valid upper bound)..."
  print *, "A(10) =", A(10)   ! EXPECTED: VALID
  idx = 11
  print *, "Now accessing A(idx) (one beyond upper bound)..."
  print *, "A(idx) =", A(idx)   ! EXPECTED: OOB ERROR at this line (index 11 > upper bound 10)

  print *, "test_static_oob_upper: SHOULD NOT REACH HERE"
end program test_static_oob_upper
