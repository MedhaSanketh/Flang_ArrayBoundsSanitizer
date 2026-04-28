! ============================================================
! FILE: test_dynamic_bounds.f90
! DESC: Array size determined at runtime via command-line arg.
!       Accesses index N+1 which is always OOB regardless of N.
! EXPECTED: OOB ERROR at line 31 when accessing index N+1 (> upper bound N)
! ============================================================
program test_dynamic_bounds
  implicit none
  integer, allocatable :: A(:)
  integer :: N, i
  character(len=20) :: arg

  ! Default size if no argument provided
  N = 8
  if (command_argument_count() >= 1) then
    call get_command_argument(1, arg)
    read(arg, *) N
  end if

  print *, "Dynamic N =", N
  allocate(A(1:N))

  do i = 1, N
    A(i) = i * 3
  end do

  print *, "A(1)  =", A(1)    ! EXPECTED: VALID (lower bound)
  print *, "A(N)  =", A(N)    ! EXPECTED: VALID (upper bound)

  print *, "Attempting A(N+1) — always OOB for any N..."
  print *, "A(N+1) =", A(N+1) ! EXPECTED: OOB ERROR at this line (index N+1 > upper bound N)

  deallocate(A)
  print *, "test_dynamic_bounds: SHOULD NOT REACH HERE"
end program test_dynamic_bounds
