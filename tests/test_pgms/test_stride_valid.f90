! ============================================================
! FILE: test_stride_valid.f90
! DESC: Allocatable array A(1:10) is passed as a strided slice
!       A(1:10:2) — odd indices only, 5 elements.
!       Subroutine walks the assumed-shape dummy with stride 1
!       (descriptor re-indexes to 1..5), all accesses stay in bounds.
! EXPECTED: ALL ACCESSES VALID — no OOB error
! ============================================================
program test_stride_valid
  implicit none

  integer, allocatable :: A(:)
  integer :: i

  ! Allocate and fill a 10-element array
  allocate(A(1:10))
  do i = 1, 10
    A(i) = i * 5
  end do

  print *, "Calling read_strided with A(1:10:2) — 5 elements..."

  ! Strided slice: picks A(1), A(3), A(5), A(7), A(9)
  ! Subroutine sees a contiguous descriptor of size 5
  call read_strided(A(1:10:2))

  print *, "test_stride_valid: ALL ACCESSES VALID"

  deallocate(A)

contains

  subroutine read_strided(S)
    integer, intent(in) :: S(:)   ! size 5, indices 1..5
    integer :: j

    ! Walk all 5 elements — all within descriptor bounds
    do j = 1, size(S)
      print *, "read_strided: S(", j, ")=", S(j)   ! EXPECTED: VALID
    end do

  end subroutine read_strided

end program test_stride_valid