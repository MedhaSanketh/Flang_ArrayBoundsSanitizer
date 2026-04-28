! ============================================================
! FILE: test_slice_complex.f90
! DESC: A slice A(2:5) (4 elements) is passed to a subroutine.
!       The subroutine tries to access index 5, but the slice
!       only has local indices 1..4.
! EXPECTED: OOB ERROR at line 30 (index 5 > upper bound 4 of slice)
! ============================================================
program test_slice_complex
  implicit none
  integer :: A(10)
  integer :: i

  do i = 1, 10
    A(i) = i * 7
  end do

  print *, "Passing slice A(2:5) — 4 elements — to subroutine..."
  call check_slice(A(2:5))   ! local indices 1..4

  print *, "test_slice_complex: SHOULD NOT REACH HERE"

contains

  subroutine check_slice(S)
    integer, intent(in) :: S(:)  ! size = 4, bounds 1..4
    print *, "S(1) =", S(1)      ! EXPECTED: VALID
    print *, "S(4) =", S(4)      ! EXPECTED: VALID (upper bound of slice)
    print *, "Attempting S(5) — beyond slice upper bound..."
    print *, "S(5) =", S(5)      ! EXPECTED: OOB ERROR at this line (index 5 > upper bound 4)
  end subroutine check_slice

end program test_slice_complex
