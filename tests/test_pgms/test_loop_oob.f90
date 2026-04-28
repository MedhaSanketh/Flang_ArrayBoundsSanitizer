! ============================================================
! FILE: test_loop_oob.f90
! DESC: Loop over 1..N+1 but array only has N elements.
!       The final iteration (i=N+1) causes OOB access.
! EXPECTED: OOB ERROR when loop reaches i=11 (index 11 > upper bound 10)
! ============================================================
program test_loop_oob
  implicit none
  integer, parameter :: N = 10
  integer :: A(N)
  integer :: i, total

  do i = 1, N
    A(i) = i
  end do

  total = 0
  print *, "Summing A(1..11) — last iteration is OOB..."
  do i = 1, N + 1    ! Loop goes one step too far
    print *, "  Accessing A(", i, ")..."
    total = total + A(i)   ! EXPECTED: OOB ERROR when i=11 (index 11 > upper bound 10)
  end do

  print *, "total =", total
  print *, "test_loop_oob: SHOULD NOT REACH HERE"
end program test_loop_oob
