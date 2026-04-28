! ============================================================
! FILE: test_static_oob_upper.f90
! DESC: Static array access beyond the upper bound.
! EXPECTED: OOB ERROR at line 20 (index 11 > upper bound 10)
! ============================================================
program test_static_oob_upper
  implicit none
  integer, parameter :: N = 10
  integer :: A(N)
  integer :: i

  do i = 1, N
    A(i) = i
  end do

  print *, "Accessing A(10) (valid upper bound)..."
  print *, "A(10) =", A(10)   ! EXPECTED: VALID

  print *, "Now accessing A(11) (one beyond upper bound)..."
  print *, "A(11) =", A(11)   ! EXPECTED: OOB ERROR at this line (index 11 > upper bound 10)

  print *, "test_static_oob_upper: SHOULD NOT REACH HERE"
end program test_static_oob_upper
