! ============================================================
! FILE: test_nested_calls.f90
! DESC: Nested subroutine calls. Outer passes slice A(2:9);
!       inner subroutine passes a sub-slice S(2:7) further.
!       Deep access is valid at all levels except last.
! EXPECTED: OOB ERROR at line 35 when loop reaches i=11 (index 7 > upper bound 6)
! ============================================================
program test_nested_calls
  implicit none
  integer :: A(10)
  integer :: i

  do i = 1, 10
    A(i) = i * 2
  end do

  print *, "Calling outer with A(2:9) — 8 elements..."
  call outer(A(2:9))
  print *, "test_nested_calls: ALL ACCESSES VALID"

contains

  subroutine outer(X)
    integer, intent(in) :: X(:)   ! size 8, indices 1..8
    print *, "outer: X(1)=", X(1), " X(8)=", X(8)   ! EXPECTED: VALID
    print *, "outer: Calling inner with X(2:7) — 6 elements..."
    call inner(X(2:7))
  end subroutine outer

  subroutine inner(Y)
    integer, intent(in) :: Y(:)   ! size 6, indices 1..6
    print *, "inner: Y(1)=", Y(1), " Y(6)=", Y(6)   ! EXPECTED: VALID
    print *, "inner: Y(3)=", Y(3)                    ! EXPECTED: VALID
    print *, "inner: Accessing OOB Y(7)..."
    print *, "inner: Y(7)=", Y(7)                    ! EXPECTED: OOB ERROR
  end subroutine inner

end program test_nested_calls
