program bench1_static_sequential
  implicit none
  integer, parameter :: N = 40000000
  integer, parameter :: N_REPEATS = 10
  integer :: a(N)
  integer :: i, r, checksum
  real(8) :: t1, t2, wall, cpu
  integer(8) :: count, count_rate, count_max

  ! Initialization
  do i = 1, N
     a(i) = i
  end do

  ! Phase A: Sequential read (stride=1)
  checksum = 0
  call system_clock(count, count_rate, count_max)
  t1 = real(count, 8) / real(count_rate, 8)
  call cpu_time(t2)
  
  do r = 1, N_REPEATS
     do i = 1, N
        checksum = checksum + a(i)
     end do
  end do
  
  call system_clock(count, count_rate, count_max)
  wall = (real(count, 8) / real(count_rate, 8)) - t1
  call cpu_time(t1)
  cpu = t1 - t2
  
  print "(A,E25.14,A,E25.14,A,E25.14)", "[PHASE:Sequential_Read] wall=", wall, " cpu=", cpu, " throughput=", (real(N, 8)*N_REPEATS/max(wall, 1d-9))/1d9
  print *, "[CHECKSUM] ", checksum
  call flush(6)

  ! Phase B: Strided read (stride=64)
  checksum = 0
  call system_clock(count, count_rate, count_max)
  t1 = real(count, 8) / real(count_rate, 8)
  call cpu_time(t2)
  
  do r = 1, N_REPEATS
     do i = 1, N, 64
        checksum = checksum + a(i)
     end do
  end do
  
  call system_clock(count, count_rate, count_max)
  wall = (real(count, 8) / real(count_rate, 8)) - t1
  call cpu_time(t1)
  cpu = t1 - t2
  
  print "(A,E25.14,A,E25.14,A,E25.14)", "[PHASE:Strided_Read] wall=", wall, " cpu=", cpu, " throughput=", (real(N/64, 8)*N_REPEATS/max(wall, 1d-9))/1d9
  print *, "[CHECKSUM] ", checksum
  call flush(6)

  ! Phase C: Sequential write
  call system_clock(count, count_rate, count_max)
  t1 = real(count, 8) / real(count_rate, 8)
  call cpu_time(t2)
  
  do r = 1, N_REPEATS
     do i = 1, N
        a(i) = i + r
     end do
  end do
  
  call system_clock(count, count_rate, count_max)
  wall = (real(count, 8) / real(count_rate, 8)) - t1
  call cpu_time(t1)
  cpu = t1 - t2
  
  print "(A,E25.14,A,E25.14,A,E25.14)", "[PHASE:Sequential_Write] wall=", wall, " cpu=", cpu, " throughput=", (real(N, 8)*N_REPEATS/max(wall, 1d-9))/1d9
  print *, "[CHECKSUM] ", a(N)
  call flush(6)

  ! Intentional OOB access
!  print *, "[OOB_SENTINEL] Accessing a(N+1)"
!  i = N + 1
!  print *, a(i)  !$OOB_LINE: 77
end program bench1_static_sequential
