program bench2_allocatable_descriptor
  implicit none
  integer, parameter :: N = 20000000
  integer, parameter :: N_REPEATS = 10
  integer, allocatable :: a(:)
  integer :: i, r, checksum, current_n
  real(8) :: t1, t2, wall, cpu
  integer(8) :: count, count_rate, count_max

  ! Phase A: Standard descriptor (1:N)
  allocate(a(1:N))
  do i = 1, N; a(i) = i; end do
  
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
  
  print "(A,E25.14,A,E25.14,A,E25.14)", "[PHASE:Standard_Descriptor] wall=", wall, " cpu=", cpu, " throughput=", (real(N, 8)*N_REPEATS/max(wall, 1d-9))/1d9
  print *, "[CHECKSUM] ", checksum
  call flush(6)
  deallocate(a)

  ! Phase B: Negative-lb descriptor (-N/2:N/2)
  allocate(a(-N/2 : N/2))
  do i = -N/2, N/2; a(i) = i; end do
  
  checksum = 0
  call system_clock(count, count_rate, count_max)
  t1 = real(count, 8) / real(count_rate, 8)
  call cpu_time(t2)
  
  do r = 1, N_REPEATS
     do i = -N/2, N/2
        checksum = checksum + a(i)
     end do
  end do
  
  call system_clock(count, count_rate, count_max)
  wall = (real(count, 8) / real(count_rate, 8)) - t1
  call cpu_time(t1)
  cpu = t1 - t2
  
  print "(A,E25.14,A,E25.14,A,E25.14)", "[PHASE:Negative_LB_Descriptor] wall=", wall, " cpu=", cpu, " throughput=", (real(N+1, 8)*N_REPEATS/max(wall, 1d-9))/1d9
  print *, "[CHECKSUM] ", checksum
  call flush(6)
  deallocate(a)

  ! Phase C: Reallocation cycles
  current_n = N
  call system_clock(count, count_rate, count_max)
  t1 = real(count, 8) / real(count_rate, 8)
  call cpu_time(t2)
  
  do r = 1, 20
     allocate(a(current_n))
     do i = 1, current_n; a(i) = i; end do
     checksum = 0
     do i = 1, current_n
        checksum = checksum + a(i)
     end do
     deallocate(a)
     current_n = int(current_n * 0.9)
  end do
  
  call system_clock(count, count_rate, count_max)
  wall = (real(count, 8) / real(count_rate, 8)) - t1
  call cpu_time(t1)
  cpu = t1 - t2
  
  print "(A,E25.14,A,E25.14,A,E25.14)", "[PHASE:Reallocation_Cycles] wall=", wall, " cpu=", cpu, " throughput=", (real(N, 8)*20/max(wall, 1d-9))/1d9
  print *, "[CHECKSUM] ", checksum
  call flush(6)

  ! Intentional OOB access
  allocate(a(current_n))
!  print *, "[OOB_SENTINEL] Accessing a(ubound+1)"
!  print *, a(ubound(a,1)+1)  !$OOB_LINE: 91
end program bench2_allocatable_descriptor
