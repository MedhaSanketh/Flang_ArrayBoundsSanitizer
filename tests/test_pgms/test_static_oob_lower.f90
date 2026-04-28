! ============================================================
! FILE: test_static_oob_lower.f90
! DESC: Static array access below the default lower bound (1).
! EXPECTED: OOB ERROR at line 21 (index 0 < lower bound 1)
! ============================================================
program test_static_oob_lower
  implicit none
  integer, parameter :: N = 10
  integer :: A(N)    ! bounds: A(1:10)
  integer :: i, idx

  do i = 1, N
    A(i) = i * 3
  end do

  print *, "Accessing A(1) (valid lower bound)..."
  print *, "A(1) =", A(1)   ! EXPECTED: VALID

  print *, "Now accessing A(0) (one below lower bound)..."
  idx = 0
  print *, "A(idx) =", A(idx)   ! EXPECTED: OOB ERROR at this line (index 0 < lower bound 1)

  print *, "test_static_oob_lower: SHOULD NOT REACH HERE"
end program test_static_oob_lower
