#!/bin/bash

PW_v68_CPU=/home/ivan/devel/q-e-reference_cpu/PW/src/pw.x
PW_v68_GPU=/home/ivan/devel/q-e-gfortran/PW/src/pw.x

export OMP_NUM_THREADS=1 

  mpirun -np 1 ${PW_v68_CPU} -inp  k7208076uspaw.in                  >       k7208076uspaw.np01.v68cpu.log        
  ${PW_v68_GPU} <                  k7208076uspaw.in                  >       k7208076uspaw.serial.v68gpu.log      
  mpirun -np 1 ${PW_v68_CPU} -inp  k1000033uspaw.in                  >       k1000033uspaw.np01.v68cpu.log          
  ${PW_v68_GPU} <                  k1000033uspaw.in                  >       k1000033uspaw.serial.v68gpu.log      
  mpirun -np 1 ${PW_v68_CPU} -inp  gamma4021161uspaw.in              >       gamma4021161uspaw.np01.v68cpu.log       
  ${PW_v68_GPU} <                  gamma4021161uspaw.in              >       gamma4021161uspaw.serial.v68gpu.log    
  mpirun -np 1 ${PW_v68_CPU} -inp  Si255.in                          >       Si255.np01.v68cpu.log                 
  ${PW_v68_GPU} <                  Si255.in                          >       Si255.serial.v68gpu.log               

rm -rf out/
rm -rf pwscf.* 

