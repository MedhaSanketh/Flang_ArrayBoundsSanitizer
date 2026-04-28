! ============================================================
! FILE: test_pointer_valid.f90
! DESC: Pointer associated with a full array; valid accesses.
!       P => A(1:8): pointer inherits bounds 1..8.
! EXPECTED: All accesses VALID — no OOB error should occur.
! ============================================================
program test_pointer_valid
  implicit none
  integer, target  :: A(8)
  integer, pointer :: P(:)
  integer :: i

  do i = 1, 8
    A(i) = i * 4
  end do

  P => A   ! pointer to full array, bounds 1..8

  print *, "P(1) =", P(1)   ! EXPECTED: VALID (lower bound)
  print *, "P(5) =", P(5)   ! EXPECTED: VALID (middle)
  print *, "P(8) =", P(8)   ! EXPECTED: VALID (upper bound)

  nullify(P)
  print *, "test_pointer_valid: ALL ACCESSES VALID"
end program test_pointer_valid
