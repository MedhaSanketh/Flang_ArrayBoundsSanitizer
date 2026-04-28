! ============================================================
! FILE: test_allocatable_oob.f90
! DESC: Allocatable array A(5:15) accessed out of bounds.
!       Tests that sanitizer respects custom lower bound.
! EXPECTED: OOB ERROR at line 22 (index 4 < lower bound 5)
!           OOB ERROR at line 27 (index 16 > upper bound 15)
! ============================================================
program test_allocatable_oob
  implicit none
  integer, allocatable :: A(:)
  integer :: i

  allocate(A(5:15))

  do i = 5, 15
    A(i) = i
  end do

  ! Valid accesses first
  print *, "A(5)  =", A(5)    ! EXPECTED: VALID
  print *, "A(15) =", A(15)   ! EXPECTED: VALID

  ! Access below custom lower bound
  print *, "Accessing A(4) — below lower bound 5..."
  print *, "A(4) =", A(4)     ! EXPECTED: OOB ERROR at this line (index 4 < lower bound 5)

  deallocate(A)
  print *, "test_allocatable_oob: SHOULD NOT REACH HERE"
end program test_allocatable_oob
