! ============================================================
! FILE: test_zero_length.f90
! DESC: Zero-length allocatable array (allocate A(1:0)).
!       Any element access is immediately OOB.
! EXPECTED: OOB ERROR at line 20 (any index into zero-length array)
! ============================================================
program test_zero_length
  implicit none
  integer, allocatable :: A(:)

  ! Allocate zero-length array (valid Fortran, size = 0)
  allocate(A(1:0))

  print *, "Allocated A(1:0) — zero elements, size =", size(A)
  print *, "Attempting A(1) — OOB for zero-length array..."
  print *, "A(1) =", A(1)   ! EXPECTED: OOB ERROR at this line (array has 0 elements)

  deallocate(A)
  print *, "test_zero_length: SHOULD NOT REACH HERE"
end program test_zero_length
