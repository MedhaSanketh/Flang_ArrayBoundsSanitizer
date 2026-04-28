! ============================================================
! FILE: test_loop_assumed.f90
! DESC: Allocatable array is sliced and passed as assumed-shape
!       dummy argument. Loop inside subroutine runs one step past
!       the slice upper bound.
! EXPECTED: OOB ERROR at line 43 when j=9 (index 9 > slice upper bound 8)
! ============================================================
program test_loop_assumed
  implicit none

  integer, allocatable :: A(:)
  integer :: i

  ! Allocate and fill a 10-element array
  allocate(A(1:10))
  do i = 1, 10
    A(i) = i * 10
  end do

  print *, "Calling write_into_slice with A(2:9) — 8 elements..."

  ! Pass interior slice only — subroutine sees size=8, not 10
  call write_into_slice(A(2:9))

  print *, "test_loop_assumed: ALL ACCESSES VALID"

  deallocate(A)

contains

  subroutine write_into_slice(S)
    integer, intent(inout) :: S(:)   ! size 8, indices 1..8
    integer :: j

    ! Valid writes within slice bounds
    do j = 1, size(S)
      print *, "write_into_slice: S(", j, ")=", j * 99   ! EXPECTED: VALID
      S(j) = j * 99
    end do

    ! One step past the slice upper bound — OOB write
    print *, "write_into_slice: Accessing OOB S(9)..."
    S(size(S) + 1) = 0   ! EXPECTED: OOB ERROR

  end subroutine write_into_slice

end program test_loop_assumed