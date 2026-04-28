! ============================================================
! FILE: test_2d_valid.f90
! DESC: 2D array A(4,6); valid accesses across both dimensions.
! EXPECTED: All accesses VALID — no OOB error should occur.
! ============================================================
program test_2d_valid
  implicit none
  integer :: A(4, 6)
  integer :: i, j

  do j = 1, 6
    do i = 1, 4
      A(i, j) = i * 10 + j
    end do
  end do

  print *, "A(1,1) =", A(1, 1)   ! EXPECTED: VALID (corner)
  print *, "A(4,6) =", A(4, 6)   ! EXPECTED: VALID (opposite corner)
  print *, "A(2,3) =", A(2, 3)   ! EXPECTED: VALID (interior)
  print *, "A(4,1) =", A(4, 1)   ! EXPECTED: VALID (edge)
  print *, "A(1,6) =", A(1, 6)   ! EXPECTED: VALID (edge)

  print *, "test_2d_valid: ALL ACCESSES VALID"
end program test_2d_valid
