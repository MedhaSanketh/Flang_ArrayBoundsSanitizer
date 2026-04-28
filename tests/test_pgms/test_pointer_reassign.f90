! ============================================================
! FILE: test_pointer_reassign.f90
! DESC: Pointer is reassigned from a large array to a small one.
!       An index valid for the first target is OOB for the second.
! EXPECTED: OOB ERROR at line 32 (index 10 > upper bound 5 after reassign)
! ============================================================
program test_pointer_reassign
  implicit none
  integer, target  :: BIG(10), SMALL(5)
  integer, pointer :: P(:)
  integer :: i

  do i = 1, 10
    BIG(i) = i * 10
  end do
  do i = 1, 5
    SMALL(i) = i * 100
  end do

  ! Step 1: Point to BIG — index 10 is valid here
  P => BIG
  print *, "P points to BIG(1:10)"
  print *, "P(10) =", P(10)   ! EXPECTED: VALID

  ! Step 2: Reassign pointer to SMALL — index 10 is now OOB
  P => SMALL
  print *, "P now points to SMALL(1:5)"
  print *, "Attempting P(10) — OOB for SMALL..."
  print *, "P(10) =", P(10)   ! EXPECTED: OOB ERROR at this line (index 10 > upper bound 5)

  nullify(P)
  print *, "test_pointer_reassign: SHOULD NOT REACH HERE"
end program test_pointer_reassign
