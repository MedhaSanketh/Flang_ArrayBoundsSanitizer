! ============================================================
! FILE: test_allocatable_valid.f90
! DESC: Allocatable array with custom bounds A(5:15).
!       All accesses are within valid range [5..15].
! EXPECTED: All accesses VALID — no OOB error should occur.
! ============================================================
program test_allocatable_valid
  implicit none
  integer, allocatable :: A(:)
  integer :: i

  ! Allocate with custom lower bound 5, upper bound 15
  allocate(A(5:15))

  do i = 5, 15
    A(i) = i * 10
  end do

  print *, "A(5)  =", A(5)    ! EXPECTED: VALID (lower bound)
  print *, "A(10) =", A(10)   ! EXPECTED: VALID (middle)
  print *, "A(15) =", A(15)   ! EXPECTED: VALID (upper bound)

  deallocate(A)
  print *, "test_allocatable_valid: ALL ACCESSES VALID"
end program test_allocatable_valid
