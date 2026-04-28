! ============================================================
! FILE: test_pointer_oob.f90
! DESC: Pointer P => A(3:7) (5 elements, local bounds 3..7).
!       Access P(8) is beyond the pointer's upper bound of 7.
! EXPECTED: OOB ERROR at line 25 (index 8 > upper bound 7)
! ============================================================
program test_pointer_oob
  implicit none
  integer, target  :: A(10)
  integer, pointer :: P(:)
  integer :: i

  do i = 1, 10
    A(i) = i * 2
  end do

  ! Pointer to slice — preserves original index space (3..7)
  P => A(3:7)

  print *, "P(3) =", P(3)   ! EXPECTED: VALID (lower bound of slice)
  print *, "P(7) =", P(7)   ! EXPECTED: VALID (upper bound of slice)

  print *, "Attempting P(8) — beyond pointer upper bound 7..."
  print *, "P(8) =", P(8)   ! EXPECTED: OOB ERROR at this line (index 8 > upper bound 7)

  nullify(P)
  print *, "test_pointer_oob: SHOULD NOT REACH HERE"
end program test_pointer_oob
