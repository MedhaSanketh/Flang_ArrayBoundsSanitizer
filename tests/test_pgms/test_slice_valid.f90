! ============================================================
! FILE: test_slice_valid.f90
! DESC: Array slices passed to subroutine; valid accesses only.
!       Slice A(3:8) has local indices 1..6 in assumed-shape arg.
! EXPECTED: All accesses VALID — no OOB error should occur.
! ============================================================
program test_slice_valid
  implicit none
  integer :: A(10)
  integer :: i

  do i = 1, 10
    A(i) = i * 3
  end do

  print *, "Passing slice A(3:8) to subroutine (6 elements)..."
  call use_slice(A(3:8))   ! slice has local indices 1..6

  print *, "Passing strided slice A(1:9:2) to subroutine (5 elements)..."
  call use_slice(A(1:9:2)) ! indices 1,3,5,7,9 — 5 elements locally 1..5

  print *, "test_slice_valid: ALL ACCESSES VALID"

contains

  subroutine use_slice(S)
    integer, intent(in) :: S(:)
    print *, "S(1)       =", S(1)         ! EXPECTED: VALID
    print *, "S(size(S)) =", S(size(S))   ! EXPECTED: VALID (upper bound)
  end subroutine use_slice

end program test_slice_valid
