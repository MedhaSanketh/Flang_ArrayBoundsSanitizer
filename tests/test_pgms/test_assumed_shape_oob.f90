! ============================================================
! FILE: test_assumed_shape_oob.f90
! DESC: Assumed-shape dummy argument accessed out of bounds.
!       Array of size 6 is passed; index 7 is accessed inside.
! EXPECTED: OOB ERROR at line 27 (index 7 > upper bound 6)
! ============================================================
program test_assumed_shape_oob
  implicit none
  integer :: A(6)
  integer :: i

  do i = 1, 6
    A(i) = i * 2
  end do

  print *, "Passing A(1:6) to subroutine..."
  call bad_access(A)
  print *, "test_assumed_shape_oob: SHOULD NOT REACH HERE"

contains

  subroutine bad_access(X)
    integer, intent(in) :: X(:)   ! assumed-shape, size = 6
    print *, "X(1) =", X(1)       ! EXPECTED: VALID
    print *, "X(6) =", X(6)       ! EXPECTED: VALID (upper bound)
    print *, "Attempting X(7) inside subroutine..."
    print *, "X(7) =", X(7)       ! EXPECTED: OOB ERROR at this line (index 7 > upper bound 6)
  end subroutine bad_access

end program test_assumed_shape_oob
