! ============================================================
! FILE: test_assumed_shape_valid.f90
! DESC: Pass array to subroutine with assumed-shape dummy arg.
!       All accesses inside subroutine are within bounds.
! EXPECTED: All accesses VALID — no OOB error should occur.
! ============================================================
program test_assumed_shape_valid
  implicit none
  integer :: A(8)
  integer :: i

  do i = 1, 8
    A(i) = i * 5
  end do

  print *, "Calling subroutine with full array A(1:8)..."
  call process_array(A)
  print *, "test_assumed_shape_valid: ALL ACCESSES VALID"

contains

  subroutine process_array(X)
    integer, intent(in) :: X(:)   ! assumed-shape: inherits bounds 1..8
    print *, "X(1) =", X(1)       ! EXPECTED: VALID (lower bound)
    print *, "X(4) =", X(4)       ! EXPECTED: VALID (middle)
    print *, "X(8) =", X(8)       ! EXPECTED: VALID (upper bound)
    print *, "size(X) =", size(X) ! Should print 8
  end subroutine process_array

end program test_assumed_shape_valid
