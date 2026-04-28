! ============================================================
! FILE: test_static_valid.f90
! DESC: Static fixed-size array with only valid accesses.
! EXPECTED: All accesses VALID — no OOB error should occur.
! ============================================================
program test_static_valid
  implicit none
  integer, parameter :: N = 10
  integer :: A(N)
  integer :: i

  ! Initialize array
  do i = 1, N
    A(i) = i * 2
  end do

  ! Access exactly at lower bound (index 1)   -- VALID
  print *, "A(1)  =", A(1)   ! EXPECTED: VALID (lower bound)

  ! Access exactly at upper bound (index 10)  -- VALID
  print *, "A(10) =", A(10)  ! EXPECTED: VALID (upper bound)

  ! Access middle element                     -- VALID
  print *, "A(5)  =", A(5)   ! EXPECTED: VALID

  print *, "test_static_valid: ALL ACCESSES VALID"
end program test_static_valid
