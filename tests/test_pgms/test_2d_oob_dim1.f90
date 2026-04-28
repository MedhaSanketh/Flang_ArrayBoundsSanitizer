! ============================================================
! FILE: test_2d_oob_dim1.f90
! DESC: 2D array A(4,6); row index goes out of bounds.
!       A(5,3) is accessed where valid rows are 1..4.
! EXPECTED: OOB ERROR at line 24 (row index 5 > upper bound 4)
! ============================================================
program test_2d_oob_dim1
  implicit none
  integer :: A(4, 6)   ! valid: A(1:4, 1:6)
  integer :: i, j, row, col

  do j = 1, 6
    do i = 1, 4
      A(i, j) = i * 10 + j
    end do
  end do

  print *, "A(4,3) =", A(4, 3)   ! EXPECTED: VALID (boundary row)
  print *, "A(1,6) =", A(1, 6)   ! EXPECTED: VALID

  integer :: row, col
  row = 5
  col = 3
  print *, "Attempting A(row,col) — row 5 > upper bound 4..."
  print *, "A(row,col) =", A(row, col)   ! EXPECTED: OOB ERROR at this line (dim1 index 5 > 4)

  print *, "test_2d_oob_dim1: SHOULD NOT REACH HERE"
end program test_2d_oob_dim1
