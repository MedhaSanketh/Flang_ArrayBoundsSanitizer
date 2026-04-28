! ============================================================
! FILE: test_3d_oob_dim3.f90
! DESC: 3D array A(3,3,3); access beyond third dimension.
!       A(2,2,4) accesses depth index 4 where valid is 1..3.
! EXPECTED: OOB ERROR at line 28 (dim3 index 4 > upper bound 3)
! ============================================================
program test_3d_oob_dim3
  implicit none
  integer :: A(3, 3, 3)   ! valid: A(1:3, 1:3, 1:3)
  integer :: i, j, k
  integer :: d1, d2, d3

  do k = 1, 3
    do j = 1, 3
      do i = 1, 3
        A(i, j, k) = i + j*10 + k*100
      end do
    end do
  end do

  print *, "A(1,1,1) =", A(1, 1, 1)   ! EXPECTED: VALID (min corner)
  print *, "A(3,3,3) =", A(3, 3, 3)   ! EXPECTED: VALID (max corner)
  print *, "A(2,2,3) =", A(2, 2, 3)   ! EXPECTED: VALID (boundary depth)
  d1 = 2
  d2 = 2
  d3 = 4
  print *, "Attempting A(d1,d2,d3) — depth index 4 > upper bound 3..."
  print *, "A(d1,d2,d3) =", A(d1, d2, d3)   ! EXPECTED: OOB ERROR at this line (dim3 index 4 > 3)

  print *, "test_3d_oob_dim3: SHOULD NOT REACH HERE"
end program test_3d_oob_dim3
