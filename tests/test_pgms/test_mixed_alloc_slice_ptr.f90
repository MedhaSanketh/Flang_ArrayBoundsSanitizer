! ============================================================
! FILE: test_mixed_alloc_slice_ptr.f90
! DESC: Allocatable array A(1:20), slice A(5:15) taken, then
!       a pointer is aimed at that slice. OOB via pointer.
! EXPECTED: OOB ERROR at line 35 (index 16 > upper bound 15 of slice)
! ============================================================
program test_mixed_alloc_slice_ptr
  implicit none
  integer, allocatable, target :: A(:)
  integer, pointer             :: P(:)
  integer :: i

  allocate(A(1:20))
  do i = 1, 20
    A(i) = i * 5
  end do

  ! Pointer to slice A(5:15) — inherits index range 5..15
  P => A(5:15)

  print *, "A allocated (1:20), P => A(5:15)"
  print *, "P(5)  =", P(5)    ! EXPECTED: VALID (lower bound of slice)
  print *, "P(10) =", P(10)   ! EXPECTED: VALID (middle)
  print *, "P(15) =", P(15)   ! EXPECTED: VALID (upper bound of slice)

  print *, "Attempting P(16) — beyond pointer/slice upper bound 15..."
  print *, "P(16) =", P(16)   ! EXPECTED: OOB ERROR at this line (index 16 > upper bound 15)

  nullify(P)
  deallocate(A)
  print *, "test_mixed_alloc_slice_ptr: SHOULD NOT REACH HERE"
end program test_mixed_alloc_slice_ptr
