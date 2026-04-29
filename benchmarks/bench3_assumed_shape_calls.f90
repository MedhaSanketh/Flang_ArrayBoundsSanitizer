program bench3_assumed_shape_calls
  implicit none
  integer, parameter :: N = 15000000
  integer, parameter :: N_REPEATS = 10
  integer :: a(N)
  integer :: i, r, checksum
  real(8) :: t1, t2, wall, cpu
  integer(8) :: count, count_rate, count_max

  do i = 1, N; a(i) = i; end do

  ! Phase A: Amortized call overhead (3 calls)
  checksum = 0
  call system_clock(count, count_rate, count_max)
  t1 = real(count, 8) / real(count_rate, 8)
  call cpu_time(t2)
  
  do r = 1, N_REPEATS
     call process_amortized(a, N, checksum)
  end do
  
  call system_clock(count, count_rate, count_max)
  wall = (real(count, 8) / real(count_rate, 8)) - t1
  call cpu_time(t1)
  cpu = t1 - t2
  
  print "(A,E25.14,A,E25.14,A,E25.14)", "[PHASE:Amortized_Calls] wall=", wall, " cpu=", cpu, " throughput=", (real(N, 8)*N_REPEATS/max(wall, 1d-9))/1d9
  print *, "[CHECKSUM] ", checksum
  call flush(6)

  ! Phase B: Call-site overhead (30,000 calls)
  checksum = 0
  call system_clock(count, count_rate, count_max)
  t1 = real(count, 8) / real(count_rate, 8)
  call cpu_time(t2)
  
  do r = 1, N_REPEATS
     do i = 1, 30000
        call process_tiny(a((i-1)*100+1 : i*100), checksum)
     end do
  end do
  
  call system_clock(count, count_rate, count_max)
  wall = (real(count, 8) / real(count_rate, 8)) - t1
  call cpu_time(t1)
  cpu = t1 - t2
  
  print "(A,E25.14,A,E25.14,A,E25.14)", "[PHASE:CallSite_Overhead] wall=", wall, " cpu=", cpu, " throughput=", (real(30000*100, 8)*N_REPEATS/max(wall, 1d-9))/1d9
  print *, "[CHECKSUM] ", checksum
  call flush(6)

  ! Phase C: Slice forwarding
  checksum = 0
  call system_clock(count, count_rate, count_max)
  t1 = real(count, 8) / real(count_rate, 8)
  call cpu_time(t2)
  
  do r = 1, N_REPEATS
     if (mod(r, 2) == 0) then
        call process_tiny(a(1:N:2), checksum)
     else
        call process_tiny(a(2:N:2), checksum)
     end if
  end do
  
  call system_clock(count, count_rate, count_max)
  wall = (real(count, 8) / real(count_rate, 8)) - t1
  call cpu_time(t1)
  cpu = t1 - t2
  
  print "(A,E25.14,A,E25.14,A,E25.14)", "[PHASE:Slice_Forwarding] wall=", wall, " cpu=", cpu, " throughput=", (real(N/2, 8)*N_REPEATS/max(wall, 1d-9))/1d9
  print *, "[CHECKSUM] ", checksum
  call flush(6)

  ! Intentional OOB access
  print *, "[OOB_SENTINEL] Accessing index K+1 in subroutine"
  call trigger_oob(a, N)

contains
  subroutine process_amortized(arr, size, cs)
    integer, intent(in) :: arr(:)
    integer, intent(in) :: size
    integer, intent(inout) :: cs
    integer :: j
    call process_tiny(arr(1:size/3), cs)
    call process_tiny(arr(size/3+1:2*size/3), cs)
    call process_tiny(arr(2*size/3+1:size), cs)
  end subroutine

  subroutine process_tiny(arr, cs)
    integer, intent(in) :: arr(:)
    integer, intent(inout) :: cs
    integer :: j
    do j = 1, size(arr)
       cs = cs + arr(j)
    end do
  end subroutine

  subroutine trigger_oob(arr, k)
    integer, intent(in) :: arr(:)
    integer, intent(in) :: k
    print *, arr(k+1)  !$OOB_LINE: 94
  end subroutine
end program bench3_assumed_shape_calls
