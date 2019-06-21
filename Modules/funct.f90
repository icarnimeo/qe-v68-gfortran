!
! Copyright (C) 2004-2016 Quantum ESPRESSO group
! This file is distributed under the terms of the
! GNU General Public License. See the file `License'
! in the root directory of the present distribution,
! or http://www.gnu.org/copyleft/gpl.txt .
!
!-------------------------------------------------------------------
MODULE funct
  !-------------------------------------------------------------------
  !! This module contains data defining the DFT functional in use
  !! and a number of functions and subroutines to manage them.  
  !! Data are PRIVATE and are accessed and set only by function calls.
  !
  !   setting routines:  set_dft_from_name (previously which_dft)
  !                      set_dft_from_indices
  !                      enforce_input_dft
  !                      start_exx
  !                      stop_exx
  !                      set_finite_size_volume
  !   retrieve functions: get_dft_name, get_dft_short, get_dft_long
  !                      get_iexch
  !                      get_icorr
  !                      get_igcx
  !                      get_igcc
  !                      get_exx_fraction
  !                      write_dft_name
  !  logical functions:  dft_is_gradient
  !                      dft_is_meta
  !                      dft_is_hybrid
  !                      dft_is_nonlocc
  !                      exx_is_active
  !                      dft_has_finite_size_correction
  !
  !
  USE io_global,   ONLY: stdout
  USE kinds,       ONLY: DP
#if defined(__LIBXC)
  USE xc_f90_types_m
  USE xc_f90_lib_m
#endif
  !
  IMPLICIT NONE
  !
  PRIVATE
  SAVE
  !
  ! subroutines/functions managing dft name and indices
  PUBLIC  :: set_dft_from_indices, set_dft_from_name
  PUBLIC  :: enforce_input_dft, write_dft_name
  PUBLIC  :: get_dft_name, get_dft_short, get_dft_long,&
             get_nonlocc_name
  PUBLIC  :: get_iexch, get_icorr, get_igcx, get_igcc, get_meta, get_inlc
  PUBLIC  :: dft_is_gradient, dft_is_meta, dft_is_hybrid, dft_is_nonlocc, igcc_is_lyp
  PUBLIC  :: set_auxiliary_flags
  !
  ! additional subroutines/functions for hybrid functionals
  PUBLIC  :: start_exx, stop_exx, get_exx_fraction, exx_is_active
  PUBLIC  :: set_exx_fraction, dft_force_hybrid
  PUBLIC  :: set_screening_parameter, get_screening_parameter
  PUBLIC  :: set_gau_parameter, get_gau_parameter
  !
  ! additional subroutines/functions for finite size corrections
  PUBLIC  :: dft_has_finite_size_correction, set_finite_size_volume
  ! rpa specific
  PUBLIC  :: init_dft_exxrpa, enforce_dft_exxrpa
  !
  ! driver subroutines computing XC
  PUBLIC  :: init_xc, is_libxc
  PUBLIC  :: tau_xc , tau_xc_spin
  PUBLIC  :: tau_xc_array, tau_xc_array_spin
  PUBLIC  :: nlc
  !
  ! PRIVATE variables defining the DFT functional
  !
  PRIVATE :: dft, iexch, icorr, igcx, igcc, imeta, inlc
  PRIVATE :: discard_input_dft
  PRIVATE :: isgradient, ismeta, ishybrid
  PRIVATE :: exx_fraction, exx_started
  PRIVATE :: has_finite_size_correction, &
             finite_size_cell_volume,  finite_size_cell_volume_set
  !
  CHARACTER(LEN=25) :: dft = 'not set'
  !
  ! ------------------------------------------------------------------------
  ! "dft" is the exchange-correlation functional label, as set by the user,
  ! using either set_dft_from_name or set_dft_from_indices. It can contain
  ! either the short names or a series of the keywords listed below.
  ! All operations on names are case-insensitive.
  !
  !           short name       complete name       Short description
  !              "pz"    = "sla+pz"            = Perdew-Zunger LDA
  !              "bp"    = "b88+p86"           = Becke-Perdew grad.corr.
  !              "pw91"  = "sla+pw+ggx+ggc"    = PW91 (aka GGA)
  !              "blyp"  = "sla+b88+lyp+blyp"  = BLYP
  !              "pbe"   = "sla+pw+pbx+pbc"    = PBE
  !              "revpbe"= "sla+pw+rpb+pbc"    = revPBE (Zhang-Yang)
  !              "pw86pbe" = "sla+pw+pw86+pbc" = PW86 exchange + PBE correlation
  !              "b86bpbe" = "sla+pw+b86b+pbc" = B86b exchange + PBE correlation
  !              "pbesol"= "sla+pw+psx+psc"    = PBEsol
  !              "q2d"   = "sla+pw+q2dx+q2dc"  = PBEQ2D
  !              "hcth"  = "nox+noc+hcth+hcth" = HCTH/120
  !              "olyp"  = "nox+lyp+optx+blyp" = OLYP
  !              "wc"    = "sla+pw+wcx+pbc"    = Wu-Cohen
  !              "sogga" = "sla+pw+sox+pbec"   = SOGGA
  !              "optbk88"="sla+pw+obk8+p86"   = optB88
  !              "optb86b"="sla+pw+ob86+p86"   = optB86
  !              "ev93"  = "sla+pw+evx+nogc"   = Engel-Vosko
  !              "tpss"  = "sla+pw+tpss+tpss"  = TPSS Meta-GGA
  !              "m06l"  = "nox+noc+m6lx+m6lc" = M06L Meta-GGA
  !              "tb09"  = "sla+pw+tb09+tb09"  = TB09 Meta-GGA
  !              "pbe0"  = "pb0x+pw+pb0x+pbc"  = PBE0
  !              "b86bx" = "pb0x+pw+b86x+pbc"  = B86bPBE hybrid
  !              "bhahlyp"="pb0x+pw+b88x+blyp" = Becke half-and-half LYP
  !              "hse"   = "sla+pw+hse+pbc"    = Heyd-Scuseria-Ernzerhof (HSE 06, see note below)
  !              "b3lyp"                        = B3LYP
  !              "b3lyp-v1r"                    = B3LYP-VWN1-RPA
  !              "x3lyp"                        = X3LYP
  !              "vwn-rpa" = VWN LDA using vwn1-rpa parametrization
  !              "gaupbe"= "sla+pw+gaup+pbc"   = Gau-PBE (also "gaup")
  !              "vdw-df"       ="sla+pw+rpb +vdw1"   = vdW-DF1
  !              "vdw-df2"      ="sla+pw+rw86+vdw2"   = vdW-DF2
  !              "vdw-df-c09"   ="sla+pw+c09x+vdw1"   = vdW-DF-C09
  !              "vdw-df2-c09"  ="sla+pw+c09x+vdw2"   = vdW-DF2-C09
  !              "vdw-df-obk8"  ="sla+pw+obk8+vdw1"   = vdW-DF-obk8 (optB88-vdW)
  !              "vdw-df-ob86"  ="sla+pw+ob86+vdw1"   = vdW-DF-ob86 (optB86b-vdW)
  !              "vdw-df2-b86r" ="sla+pw+b86r+vdw2"   = vdW-DF2-B86R (rev-vdw-df2)
  !              "vdw-df-cx"    ="sla+pw+cx13+vdW1"   = vdW-DF-cx
  !              "vdw-df-cx0"    ="sla+pw+cx13+vdW1+HF/4"   = vdW-DF-cx-0
  !              "vdw-df2-0"     ="sla+pw+rw86+vdw2+HF/4"   = vdW-DF2-0
  !              "vdw-df2-br0"  ="sla+pw+b86r+vdW2+HF/4"   = vdW-DF2-b86r-0
  !              "vdw-df-c090"   ="sla+pw+c09x+vdw1+HF/4"   = vdW-DF-C09-0
  !              "vdw-df-x"     ="sla+pw+????+vdwx"   = vdW-DF-x, reserved Thonhauser, not implemented
  !              "vdw-df-y"     ="sla+pw+????+vdwy"   = vdW-DF-y, reserved Thonhauser, not implemented
  !              "vdw-df-z"     ="sla+pw+????+vdwz"   = vdW-DF-z, reserved Thonhauser, not implemented
  !              "rvv10" = "sla+pw+rw86+pbc+vv10"     = rVV10
  !
  ! Any nonconflicting combination of the following keywords is acceptable:
  !
  ! Exchange:    "nox"    none                           iexch=0
  !              "sla"    Slater (alpha=2/3)             iexch=1 (default)
  !              "sl1"    Slater (alpha=1.0)             iexch=2
  !              "rxc"    Relativistic Slater            iexch=3
  !              "oep"    Optimized Effective Potential  iexch=4
  !              "hf"     Hartree-Fock                   iexch=5
  !              "pb0x"   (Slater*0.75+HF*0.25)          iexch=6 for PBE0 and vdW-DF-cx0 and vdW-DF2-0 etc
  !              "b3lp"   B3LYP(Slater*0.80+HF*0.20)     iexch=7
  !              "kzk"    Finite-size corrections        iexch=8
  !              "x3lp"   X3LYP(Slater*0.782+HF*0.218)   iexch=9
  !              "kli"    KLI aproximation for exx       iexch=10
  !
  ! Correlation: "noc"    none                           icorr=0
  !              "pz"     Perdew-Zunger                  icorr=1 (default)
  !              "vwn"    Vosko-Wilk-Nusair              icorr=2
  !              "lyp"    Lee-Yang-Parr                  icorr=3
  !              "pw"     Perdew-Wang                    icorr=4
  !              "wig"    Wigner                         icorr=5
  !              "hl"     Hedin-Lunqvist                 icorr=6
  !              "obz"    Ortiz-Ballone form for PZ      icorr=7
  !              "obw"    Ortiz-Ballone form for PW      icorr=8
  !              "gl"     Gunnarson-Lunqvist             icorr=9
  !              "kzk"    Finite-size corrections        icorr=10
  !              "vwn-rpa" Vosko-Wilk-Nusair, alt param  icorr=11
  !              "b3lp"   B3LYP (0.19*vwn+0.81*lyp)      icorr=12
  !              "b3lpv1r"  B3LYP-VWN-1-RPA
  !                         (0.19*vwn_rpa+0.81*lyp)      icorr=13
  !              "x3lp"   X3LYP (0.129*vwn_rpa+0.871*lyp)icorr=14
  !
  ! Gradient Correction on Exchange:
  !              "nogx"   none                           igcx =0 (default)
  !              "b88"    Becke88 (beta=0.0042)          igcx =1
  !              "ggx"    Perdew-Wang 91                 igcx =2
  !              "pbx"    Perdew-Burke-Ernzenhof exch    igcx =3
  !              "rpb"    revised PBE by Zhang-Yang      igcx =4
  !              "hcth"   Cambridge exch, Handy et al    igcx =5
  !              "optx"   Handy's exchange functional    igcx =6
  !              "pb0x"   PBE0 (PBE exchange*0.75)       igcx =8
  !              "b3lp"   B3LYP (Becke88*0.72)           igcx =9
  !              "psx"    PBEsol exchange                igcx =10
  !              "wcx"    Wu-Cohen                       igcx =11
  !              "hse"    HSE screened exchange          igcx =12
  !              "rw86"   revised PW86                   igcx =13
  !              "pbe"    same as PBX, back-comp.        igcx =14
  !              "c09x"   Cooper 09                      igcx =16
  !              "sox"    sogga                          igcx =17
  !              "q2dx"   Q2D exchange grad corr         igcx =19
  !              "gaup"   Gau-PBE hybrid exchange        igcx =20
  !              "pw86"   Perdew-Wang (1986) exchange    igcx =21
  !              "b86b"   Becke (1986) exchange          igcx =22
  !              "obk8"   optB88  exchange               igcx =23
  !              "ob86"   optB86b exchange               igcx =24
  !              "evx"    Engel-Vosko exchange           igcx =25
  !              "b86r"   revised Becke (b86b)           igcx =26
  !              "cx13"   consistent exchange            igcx =27
  !              "x3lp"   X3LYP (Becke88*0.542 +
  !                              Perdew-Wang91*0.167)    igcx =28
  !              "cx0"    vdW-DF-cx+HF/4 (cx13-0)        igcx =29 
  !              "r860"   rPW86+HF/4 (rw86-0)            igcx =30 (for DF0)
  !              "cx0p"   vdW-DF-cx+HF/5 (cx13-0p)       igcx =31 
  !              "ahcx"   vdW-DF-cx based not yet in use igcx =32 reserved PH
  !              "ahf2"   vdW-DF2 based not yet in use   igcx =33 reserved PH
  !              "ahpb"   PBE based not yet in use       igcx =34 reserved PH
  !              "ahps"   PBE-sol based not in use       igcx =35 reserved PH
  !              "cx14"   Exporations                    igcx =36 reserved PH
  !              "cx15"   Exporations                    igcx =37 reserved PH
  !              "br0"    vdW-DF2-b86r+HF/4 (b86r-0)     igcx =38 
  !              "cx16"   Exporations                    igcx =39 reserved PH
  !              "c090"   vdW-DF-c09+HF/4 (c09-0)        igcx =40 
  !              "b86x"   B86b exchange * 0.75           igcx =41
  !              "b88x"   B88 exchange * 0.50            igcx =42
  !
  ! Gradient Correction on Correlation:
  !              "nogc"   none                           igcc =0 (default)
  !              "p86"    Perdew86                       igcc =1
  !              "ggc"    Perdew-Wang 91 corr.           igcc =2
  !              "blyp"   Lee-Yang-Parr                  igcc =3
  !              "pbc"    Perdew-Burke-Ernzenhof corr    igcc =4
  !              "hcth"   Cambridge corr, Handy et al    igcc =5
  !              "b3lp"   B3LYP (Lee-Yang-Parr*0.81)     igcc =7
  !              "psc"    PBEsol corr                    igcc =8
  !              "pbe"    same as PBX, back-comp.        igcc =9
  !              "q2dc"   Q2D correlation grad corr      igcc =12
  !              "x3lp"   X3LYP (Lee-Yang-Parr*0.871)    igcc =13
  !
  ! Meta-GGA functionals
  !              "tpss"   TPSS Meta-GGA                  imeta=1
  !              "m6lx"   M06L Meta-GGA                  imeta=2
  !              "tb09"   TB09 Meta-GGA                  imeta=3
  !              "+meta"  activate MGGA even without MGGA-XC   imeta=4
  !              "scan"   SCAN Meta-GGA                  imeta=5
  !              "sca0"   SCAN0  Meta-GGA                imeta=6
  !
  ! Van der Waals functionals (nonlocal term only)
  !              "nonlc"  none                           inlc =0 (default)
  !              "vdw1"   vdW-DF1                        inlc =1
  !              "vdw2"   vdW-DF2                        inlc =2
  !              "vv10"   rVV10                          inlc =3
  !              "vdwx"   vdW-DF-x                       inlc =4, reserved Thonhauser, not implemented
  !              "vdwy"   vdW-DF-y                       inlc =5, reserved Thonhauser, not implemented
  !              "vdwz"   vdW-DF-z                       inlc =6, reserved Thonhauser, not implemented
  !
  ! Meta-GGA with Van der Waals
  !              "rvv10-scan" rVV10 (with b=15.7) and scan inlc=3 (PRX 6, 041005 (2016))
  !
  ! Note: as a rule, all keywords should be unique, and should be different
  ! from the short name, but there are a few exceptions.
  !
  ! References:
  !              pz      J.P.Perdew and A.Zunger, PRB 23, 5048 (1981)
  !              vwn     S.H.Vosko, L.Wilk, M.Nusair, Can.J.Phys. 58,1200(1980)
  !              vwn1-rpa S.H.Vosko, L.Wilk, M.Nusair, Can.J.Phys. 58,1200(1980)
  !              wig     E.P.Wigner, Trans. Faraday Soc. 34, 67 (1938)
  !              hl      L.Hedin and B.I.Lundqvist, J. Phys. C4, 2064 (1971)
  !              gl      O.Gunnarsson and B.I.Lundqvist, PRB 13, 4274 (1976)
  !              pw      J.P.Perdew and Y.Wang, PRB 45, 13244 (1992)
  !              obpz    G.Ortiz and P.Ballone, PRB 50, 1391 (1994)
  !              obpw    as above
  !              b88     A.D.Becke, PRA 38, 3098 (1988)
  !              p86     J.P.Perdew, PRB 33, 8822 (1986)
  !              pw86    J.P.Perdew, PRB 33, 8800 (1986)
  !              b86b    A.D.Becke, J.Chem.Phys. 85, 7184 (1986)
  !              ob86    Klimes, Bowler, Michaelides, PRB 83, 195131 (2011)
  !              b86r    I. Hamada, Phys. Rev. B 89, 121103(R) (2014)
  !              pbe     J.P.Perdew, K.Burke, M.Ernzerhof, PRL 77, 3865 (1996)
  !              pw91    J.P.Perdew and Y. Wang, PRB 46, 6671 (1992)
  !              blyp    C.Lee, W.Yang, R.G.Parr, PRB 37, 785 (1988)
  !              hcth    Handy et al, JCP 109, 6264 (1998)
  !              olyp    Handy et al, JCP 116, 5411 (2002)
  !              revPBE  Zhang and Yang, PRL 80, 890 (1998)
  !              pbesol  J.P. Perdew et al., PRL 100, 136406 (2008)
  !              q2d     L. Chiodo et al., PRL 108, 126402 (2012)
  !              rw86    Eamonn D. Murray et al, J. Chem. Theory Comput. 5, 2754 (2009)
  !              wc      Z. Wu and R. E. Cohen, PRB 73, 235116 (2006)
  !              kzk     H.Kwee, S. Zhang, H. Krakauer, PRL 100, 126404 (2008)
  !              pbe0    J.P.Perdew, M. Ernzerhof, K.Burke, JCP 105, 9982 (1996)
  !              hse     Heyd, Scuseria, Ernzerhof, J. Chem. Phys. 118, 8207 (2003)
  !                      Heyd, Scuseria, Ernzerhof, J. Chem. Phys. 124, 219906 (2006).
  !              b3lyp   P.J. Stephens,F.J. Devlin,C.F. Chabalowski,M.J. Frisch
  !                      J.Phys.Chem 98, 11623 (1994)
  !              x3lyp   X. Xu, W.A Goddard III, PNAS 101, 2673 (2004)
  !              vdW-DF       M. Dion et al., PRL 92, 246401 (2004)
  !                           T. Thonhauser et al., PRL 115, 136402 (2015)
  !              vdW-DF2      Lee et al., Phys. Rev. B 82, 081101 (2010)
  !              rev-vdW-DF2  I. Hamada, Phys. Rev. B 89, 121103(R) (2014)
  !              vdW-DF-cx    K. Berland and P. Hyldgaard, PRB 89, 035412 (2014)
  !              vdW-DF-cx0   K. Berland, Y. Jiao, J.-H. Lee, T. Rangel, J. B. Neaton and P. Hyldgaard,
  !                           J. Chem. Phys. 146, 234106 (2017)
  !              vdW-DF-cx0p  Y. Jiao, E. Schröder and P. Hyldgaard, 
  !                           J. Chem. Phys. 148, 194115 (2018)
  !              vdW-DF-obk8  Klimes et al, J. Phys. Cond. Matter, 22, 022201 (2010)
  !              vdW-DF-ob86  Klimes et al, Phys. Rev. B, 83, 195131 (2011)
  !              c09x    V. R. Cooper, Phys. Rev. B 81, 161104(R) (2010)
  !              tpss    J.Tao, J.P.Perdew, V.N.Staroverov, G.E. Scuseria,
  !                      PRL 91, 146401 (2003)
  !              tb09    F Tran and P Blaha, Phys.Rev.Lett. 102, 226401 (2009)
  !              scan    J Sun, A Ruzsinszky and J Perdew, PRL 115, 36402 (2015)
  !              scan0   K Hui and J-D. Chai, JCP 144, 44114 (2016)
  !              sogga   Y. Zhao and D. G. Truhlar, JCP 128, 184109 (2008)
  !              m06l    Y. Zhao and D. G. Truhlar, JCP 125, 194101 (2006)
  !              gau-pbe J.-W. Song, K. Yamashita, K. Hirao JCP 135, 071103 (2011)
  !              rVV10   R. Sabatini et al. Phys. Rev. B 87, 041108(R) (2013)
  !              ev93     Engel-Vosko, Phys. Rev. B 47, 13164 (1993)
  !
  ! NOTE ABOUT HSE: there are two slight deviations with respect to the HSE06
  ! functional as it is in Gaussian code (that is considered as the reference
  ! in the chemistry community):
  ! - The range separation in Gaussian is precisely 0.11 bohr^-1,
  !   instead of 0.106 bohr^-1 in this implementation
  ! - The gradient scaling relation is a bit more complicated
  !   [ see: TM Henderson, AF Izmaylov, G Scalmani, and GE Scuseria,
  !          J. Chem. Phys. 131, 044108 (2009) ]
  ! These two modifications accounts only for a 1e-5 Ha difference for a
  ! single He atom. Info by Fabien Bruneval.
  ! ------------------------------------------------------------------------
  !
  INTEGER, PARAMETER :: notset = -1
  !
  ! internal indices for exchange-correlation
  !    iexch: type of exchange
  !    icorr: type of correlation
  !    igcx:  type of gradient correction on exchange
  !    igcc:  type of gradient correction on correlation
  !    inlc:  type of non local correction on correlation
  !    imeta: type of meta-GGA
  INTEGER :: iexch = notset
  INTEGER :: icorr = notset
  INTEGER :: igcx  = notset
  INTEGER :: igcc  = notset
  INTEGER :: imeta = notset
  INTEGER :: inlc  = notset
  !
  ! is_libxc(i)==.TRUE. if the the i-th term of xc is from libxc
  LOGICAL :: is_libxc(6)
  !
  REAL(DP):: exx_fraction = 0.0_DP
  REAL(DP):: screening_parameter = 0.0_DP
  REAL(DP):: gau_parameter = 0.0_DP
  LOGICAL :: islda       = .FALSE.
  LOGICAL :: isgradient  = .FALSE.
  LOGICAL :: ismeta      = .FALSE.
  LOGICAL :: ishybrid    = .FALSE.
  LOGICAL :: isnonlocc   = .FALSE.
  LOGICAL :: exx_started = .FALSE.
  LOGICAL :: has_finite_size_correction = .FALSE.
  LOGICAL :: finite_size_cell_volume_set = .FALSE.
  REAL(DP):: finite_size_cell_volume = notset
  LOGICAL :: discard_input_dft = .FALSE.
  !
  INTEGER, PARAMETER :: nxc=8, ncc=10, ngcx=42, ngcc=12, nmeta=6, ncnl=6
  CHARACTER(LEN=4) :: exc, corr, gradx, gradc, meta, nonlocc
  DIMENSION :: exc(0:nxc), corr(0:ncc), gradx(0:ngcx), gradc(0:ngcc), &
               meta(0:nmeta), nonlocc(0:ncnl)
  !
  DATA exc  / 'NOX', 'SLA', 'SL1', 'RXC', 'OEP', 'HF', 'PB0X', 'B3LP', 'KZK' /
  DATA corr / 'NOC', 'PZ', 'VWN', 'LYP', 'PW', 'WIG', 'HL', 'OBZ', &
              'OBW', 'GL' , 'KZK' /
  !
  DATA gradx / 'NOGX', 'B88', 'GGX', 'PBX',  'RPB', 'HCTH', 'OPTX',&
               'xxxx', 'PB0X', 'B3LP','PSX', 'WCX', 'HSE', 'RW86', 'PBE', &
               'xxxx', 'C09X', 'SOX', 'xxxx', 'Q2DX', 'GAUP', 'PW86', 'B86B', &
               'OBK8', 'OB86', 'EVX', 'B86R', 'CX13', 'X3LP', &
               'CX0', 'R860', 'CX0P', 'AHCX', 'AHF2', &
               'AHPB', 'AHPS', 'CX14', 'CX15', 'BR0', 'CX16', 'C090', &
               'B86X', 'B88X'/
  !
  DATA gradc / 'NOGC', 'P86', 'GGC', 'BLYP', 'PBC', 'HCTH', 'NONE',&
               'B3LP', 'PSC', 'PBE', 'xxxx', 'xxxx', 'Q2DC' /
  !
  DATA meta  / 'NONE', 'TPSS', 'M06L', 'TB09', 'META', 'SCAN', 'SCA0' /
  !
  DATA nonlocc/'NONE', 'VDW1', 'VDW2', 'VV10', 'VDWX', 'VDWY', 'VDWZ' /

#if defined(__LIBXC)
  INTEGER :: libxc_major=0, libxc_minor=0, libxc_micro=0
  PUBLIC :: libxc_major, libxc_minor, libxc_micro, get_libxc_version
#endif
  !
CONTAINS
  !
  !-----------------------------------------------------------------------
  SUBROUTINE set_dft_from_name( dft_ )
    !-----------------------------------------------------------------------
    !! Translates a string containing the exchange-correlation name
    !! into internal indices iexch, icorr, igcx, igcc, inlc, imeta.
    !
    IMPLICIT NONE
    !
    CHARACTER(LEN=*), INTENT(IN) :: dft_
    INTEGER :: len, l, i
    CHARACTER(len=50):: dftout
    LOGICAL :: dft_defined = .FALSE.
    CHARACTER(LEN=1), EXTERNAL :: capital
    INTEGER ::  save_iexch, save_icorr, save_igcx, save_igcc, save_meta, save_inlc
#if defined(__LIBXC)
    INTEGER :: fkind
    TYPE(xc_f90_pointer_t) :: xc_func, xc_info
#endif
    !
    ! Exit if set to discard further input dft
    !
    IF ( discard_input_dft ) RETURN
    !
    ! save current status of XC indices
    !
    save_iexch = iexch
    save_icorr = icorr
    save_igcx  = igcx
    save_igcc  = igcc
    save_meta  = imeta
    save_inlc  = inlc
    !
    ! convert to uppercase
    !
    len = LEN_TRIM(dft_)
    dftout = ' '
    !
    DO l = 1, len
       dftout(l:l) = capital( dft_(l:l) )
    ENDDO
    !
    ! ----------------------------------------------
    ! FIRST WE CHECK ALL THE SHORT NAMES
    ! Note: comparison is done via exact matching
    ! ----------------------------------------------
    !
    SELECT CASE( TRIM(dftout) )
    ! special cases : PZ  (LDA is equivalent to PZ)
    CASE( 'PZ', 'LDA' )
       dft_defined = set_dft_values(1,1,0,0,0,0)
    ! speciale cases : PW ( LDA with PW correlation )
    CASE( 'PW' )
       dft_defined = set_dft_values(1,4,0,0,0,0)
    ! special cases : VWN-RPA
    CASE( 'VWN-RPA' )
       dft_defined = set_dft_values(1,11,0,0,0,0)
    ! special cases : OEP no GC part (nor LDA...) and no correlation by default
    CASE( 'OEP' )
       dft_defined = set_dft_values(4,0,0,0,0,0)
    !
    CASE( 'KLI' )
       dft_defined = set_dft_values(10,0,0,0,0,0)
    ! special cases : HF no GC part (nor LDA...) and no correlation by default
    CASE( 'HF' )
       dft_defined = set_dft_values(5,0,0,0,0,0)
    ! special case : PBE
    CASE( 'PBE' )
       dft_defined = set_dft_values(1,4,3,4,0,0)
    ! special case : B88
    CASE( 'B88' )
       dft_defined = set_dft_values(1,1,1,0,0,0)
    ! special case : BP = B88 + P86
    CASE( 'BP' )
       dft_defined = set_dft_values(1,1,1,1,0,0)
    ! special case : PW91 = GGX + GGC
    CASE( 'PW91' )
       dft_defined = set_dft_values(1,4,2,2,0,0)
    ! special case : revPBE
    CASE( 'REVPBE' )
       dft_defined = set_dft_values(1,4,4,4,0,0)
    ! special case : PBEsol
    CASE( 'PBESOL' )
       dft_defined = set_dft_values(1,4,10,8,0,0)
    ! special cases : BLYP (note, BLYP=>B88)
    CASE( 'BLYP' )
       dft_defined = set_dft_values(1,3,1,3,0,0)
    ! Special case optB88
    CASE( 'OPTBK88' )
       dft_defined = set_dft_values(1,4,23,1,0,0)
    ! Special case optB86b
    CASE( 'OPTB86B' )
       dft_defined = set_dft_values(1,4,24,1,0,0)
    ! special case : PBC  = PW + PBC
    CASE( 'PBC' )
       dft_defined = set_dft_values(1,4,0,4,0,0)
    ! special case : HCTH
    CASE( 'HCTH' )
       dft_defined = set_dft_values(0,0,5,5,0,0)
       CALL errore( 'set_dft_from_name', 'HCTH yields suspicious results', 1 )
    ! special case : OLYP = OPTX + LYP
    CASE( 'OLYP' )
       dft_defined = set_dft_values(0,3,6,3,0,0)
       CALL errore( 'set_dft_from_name', 'OLYP yields suspicious results', 1 )
    ! special case : Wu-Cohen
    CASE( 'WC' )
       dft_defined = set_dft_values(1,4,11,4,0,0)
    ! special case : PW86PBE
    CASE( 'PW86PBE' )
       dft_defined = set_dft_values(1,4,21,4,0,0)
    ! special case : B86BPBE
    CASE( 'B86BPBE' )
       dft_defined = set_dft_values(1,4,22,4,0,0)
    ! special case : PBEQ2D
    CASE( 'PBEQ2D', 'Q2D' )
       dft_defined = set_dft_values(1,4,19,12,0,0)
    ! special case : SOGGA = SOX + PBEc
    CASE( 'SOGGA' )
       dft_defined = set_dft_values(1,4,17,4,0,0)
    ! special case : Engel-Vosko
    CASE( 'EV93' )
       dft_defined = set_dft_values(1,4,25,0,0,0)
    ! special case : RPBE
    CASE( 'RPBE' )
       CALL errore( 'set_dft_from_name', &
                    'RPBE (Hammer-Hansen-Norskov) not implemented (revPBE is)', 1 )
    ! special case : PBE0
    CASE( 'PBE0' )
       dft_defined = set_dft_values(6,4,8,4,0,0)
    ! special case : B86BPBEX
    CASE( 'B86BPBEX' )
       dft_defined = set_dft_values(6,4,41,4,0,0)
    !
    CASE( 'BHAHLYP', 'BHANDHLYP' )
       dft_defined = set_dft_values(6,4,42,3,0,0)
    ! special case : HSE
    CASE( 'HSE' )
       dft_defined = set_dft_values(1,4,12,4,0,0)
    ! special case : GAUPBE
    CASE( 'GAUP', 'GAUPBE' )
       dft_defined = set_dft_values(1,4,20,4,0,0)
    ! Special case vdW-DF
    CASE( 'VDW-DF' )
       dft_defined = set_dft_values(1,4,4,0,1,0)
    ! Special case vdW-DF2
    CASE( 'VDW-DF2' )
       dft_defined = set_dft_values(1,4,13,0,2,0)
    ! Special case vdW-DF with C09 exchange
    CASE( 'VDW-DF-C09' )
       dft_defined = set_dft_values(1,4,16,0,1,0)
    ! Special case vdW-DF2 with C09 exchange
    CASE( 'VDW-DF2-C09' )
       dft_defined = set_dft_values(1,4,16,0,2,0)
    ! Special case vdW-DF-obk8, or vdW-DF + optB88
    CASE( 'VDW-DF-OBK8' )
       dft_defined = set_dft_values(1,4,23,0,1,0)
    ! Special case vdW-DF-ob86, or vdW-DF + optB86
    CASE( 'VDW-DF-OB86' )
       dft_defined = set_dft_values(1,4,24,0,1,0)
    ! Special case vdW-DF2 with B86R
    CASE( 'VDW-DF2-B86R' )
       dft_defined = set_dft_values(1,4,26,0,2,0)
    ! Special case vdW-DF-CX
    CASE( 'VDW-DF-CX' )
       dft_defined = set_dft_values(1,4,27,0,1,0)
    ! Special case vdW-DF-CX0
    CASE( 'VDW-DF-CX0' )
       dft_defined = set_dft_values(6,4,29,0,1,0)
    ! Special case vdW-DF-CX0P
    CASE( 'VDW-DF-CX0P' )
       dft_defined = set_dft_values(6,4,31,0,1,0)
    ! Special case vdW-DF2-0
    CASE( 'VDW-DF2-0' )
       dft_defined = set_dft_values(6,4,30,0,2,0)
    ! Special case vdW-DF2-BR0
    CASE( 'VDW-DF2-BR0' )
       dft_defined = set_dft_values(6,4,38,0,2,0)
    ! Special case vdW-DF-C090
    CASE( 'VDW-DF-C090' )
       dft_defined = set_dft_values(6,4,40,0,1,0)
    ! Special case rVV10
    CASE( 'RVV10' )
       dft_defined = set_dft_values(1,4,13,4,3,0)
    ! Special case rVV10+scan
    CASE( 'RVV10-SCAN' )
       dft_defined = set_dft_values(0,0,0,0,3,5)
    ! special case : B3LYP hybrid
    CASE( 'B3LYP' )
       dft_defined = set_dft_values(7,12,9,7,0,0)
    ! special case : B3LYP-VWN-1-RPA hybrid
    CASE( 'B3LYP-V1R' )
       dft_defined = set_dft_values(7,13,9,7,0,0)
    ! special case : X3LYP hybrid
    CASE( 'X3LYP' )
       dft_defined = set_dft_values(9,14,28,13,0,0)
    ! special case : TPSS meta-GGA Exc
    CASE( 'TPSS' )
       dft_defined = set_dft_values(1,4,7,6,0,1)
    ! special case : M06L Meta GGA
    CASE( 'M06L' )
       dft_defined = set_dft_values(0,0,0,0,0,2)
    ! special case : TB09 meta-GGA Exc
    CASE( 'TB09' )
       dft_defined = set_dft_values(0,0,0,0,0,3)
    ! special case : SCAN Meta GGA
    CASE( 'SCAN' )
       dft_defined = set_dft_values(0,0,0,0,0,5)
    ! special case : SCAN0
    CASE( 'SCAN0' )
       dft_defined = set_dft_values(0,0,0,0,0,6)
    ! special case : PZ/LDA + null meta-GGA
    CASE( 'PZ+META', 'LDA+META' )
       dft_defined = set_dft_values(1,1,0,0,0,4)
    ! special case : PBE + null meta-GGA
    CASE( 'PBE+META' )
       dft_defined = set_dft_values(1,4,3,4,0,4)
    !
    CASE( 'REV-VDW-DF2' )
       CALL errore( 'set_dft_from_name', 'obsolete XC label, use VDW-DF2-B86R', 1 )
    !
    CASE( 'VDW-DF3' )
       CALL errore( 'set_dft_from_name', 'obsolete XC label, use VDW-DF-OBK8', 1 )
    !
    CASE( 'VDW-DF4', 'OPTB86B-VDW' )
       CALL errore( 'set_dft_from_name', 'obsolete XC label, use VDW-DF-OB86', 1 )
    ! Special case vdW-DF-X
    CASE( 'VDW-DF-X' )
       CALL errore( 'set_dft_from_name', 'functional not yet implemented', 1 )
    ! Special case vdW-DF-Y
    CASE( 'VDW-DF-Y' )
       CALL errore( 'set_dft_from_name', 'functional not yet implemented', 1 )
    ! Special case vdW-DF-Z
    CASE( 'VDW-DF-Z' )
       CALL errore( 'set_dft_from_name', 'functional not yet implemented', 1 )
    ! Case for old RRKJ format, containing indices instead of label
    CASE DEFAULT
       IF ('INDEX:' ==  dftout(1:6)) THEN
          READ( dftout(7:18), '(6i2)') iexch, icorr, igcx, igcc, inlc, imeta
              dft_defined = set_dft_values(iexch, icorr, igcx, igcc, inlc, imeta)
              dftout = exc (iexch) //'-'//corr (icorr) //'-'//gradx (igcx) //'-' &
              &//gradc (igcc) //'-'// nonlocc(inlc)
       ENDIF
    END SELECT
    !
    !
    !----------------------------------------------------------------
    ! If the DFT was not yet defined, check every part of the string
    !----------------------------------------------------------------
    !
    IF (.NOT. dft_defined) THEN
       !
       iexch = matching( 1, dftout, nxc,   exc,     is_libxc(1) )
       icorr = matching( 2, dftout, ncc,   corr,    is_libxc(2) )
       igcx  = matching( 3, dftout, ngcx,  gradx,   is_libxc(3) )
       igcc  = matching( 4, dftout, ngcc,  gradc,   is_libxc(4) )       
       imeta = matching( 5, dftout, nmeta, meta,    is_libxc(5) )
       inlc  = matching( 6, dftout, ncnl,  nonlocc, is_libxc(6) )       
       !
#if defined(__LIBXC)
       fkind = -100
       IF (is_libxc(1)) THEN
         CALL xc_f90_func_init( xc_func, xc_info, iexch, 1 )
         fkind = xc_f90_info_kind( xc_info )
         CALL xc_f90_func_end( xc_func )
       ENDIF
       !
       IF (icorr/=notset .AND. fkind==XC_EXCHANGE_CORRELATION)  &
          CALL errore( 'set_dft_from_name', 'An EXCHANGE+CORRELATION functional has &
                       &been found together with a correlation one', 2 )
       !
       fkind = -100
       IF (is_libxc(3)) THEN
         CALL xc_f90_func_init( xc_func, xc_info, igcx, 1 )
         fkind = xc_f90_info_kind( xc_info )
         CALL xc_f90_func_end( xc_func )
       ENDIF
       !
       IF (icorr/=notset .AND. fkind==XC_EXCHANGE_CORRELATION)  &
          CALL errore( 'set_dft_from_name', 'An EXCHANGE+CORRELATION functional has &
                       &been found together with a correlation one', 3 )
       !
       IF (ANY(is_libxc(1:2)) .AND. ANY(is_libxc(3:4))) &
          CALL errore( 'set_dft_from_name', 'An LDA functional has been found, but &
                       &libxc GGA functionals already include the LDA part)', 4 )
#endif
       !
    ENDIF
    !
    !----------------------------------------------------------------
    ! Last check
    ! No more defaults, the code exits if the dft is not defined
    !----------------------------------------------------------------
    !
    ! Back compatibility - TO BE REMOVED
    !
    IF (igcx == 14) igcx = 3 ! PBE -> PBX
    IF (igcc ==  9) igcc = 4 ! PBE -> PBC
    !
    IF (igcx == 6) CALL infomsg( 'set_dft_from_name', 'OPTX untested! please test' )
    !
    ! check for unrecognized labels
    !
    IF ( iexch<=0 .AND. icorr<=0 .AND. igcx<=0 .AND. igcc<=0 .AND. imeta<=0 ) THEN
       IF ( inlc <= 0 .AND. TRIM(dftout) /= 'NOX-NOC') THEN
          CALL errore( 'set_dft_from_name', TRIM(dftout)//': unrecognized dft', 1 )
       ELSE
          ! if inlc is the only nonzero index the label is likely wrong
          CALL errore( 'set_dft_from_name', TRIM(dftout)//': strange dft, please check', inlc )
       ENDIF
    ENDIF
    !
    ! Fill variables and exit
    !
    dft = dftout
    !
    !dft_longname = exc (iexch) //'-'//corr (icorr) //'-'//gradx (igcx) //'-' &
    !     &//gradc (igcc) //'-'// nonlocc(inlc)
    !
    CALL set_auxiliary_flags
    !
    ! check dft has not been previously set differently
    !
    IF (save_iexch /= notset .AND. save_iexch /= iexch) THEN
       WRITE(stdout,*) iexch, save_iexch
       CALL errore( 'set_dft_from_name', ' conflicting values for iexch', 1 )
    ENDIF
    IF (save_icorr /= notset .AND. save_icorr /= icorr) THEN
       WRITE(stdout,*) icorr, save_icorr
       CALL errore( 'set_dft_from_name', ' conflicting values for icorr', 1 )
    ENDIF
    IF (save_igcx /= notset  .AND. save_igcx /= igcx)   THEN
       WRITE(stdout,*) igcx, save_igcx
       CALL errore( 'set_dft_from_name', ' conflicting values for igcx',  1 )
    ENDIF
    IF (save_igcc /= notset  .AND. save_igcc /= igcc)   THEN
       WRITE (stdout,*) igcc, save_igcc
       CALL errore( 'set_dft_from_name', ' conflicting values for igcc',  1 )
    ENDIF
    IF (save_meta /= notset  .AND. save_meta /= imeta)  THEN
       WRITE (stdout,*) inlc, save_meta
       CALL errore( 'set_dft_from_name', ' conflicting values for imeta', 1 )
    ENDIF
    IF (save_inlc /= notset  .AND. save_inlc /= inlc)   THEN
       WRITE (stdout,*) inlc, save_inlc
       CALL errore( 'set_dft_from_name', ' conflicting values for inlc',  1 )
    ENDIF
    !
    CALL init_xc( 'ALL' )
    !
    RETURN
    !
  END SUBROUTINE set_dft_from_name
  !
  !
  !-----------------------------------------------------------------
  FUNCTION matching( fslot, dft, n, name, its_libxc )
    !------------------------------------------------------------
    !
    IMPLICIT NONE
    !
    INTEGER :: matching
    INTEGER, INTENT(IN) :: fslot
    INTEGER, INTENT(IN):: n
    LOGICAL, INTENT(OUT) :: its_libxc
    CHARACTER(LEN=*), INTENT(IN):: name(0:n)
    CHARACTER(LEN=*), INTENT(IN):: dft
    LOGICAL, EXTERNAL :: matches
    INTEGER :: i, ii, j, length
    INTEGER :: family, fkind
#if defined(__LIBXC)
    TYPE(xc_f90_pointer_t) :: xc_func, xc_info
#endif
    !
    its_libxc = .FALSE.
    matching = notset
    !
    IF (matching == notset) THEN
       !
       length = LEN( dft )
       !
       ii = 0
       !
       DO i = 1, length
          ii = ii+1
          IF (ii == length-1) EXIT
          !
          IF (dft(ii:ii+2) .EQ. 'XC_') THEN
             DO j = 1, length-ii-2
               IF (dft(ii+2+j:ii+2+j) .EQ. ' ') EXIT
             ENDDO
             !
#if defined(__LIBXC)
             matching = xc_f90_functional_get_number( dft(ii:ii+1+j) )
             !
             CALL xc_f90_func_init( xc_func, xc_info, matching, 1 )
             family = xc_f90_info_family( xc_info )
             fkind  = xc_f90_info_kind( xc_info )
             CALL xc_f90_func_end( xc_func )
             !
             IF ( slot_match_libxc( fslot, family, fkind ) ) THEN
               its_libxc = .TRUE.
               RETURN
             ENDIF
#else
             CALL errore( 'matching', 'A libxc functional has been found, &
                                      &but libxc library is not active', 1 )
#endif
             ii = ii+2+j
          ENDIF
          !
       ENDDO
       !
       matching = notset
       !
    ENDIF
    !
    DO i = n, 0, -1
       IF ( matches(name(i), TRIM(dft)) ) THEN
          IF ( matching == notset ) THEN
             ! write(*, '("matches",i2,2X,A,2X,A)') i, name(i), trim(dft)
             matching = i
          ELSE
             WRITE(*, '(2(2X,i2,2X,A))') i, TRIM(name(i)), &
                                     matching, TRIM(name(matching))
             CALL errore( 'set_dft', 'two conflicting matching values', 2 )
          ENDIF
       ENDIF
    ENDDO
    !
    IF (matching == notset) matching = 0
    !
  END FUNCTION matching
  !
  !
  !----------------------------------------------------------------------------
  FUNCTION slot_match_libxc( fslot, family, fkind )
    !-------------------------------------------------------------------------
    !
    IMPLICIT NONE
    ! 
    LOGICAL :: slot_match_libxc
    INTEGER, INTENT(IN) :: fslot, family, fkind
    !
#if defined(__LIBXC)
    slot_match_libxc=.TRUE.
    !
    SELECT CASE( fslot )
    CASE( 1 )
       IF (family==XC_FAMILY_LDA .AND. fkind==XC_EXCHANGE) RETURN
       IF (family==XC_FAMILY_LDA .AND. fkind==XC_EXCHANGE_CORRELATION) RETURN
    CASE( 2 )
       IF (family==XC_FAMILY_LDA .AND. fkind==XC_CORRELATION) RETURN
    CASE( 3 )
       IF (family==XC_FAMILY_GGA     .AND. fkind==XC_EXCHANGE) RETURN
       IF (family==XC_FAMILY_GGA     .AND. fkind==XC_EXCHANGE_CORRELATION) RETURN
       IF (family==XC_FAMILY_HYB_GGA .AND. fkind==XC_EXCHANGE) RETURN
       IF (family==XC_FAMILY_HYB_GGA .AND. fkind==XC_EXCHANGE_CORRELATION) RETURN
    CASE( 4 )
       IF (family==XC_FAMILY_GGA .AND. fkind==XC_CORRELATION) RETURN
    END SELECT
    !
#endif
    slot_match_libxc=.FALSE.
    !
    RETURN
    !
  END FUNCTION
  !
  !
  !-----------------------------------------------------------------------
  SUBROUTINE set_auxiliary_flags
    !-----------------------------------------------------------------------
    !! Set logical flags describing the complexity of the xc functional
    !! define the fraction of exact exchange used by hybrid fuctionals.
    !
    isnonlocc = (inlc > 0)
    ismeta    = (imeta > 0)
    isgradient= (igcx > 0) .OR.  (igcc > 0)  .OR. ismeta .OR. isnonlocc
    islda     = (iexch> 0) .AND. (icorr > 0) .AND. .NOT. isgradient
    ! PBE0/DF0
    IF ( iexch==6 .OR.  igcx == 8 ) exx_fraction = 0.25_DP
    ! CX0P
    IF ( iexch==6 .AND. igcx ==31 ) exx_fraction = 0.20_DP
    ! B86BPBEX
    IF ( iexch==6 .AND. igcx ==41 ) exx_fraction = 0.25_DP
    ! BHANDHLYP
    IF ( iexch==6 .AND. igcx ==42 ) exx_fraction = 0.50_DP
    ! HSE
    IF ( igcx ==12 ) THEN
       exx_fraction = 0.25_DP
       screening_parameter = 0.106_DP
    ENDIF
    ! gau-pbe
    IF ( igcx ==20 ) THEN
       exx_fraction = 0.24_DP
       gau_parameter = 0.150_DP
    ENDIF
    ! HF or OEP
    IF ( iexch==4 .OR. iexch==5 ) exx_fraction = 1.0_DP
    ! B3LYP or B3LYP-VWN-1-RPA
    IF ( iexch == 7 ) exx_fraction = 0.2_DP
    ! X3LYP
    IF ( iexch == 9 ) exx_fraction = 0.218_DP
    !
    ishybrid = ( exx_fraction /= 0.0_DP )
    !
    has_finite_size_correction = ( iexch==8 .OR. icorr==10)
    !
    RETURN
    !
  END SUBROUTINE set_auxiliary_flags
  !
  !
  !-----------------------------------------------------------------------
  LOGICAL FUNCTION set_dft_values( i1, i2, i3, i4, i5, i6 )
    !-----------------------------------------------------------------------
    !
    IMPLICIT NONE
    !
    INTEGER :: i1, i2, i3, i4, i5, i6
    !
    iexch = i1
    icorr = i2
    igcx  = i3
    igcc  = i4
    inlc  = i5
    imeta = i6
    !
    set_dft_values = .TRUE.
    !
    RETURN
    !
  END FUNCTION set_dft_values
  !
  !
  !-----------------------------------------------------------------------
  SUBROUTINE enforce_input_dft( dft_, nomsg )
    !---------------------------------------------------------------------
    !! Translates a string containing the exchange-correlation name
    !! into internal indices and force any subsequent call to 
    !! \(\textrm{set_dft_from_name}\) to return without changing them.
    !
    IMPLICIT NONE
    !
    CHARACTER(LEN=*), INTENT(IN) :: dft_
    LOGICAL, INTENT(IN), OPTIONAL :: nomsg
    !
    CALL set_dft_from_name( dft_ )
    IF (dft == 'not set') CALL errore( 'enforce_input_dft', 'cannot fix unset dft', 1 )
    discard_input_dft = .TRUE.
    !
    IF ( PRESENT(nomsg) ) RETURN
    !
    WRITE(stdout,'(/,5x,a)') "IMPORTANT: XC functional enforced from input :"
    CALL write_dft_name
    WRITE(stdout,'(5x,a)') "Any further DFT definition will be discarded"
    WRITE(stdout,'(5x,a/)') "Please, verify this is what you really want"
    !
    RETURN
    !
  END SUBROUTINE enforce_input_dft
  !
  !
  !-----------------------------------------------------------------------
  SUBROUTINE enforce_dft_exxrpa( )
    !---------------------------------------------------------------------
    !
    IMPLICIT NONE
    !
    !character(len=*), intent(in) :: dft_
    !logical, intent(in), optional :: nomsg
    !
    iexch = 0; icorr = 0; igcx = 0; igcc = 0
    exx_fraction = 1.0_DP
    ishybrid = ( exx_fraction /= 0.0_DP )
    !
    WRITE(stdout,'(/,5x,a)') "XC functional enforced to be EXXRPA"
    CALL write_dft_name
    WRITE(stdout,'(5x,a)') "!!! Any further DFT definition will be discarded"
    WRITE(stdout,'(5x,a/)') "!!! Please, verify this is what you really want !"
    !
    RETURN
    !
  END SUBROUTINE enforce_dft_exxrpa
  !
  !
  !-----------------------------------------------------------------------
  SUBROUTINE init_dft_exxrpa( )
    !-----------------------------------------------------------------------
    !
    IMPLICIT NONE
    !
    exx_fraction = 1.0_DP
    ishybrid = ( exx_fraction /= 0.0_DP )
    !
    WRITE(stdout,'(/,5x,a)') "Only exx_fraction is set to 1.d0"
    WRITE(stdout,'(5x,a)') "XC functional still not changed"
    !
    CALL write_dft_name
    !
    RETURN
    !
  END SUBROUTINE init_dft_exxrpa
  !
  !
  !-----------------------------------------------------------------------
  SUBROUTINE start_exx
     IF (.NOT. ishybrid) &
        CALL errore( 'start_exx', 'dft is not hybrid, wrong call', 1 )
     exx_started = .TRUE.
     CALL init_xc( 'ALL' )
  END SUBROUTINE start_exx
  !-----------------------------------------------------------------------
  SUBROUTINE stop_exx
     IF (.NOT. ishybrid) &
        CALL errore( 'stop_exx', 'dft is not hybrid, wrong call', 1 )
     exx_started = .FALSE.
     CALL init_xc( 'ALL' )
  END SUBROUTINE stop_exx
  !-----------------------------------------------------------------------
  SUBROUTINE dft_force_hybrid( request )
    LOGICAL,OPTIONAL,INTENT(INOUT) :: request
    LOGICAL :: aux
    IF (PRESENT(request)) THEN
      aux = ishybrid
      ishybrid = request
      request = aux
    ELSE
      ishybrid= .TRUE.
    ENDIF
  END SUBROUTINE dft_force_hybrid
  !-----------------------------------------------------------------------
  FUNCTION exx_is_active()
     LOGICAL exx_is_active
     exx_is_active = exx_started
  END FUNCTION exx_is_active
  !-----------------------------------------------------------------------
  SUBROUTINE set_exx_fraction( exxf_ )
     IMPLICIT NONE
     REAL(DP) :: exxf_
     exx_fraction = exxf_
     WRITE( stdout,'(5x,a,f6.2)') 'EXX fraction changed: ', exx_fraction
  END SUBROUTINE set_exx_fraction
  !---------------------------------------------------------------------
  SUBROUTINE set_screening_parameter( scrparm_ )
     IMPLICIT NONE
     REAL(DP):: scrparm_
     screening_parameter = scrparm_
     WRITE( stdout,'(5x,a,f12.7)') 'EXX Screening parameter changed: ', &
          & screening_parameter
  END SUBROUTINE set_screening_parameter
  !----------------------------------------------------------------------
  FUNCTION get_screening_parameter()
     REAL(DP):: get_screening_parameter
     get_screening_parameter = screening_parameter
     RETURN
  END FUNCTION get_screening_parameter
  !---------------------------------------------------------------------
  SUBROUTINE set_gau_parameter( gauparm_ )
     IMPLICIT NONE
     REAL(DP):: gauparm_
     gau_parameter = gauparm_
     WRITE( stdout,'(5x,a,f12.7)') 'EXX Gau parameter changed: ', &
          & gau_parameter
  END SUBROUTINE set_gau_parameter
  !----------------------------------------------------------------------
  FUNCTION get_gau_parameter()
     REAL(DP):: get_gau_parameter
     get_gau_parameter = gau_parameter
     RETURN
  END FUNCTION get_gau_parameter
  !-----------------------------------------------------------------------
  FUNCTION get_iexch()
     INTEGER get_iexch
     get_iexch = iexch
     RETURN
  END FUNCTION get_iexch
  !-----------------------------------------------------------------------
  FUNCTION get_icorr()
     INTEGER get_icorr
     get_icorr = icorr
     RETURN
  END FUNCTION get_icorr
  !-----------------------------------------------------------------------
  FUNCTION get_igcx()
     INTEGER get_igcx
     get_igcx = igcx
     RETURN
  END FUNCTION get_igcx
  !-----------------------------------------------------------------------
  FUNCTION get_igcc()
     INTEGER get_igcc
     get_igcc = igcc
     RETURN
  END FUNCTION get_igcc
  !-----------------------------------------------------------------------
  FUNCTION get_meta()
     INTEGER get_meta
     get_meta = imeta
     RETURN
  END FUNCTION get_meta
  !-----------------------------------------------------------------------
  FUNCTION get_inlc()
     INTEGER get_inlc
     get_inlc = inlc
     RETURN
  END FUNCTION get_inlc
  !-----------------------------------------------------------------------
  FUNCTION get_nonlocc_name()
     CHARACTER(10) get_nonlocc_name
     get_nonlocc_name = TRIM(nonlocc(inlc))
     RETURN
  END FUNCTION get_nonlocc_name
  !-----------------------------------------------------------------------
  FUNCTION dft_is_nonlocc()
     LOGICAL :: dft_is_nonlocc
     dft_is_nonlocc = isnonlocc
     RETURN
  END FUNCTION dft_is_nonlocc
  !-----------------------------------------------------------------------
  FUNCTION get_exx_fraction()
     REAL(DP) :: get_exx_fraction
#if defined(__LIBXC)
     INTEGER :: family
     TYPE(xc_f90_pointer_t) :: xc_func, xc_info
     !
     IF ( is_libxc(3) ) THEN
        CALL xc_f90_func_init( xc_func, xc_info, igcx, 1 )  
        family = xc_f90_info_family( xc_info )
        IF (family == XC_FAMILY_HYB_GGA) CALL xc_f90_hyb_exx_coef( xc_func, exx_fraction )
        CALL xc_f90_func_end( xc_func )
     ENDIF
#endif
     get_exx_fraction = exx_fraction
     RETURN
  END FUNCTION get_exx_fraction
  !-----------------------------------------------------------------------
  FUNCTION get_dft_name()
     CHARACTER(LEN=25) :: get_dft_name
     get_dft_name = dft
     RETURN
  END FUNCTION get_dft_name
  !-----------------------------------------------------------------------
  FUNCTION dft_is_gradient()
     LOGICAL :: dft_is_gradient
     dft_is_gradient = isgradient
     RETURN
  END FUNCTION dft_is_gradient
  !-----------------------------------------------------------------------
  FUNCTION dft_is_meta()
     LOGICAL :: dft_is_meta
     dft_is_meta = ismeta
     RETURN
  END FUNCTION dft_is_meta
  !-----------------------------------------------------------------------
  FUNCTION dft_is_hybrid()
     LOGICAL :: dft_is_hybrid
     dft_is_hybrid = ishybrid
     RETURN
  END FUNCTION dft_is_hybrid
  !-----------------------------------------------------------------------
  FUNCTION igcc_is_lyp()
     LOGICAL :: igcc_is_lyp
     igcc_is_lyp = (get_igcc()==3 .OR. get_igcc()==7 .OR. get_igcc()==13)
     RETURN
  END FUNCTION igcc_is_lyp
  !-----------------------------------------------------------------------
  FUNCTION dft_has_finite_size_correction()
     LOGICAL :: dft_has_finite_size_correction
     dft_has_finite_size_correction = has_finite_size_correction
     RETURN
  END FUNCTION  dft_has_finite_size_correction
  !-----------------------------------------------------------------------
  SUBROUTINE set_finite_size_volume( volume )
     REAL, INTENT(IN) :: volume
     IF (.NOT. has_finite_size_correction) &
         CALL errore( 'set_finite_size_volume', &
                      'dft w/o finite_size_correction, wrong call', 1 )
     IF (volume <= 0.d0) &
         CALL errore( 'set_finite_size_volume', &
                      'volume is not positive, check omega and/or nk1,nk2,nk3', 1 )
     finite_size_cell_volume = volume
     finite_size_cell_volume_set = .TRUE.
  END SUBROUTINE set_finite_size_volume
  !-----------------------------------------------------------------------
  !
  SUBROUTINE get_finite_size_cell_volume( is_present, volume )
     LOGICAL, INTENT(OUT) :: is_present
     REAL(DP), INTENT(OUT) :: volume
     is_present = finite_size_cell_volume_set
     volume = -1.d0
     IF (is_present) volume = finite_size_cell_volume
  END SUBROUTINE get_finite_size_cell_volume
  !
  !-----------------------------------------------------------------------
  SUBROUTINE set_dft_from_indices( iexch_, icorr_, igcx_, igcc_, inlc_ )
     INTEGER :: iexch_, icorr_, igcx_, igcc_, inlc_
     IF ( discard_input_dft ) RETURN
     IF (iexch == notset) iexch = iexch_
     IF (iexch /= iexch_) THEN
        write (stdout,*) iexch, iexch_
        CALL errore( 'set_dft', ' conflicting values for iexch', 1 )
     ENDIF
     IF (icorr == notset) icorr = icorr_
     IF (icorr /= icorr_) THEN
        write (stdout,*) icorr, icorr_
        CALL errore( 'set_dft', ' conflicting values for icorr', 1 )
     ENDIF
     IF (igcx  == notset) igcx = igcx_
     IF (igcx /= igcx_) THEN
        write (stdout,*) igcx, igcx_
        CALL errore( 'set_dft', ' conflicting values for igcx', 1 )
     ENDIF
     IF (igcc  == notset) igcc = igcc_
     IF (igcc /= igcc_) THEN
        write (stdout,*) igcc, igcc_
        CALL errore( 'set_dft', ' conflicting values for igcc', 1 )
     ENDIF
     IF (inlc  == notset) inlc = inlc_
     IF (inlc /= inlc_) THEN
        write (stdout,*) inlc, inlc_
        CALL errore( 'set_dft', ' conflicting values for inlc', 1 )
     ENDIF
     dft = exc (iexch) //'-'//corr (icorr) //'-'//gradx (igcx) //'-' &
           &//gradc (igcc)//'-'//nonlocc (inlc)
     ! WRITE( stdout,'(a)') dft
     CALL set_auxiliary_flags
     RETURN
  END SUBROUTINE set_dft_from_indices
  !
  !
  !-------------------------------------------------------------------------
  FUNCTION get_dft_short()
    !---------------------------------------------------------------------
    !
    CHARACTER(LEN=12) :: get_dft_short
    CHARACTER(LEN=12) :: shortname
    !
    shortname = 'no shortname'
    !
    IF ( iexch==1 .AND. igcx==0 .AND. igcc==0) THEN
       shortname = TRIM(corr(icorr))
    ELSEIF (iexch==4 .AND. icorr== 0 .AND. igcx==0 .AND. igcc== 0) THEN
       shortname = 'OEP'
    ELSEIF (iexch==1 .AND. icorr==11 .AND. igcx==0 .AND. igcc== 0) THEN
       shortname = 'VWN-RPA'
    ELSEIF (iexch==1 .AND. icorr== 3 .AND. igcx==1 .AND. igcc== 3) THEN
       shortname = 'BLYP'
    ELSEIF (iexch==1 .AND. icorr== 1 .AND. igcx==1 .AND. igcc== 0) THEN
       shortname = 'B88'
    ELSEIF (iexch==1 .AND. icorr== 1 .AND. igcx==1 .AND. igcc== 1) THEN
       shortname = 'BP'
    ELSEIF (iexch==1 .AND. icorr== 4 .AND. igcx==2 .AND. igcc== 2) THEN
       shortname = 'PW91'
    ELSEIF (iexch==1 .AND. icorr== 4 .AND. igcx==3 .AND. igcc== 4) THEN
       shortname = 'PBE'
    ELSEIF (iexch==6 .AND. icorr== 4 .AND. igcx==8 .AND. igcc== 4) THEN
       shortname = 'PBE0'
    ELSEIF (iexch==6 .AND. icorr== 4 .AND. igcx==41.AND. igcc== 4) THEN
       shortname = 'B86BPBEX'
    ELSEIF (iexch==6 .AND. icorr==4  .AND. igcx==42.AND. igcc== 3) THEN
       shortname = 'BHANDHLYP'
    ELSEIF (iexch==1 .AND. icorr==4  .AND. igcx==4 .AND. igcc== 4) THEN
       shortname = 'revPBE'
    ELSEIF (iexch==1 .AND. icorr==4  .AND. igcx==10.AND. igcc== 8) THEN
       shortname = 'PBESOL'
    ELSEIF (iexch==1 .AND. icorr==4  .AND. igcx==19.AND. igcc==12) THEN
       shortname = 'Q2D'
    ELSEIF (iexch==1 .AND. icorr==4  .AND. igcx==12.AND. igcc== 4) THEN
       shortname = 'HSE'
    ELSEIF (iexch==1 .AND. icorr==4  .AND. igcx==20.AND. igcc== 4) THEN
       shortname = 'GAUPBE'
    ELSEIF (iexch==1 .AND. icorr==4  .AND. igcx==21.AND. igcc== 4) THEN
       shortname = 'PW86PBE'
    ELSEIF (iexch==1 .AND. icorr==4  .AND. igcx==22.AND. igcc== 4) THEN
       shortname = 'B86BPBE'
    ELSEIF (iexch==1 .AND. icorr==4  .AND. igcx==11.AND. igcc== 4) THEN
       shortname = 'WC'
    ELSEIF (iexch==7 .AND. icorr==12 .AND. igcx==9 .AND. igcc== 7) THEN
       shortname = 'B3LYP'
    ELSEIF (iexch==7 .AND. icorr==13 .AND. igcx==9 .AND. igcc== 7) THEN
       shortname = 'B3LYP-V1R'
    ELSEIF (iexch==9 .AND. icorr==14 .AND. igcx==28.AND. igcc==13) THEN
       shortname = 'X3LYP'
    ELSEIF (iexch==0 .AND. icorr==3  .AND. igcx==6 .AND. igcc== 3) THEN
       shortname = 'OLYP'
    ELSEIF (iexch==1 .AND. icorr==4  .AND. igcx==17.AND. igcc== 4) THEN
       shortname = 'SOGGA'
    ELSEIF (iexch==1 .AND. icorr==4  .AND. igcx==23.AND. igcc== 1) THEN
       shortname = 'OPTBK88'
    ELSEIF (iexch==1 .AND. icorr==4  .AND. igcx==24.AND. igcc== 1) THEN
       shortname = 'OPTB86B'
    ELSEIF (iexch==1 .AND. icorr==4  .AND. igcx==25.AND. igcc== 0) THEN
       shortname = 'EV93'
    ELSEIF (iexch==5 .AND. icorr==0  .AND. igcx==0 .AND. igcc== 0) THEN
       shortname = 'HF'
    ENDIF
    !
    IF (imeta==1) THEN
       shortname = 'TPSS'
    ELSEIF (imeta == 2) THEN
       shortname = 'M06L'
    ELSEIF (imeta == 3) THEN
       shortname = 'TB09'
    ELSEIF (imeta == 4) THEN
       IF ( iexch == 1 .AND. icorr == 1) THEN
          shortname = 'PZ+META'
       ELSEIF (iexch==1 .AND. icorr==4 .AND. igcx==3 .AND. igcc==4) THEN
          shortname = 'PBE+META'
       ENDIF
    ELSEIF (imeta == 5 ) THEN
       shortname = 'SCAN'
    ELSEIF (imeta == 6 ) THEN
       shortname = 'SCAN0'
    ENDIF
    !
    IF (inlc==1) THEN
       IF (iexch==1 .AND. icorr==4 .AND. igcx==4 .AND. igcc==0) THEN
          shortname = 'VDW-DF'
       ELSEIF (iexch==1 .AND. icorr==4 .AND. igcx==27 .AND. igcc==0) THEN
          shortname = 'VDW-DF-CX'
       ELSEIF (iexch==6 .AND. icorr==4 .AND. igcx==29 .AND. igcc==0) THEN
          shortname = 'VDW-DF-CX0'
       ELSEIF (iexch==6 .AND. icorr==4 .AND. igcx==31 .AND. igcc==0) THEN
          shortname = 'VDW-DF-CX0P'
       ELSEIF (iexch==1 .AND. icorr==4 .AND. igcx==16 .AND. igcc==0) THEN
          shortname = 'VDW-DF-C09'
       ELSEIF (iexch==1 .AND. icorr==4 .AND. igcx==24 .AND. igcc==0) THEN
          shortname = 'VDW-DF-OB86'
       ELSEIF (iexch==1 .AND. icorr==4 .AND. igcx==23 .AND. igcc==0) THEN
          shortname = 'VDW-DF-OBK8'
       ELSEIF (iexch==6 .AND. icorr==4 .AND. igcx==40 .AND. igcc==0) THEN
          shortname = 'VDW-DF-C090'
       ENDIF
    ELSEIF (inlc==2) THEN
       if (iexch==1 .AND. icorr==4 .AND. igcx==13 .AND. igcc==0) THEN
          shortname = 'VDW-DF2'
       ELSEIF (iexch==1 .AND. icorr==4 .AND. igcx==16 .AND. igcc==0) THEN
          shortname = 'VDW-DF2-C09'
       ELSEIF (iexch==1 .AND. icorr==4 .AND. igcx==26 .AND. igcc==0) THEN
          shortname = 'VDW-DF2-B86R'
       ELSEIF (iexch==6 .AND. icorr==4 .AND. igcx==30 .AND. igcc==0) THEN
          shortname = 'VDW-DF2-0'
       ELSEIF (iexch==6 .AND. icorr==4 .AND. igcx==38 .AND. igcc==0) THEN
          shortname = 'VDW-DF2-BR0'
       ENDIF
    ELSEIF (inlc==3) THEN
       shortname = 'RVV10'
    ENDIF
    !
    get_dft_short = shortname
    !
  END FUNCTION get_dft_short
  !
  !
  !---------------------------------------------------------------------
  FUNCTION get_dft_long()
    !---------------------------------------------------------------------
    !
    CHARACTER(LEN=25) :: get_dft_long
    CHARACTER(LEN=25) :: longname
    !
    WRITE(longname,'(4a5)') exc(iexch), corr(icorr), gradx(igcx), gradc(igcc)
    !
    IF ( imeta > 0 ) THEN
       longname = longname(1:20)//TRIM(meta(imeta))
    ELSEIF ( inlc > 0 ) THEN
       longname = longname(1:20)//TRIM(nonlocc(inlc))
    ENDIF
    !
    get_dft_long = longname
    !
  END FUNCTION get_dft_long
  !
  !
!-----------------------------------------------------------------------
SUBROUTINE write_dft_name
!-----------------------------------------------------------------------
   WRITE( stdout, '(5X,"Exchange-correlation      = ",A, &
        &  " (",I2,3I3,2I2,")")') TRIM( dft ), iexch,icorr,igcx,igcc,inlc,imeta
   IF ( get_exx_fraction() > 0.0_dp ) WRITE( stdout, &
        '(5X,"EXX-fraction              =",F12.2)') get_exx_fraction()
   RETURN
END SUBROUTINE write_dft_name
!
!
!-----------------------------------------------------------------------
SUBROUTINE init_xc( family )
   !-------------------------------------------------------------------
   !! Gets from inside parameters needed to initialize lda xc-drivers.
   !
   USE kinds,          ONLY: DP
   USE xc_lda_lsda,    ONLY: libxc_switches_lda, iexch_l, icorr_l,     &
                             exx_started_l, is_there_finite_size_corr, &
                             exx_fraction_l, finite_size_cell_volume_l
   USE xc_gga,         ONLY: libxc_switches_gga, igcx_l, igcc_l, &
                             exx_started_g, exx_fraction_g,      &
                             screening_parameter_l, gau_parameter_l
   !
   IMPLICIT NONE
   !
   CHARACTER(LEN=*), INTENT(IN) :: family
   !
   IF (family.EQ.'LDA' .OR. family.EQ.'ALL') THEN
     ! =1 if libxc active, =0 otherwise
     IF (is_libxc(1)) libxc_switches_lda(1) = 1
     IF (is_libxc(2)) libxc_switches_lda(2) = 1
     ! exchange-correlation indexes
     iexch_l = get_iexch()
     icorr_l = get_icorr()
     !
     IF (iexch_l==-1 .OR. icorr_l==-1) CALL errore( 'init_xc', 'LDA functional &
                                                   & indexes not well defined', 1 )
     !
     ! hybrid exchange vars
     exx_started_l  = exx_started !is_active()
     exx_fraction_l = 0._DP
     IF ( exx_started_l ) exx_fraction_l = get_exx_fraction()
     !
     ! finite size correction vars
     CALL get_finite_size_cell_volume( is_there_finite_size_corr, &
                                       finite_size_cell_volume_l )
   ENDIF
   !
   IF (family.EQ.'GGA' .OR. family.EQ.'ALL') THEN
     ! =1 if libxc active, =0 otherwise
     IF (is_libxc(3)) libxc_switches_gga(1) = 1
     IF (is_libxc(4)) libxc_switches_gga(2) = 1
     ! exchange-correlation indexes
     igcx_l = get_igcx()
     igcc_l = get_igcc()
     !
     IF (igcx_l==-1 .OR. igcc_l==-1)  CALL errore( 'init_xc', 'GGA functional &
                                                  & indexes not well defined', 2 )     
     !
     ! hybrid exchange vars
     exx_started_g  = exx_started !is_active()
     exx_fraction_g = 0._DP
     IF ( exx_started_g ) exx_fraction_g = get_exx_fraction()
     !
     screening_parameter_l = get_screening_parameter()
     gau_parameter_l = get_gau_parameter()
   ENDIF
   !
   IF (family.NE.'LDA' .AND. family.NE.'GGA' .AND. family.NE.'ALL') &
     CALL errore( 'init_xc', 'family not found', 3 )
   !
   RETURN
   !
END SUBROUTINE init_xc
!
!
!-----------------------------------------------------------------------
!------- NONLOCAL CORRECTIONS DRIVERS ----------------------------------
!-----------------------------------------------------------------------
!
!-----------------------------------------------------------------------
SUBROUTINE nlc (rho_valence, rho_core, nspin, enl, vnl, v)
  !-----------------------------------------------------------------------
  !     non local correction for the correlation
  !
  !     input:  rho_valence, rho_core
  !     definition:  E_nl = \int E_nl(rho',grho',rho'',grho'',|r'-r''|) dr
  !     output: enl = E_nl
  !             vnl= D(E_x)/D(rho)
  !             v  = Correction to the potential
  !

  USE vdW_DF, ONLY: xc_vdW_DF, xc_vdW_DF_spin, vdw_type
  USE rVV10,  ONLY: xc_rVV10

  IMPLICIT NONE

  REAL(DP), INTENT(IN) :: rho_valence(:,:), rho_core(:)
  INTEGER, INTENT(IN)  :: nspin
  REAL(DP), INTENT(INOUT) :: v(:,:)
  REAL(DP), INTENT(INOUT) :: enl, vnl

  if ( inlc == 1 .or. inlc == 2 .or. inlc == 4 .or. inlc == 5 .or. inlc == 6 ) then

     vdw_type = inlc
     if( nspin == 1 ) then
        CALL xc_vdW_DF      (rho_valence, rho_core, enl, vnl, v)
     else if( nspin == 2 ) then
        CALL xc_vdW_DF_spin (rho_valence, rho_core, enl, vnl, v)
     else
        CALL errore ('nlc','vdW-DF not available for noncollinear spin case',1)
     end if

  elseif (inlc == 3) then
      if(imeta == 0) then
        CALL xc_rVV10 (rho_valence(:,1), rho_core, nspin, enl, vnl, v)
      else
        CALL xc_rVV10 (rho_valence(:,1), rho_core, nspin, enl, vnl, v, 15.7_dp)
      endif
  else
     enl = 0.0_DP
     vnl = 0.0_DP
     v = 0.0_DP
  endif
  !
  RETURN
END SUBROUTINE nlc

!
!-----------------------------------------------------------------------
!------- META CORRECTIONS DRIVERS ----------------------------------
!-----------------------------------------------------------------------
!
!-----------------------------------------------------------------------
SUBROUTINE tau_xc (rho, grho, tau, ex, ec, v1x, v2x, v3x, v1c, v2c, v3c)
  !-----------------------------------------------------------------------
  !     gradient corrections for exchange and correlation - Hartree a.u.
  !     See comments at the beginning of module for implemented cases
  !
  !     input:  rho, grho=|\nabla rho|^2
  !
  !     definition:  E_x = \int e_x(rho,grho) dr
  !
  !     output: sx = e_x(rho,grho) = grad corr
  !             v1x= D(E_x)/D(rho)
  !             v2x= D(E_x)/D( D rho/D r_alpha ) / |\nabla rho|
  !             v3x= D(E_x)/D(tau)
  !
  !             sc, v1c, v2c as above for correlation
  !
  IMPLICIT NONE

  REAL(DP) :: rho, grho, tau, ex, ec, v1x, v2x, v3x, v1c, v2c, v3c

  !_________________________________________________________________________

  if     (imeta == 1) then
     CALL tpsscxc (rho, grho, tau, ex, ec, v1x, v2x, v3x, v1c, v2c, v3c)
  elseif (imeta == 2) then
     CALL   m06lxc (rho, grho, tau, ex, ec, v1x, v2x, v3x, v1c, v2c, v3c)
  elseif (imeta == 3) then
     CALL  tb09cxc (rho, grho, tau, ex, ec, v1x, v2x, v3x, v1c, v2c, v3c)
  elseif (imeta == 4) then
     ! do nothing
  elseif (imeta == 5) then
     CALL  SCANcxc (rho, grho, tau, ex, ec, v1x, v2x, v3x, v1c, v2c, v3c)
  else
    CALL errore('tau_xc','wrong igcx and/or igcc',1)
  end if

  RETURN

END SUBROUTINE tau_xc

SUBROUTINE tau_xc_array (nnr, rho, grho, tau, ex, ec, v1x, v2x, v3x, v1c, v2c, v3c)
  ! HK/MCA : the xc_func_init is slow and is called too many times
  ! HK/MCA : we modify this subroutine so that the overhead could be minimized
  !-----------------------------------------------------------------------
  !     gradient corrections for exchange and correlation - Hartree a.u.
  !     See comments at the beginning of module for implemented cases
  !
  !     input:  rho, grho=|\nabla rho|^2
  !
  !     definition:  E_x = \int e_x(rho,grho) dr
  !
  !     output: sx = e_x(rho,grho) = grad corr
  !             v1x= D(E_x)/D(rho)
  !             v2x= D(E_x)/D( D rho/D r_alpha ) / |\nabla rho|
  !             v3x= D(E_x)/D(tau)
  !
  !             sc, v1c, v2c as above for correlation
  !
  IMPLICIT NONE

  INTEGER, intent(in) :: nnr
  REAL(DP) :: rho(nnr), grho(nnr), tau(nnr), ex(nnr), ec(nnr)
  REAL(DP) :: v1x(nnr), v2x(nnr), v3x(nnr), v1c(nnr), v2c(nnr), v3c(nnr)
  !_________________________________________________________________________

  if (imeta == 5) then
     CALL  scancxc_array (nnr, rho, grho, tau, ex, ec, v1x, v2x, v3x, v1c, v2c, v3c)
  elseif (imeta == 6 ) then ! HK/MCA: SCAN0
     CALL  scancxc_array (nnr, rho, grho, tau, ex, ec, v1x, v2x, v3x, v1c, v2c, v3c)
     if (exx_started) then
        ex  = (1.0_DP - exx_fraction) * ex
        v1x = (1.0_DP - exx_fraction) * v1x
        v2x = (1.0_DP - exx_fraction) * v2x
        v3x = (1.0_DP - exx_fraction) * v3x
     end if
  else
     CALL errore('v_xc_meta_array','(CP only) array mode only works for SCAN',1)
  end if

  RETURN

END SUBROUTINE tau_xc_array
!
!
!-----------------------------------------------------------------------
SUBROUTINE tau_xc_spin (rhoup, rhodw, grhoup, grhodw, tauup, taudw, ex, ec,   &
           &            v1xup, v1xdw, v2xup, v2xdw, v3xup, v3xdw, v1cup, v1cdw,&
           &            v2cup, v2cdw, v3cup, v3cdw)

!-----------------------------------------------------------------------
  !
  !

  IMPLICIT NONE

  real(dp), intent(in)                :: rhoup, rhodw, tauup, taudw
  real(dp), dimension (3), intent(in) :: grhoup, grhodw

  real(dp), intent(out)               :: ex, ec, v1xup, v1xdw, v2xup, v2xdw, v3xup, v3xdw,  &
                                      &  v1cup, v1cdw, v3cup, v3cdw
  real(dp), dimension(3), intent(out) :: v2cup, v2cdw

  !
  !  Local variables
  !
  INTEGER                 :: ipol
  real(dp)                :: rh, zeta, atau, grhoup2, grhodw2
  real(dp), parameter     :: epsr=1.0d-08, zero=0._dp
  !
  !_____________________________

  grhoup2 = zero
  grhodw2 = zero

  v2cup         = zero
  v2cdw         = zero

  ! FIXME: for SCAN, this will be calculated later
  if (imeta /= 4) then

      do ipol=1,3
        grhoup2 = grhoup2 + grhoup(ipol)**2
        grhodw2 = grhodw2 + grhodw(ipol)**2
      end do

  end if

  if (imeta == 1) then

     CALL tpsscx_spin(rhoup, rhodw, grhoup2, grhodw2, tauup,   &
              &  taudw, ex, v1xup,v1xdw,v2xup,v2xdw,v3xup,v3xdw)

     rh   =  rhoup + rhodw

     zeta = (rhoup - rhodw) / rh
     atau =  tauup + taudw    ! KE-density in Hartree

     CALL tpsscc_spin(rh,zeta,grhoup,grhodw, atau,ec,              &
     &                v1cup,v1cdw,v2cup,v2cdw,v3cup, v3cdw)


  elseif (imeta == 2) then

     CALL   m06lxc_spin (rhoup, rhodw, grhoup2, grhodw2, tauup, taudw,      &
            &            ex, ec, v1xup, v1xdw, v2xup, v2xdw, v3xup, v3xdw,  &
            &            v1cup, v1cdw, v2cup(1), v2cdw(1), v3cup, v3cdw)

  elseif (imeta == 5) then

            ! FIXME: not the most efficient use of libxc

            CALL scanxc_spin(rhoup, rhodw, grhoup, grhodw, tauup, taudw,  &
                     &  ex, v1xup,v1xdw,v2xup,v2xdw,v3xup,v3xdw,          &
                     &  ec, v1cup,v1cdw,v2cup,v2cdw,v3cup,v3cdw )

  else

    CALL errore('tau_xc_spin','This case not implemented',imeta)

  end if

END SUBROUTINE tau_xc_spin

SUBROUTINE tau_xc_array_spin (nnr, rho, grho, tau, ex, ec, v1x, v2x, v3x, &
  & v1c, v2c, v3c)
! HK/MCA : the xc_func_init (LIBXC) is slow and is called too many times
! HK/MCA : we modify this SUBROUTINE so that the overhead could be minimized
!-----------------------------------------------------------------------
!     gradient corrections for exchange and correlation - Hartree a.u.
!     See comments at the beginning of module for implemented cases
!
!     input:  rho,rho, grho=\nabla rho
!
!     definition:  E_x = \int e_x(rho,grho) dr
!
!     output: sx = e_x(rho,grho) = grad corr
!             v1x= D(E_x)/D(rho)
!             v2x= D(E_x)/D( D rho/D r_alpha ) / |\nabla rho|
!             v3x= D(E_x)/D(tau)
!
!             sc, v1cup, v2cup as above for correlation
!
IMPLICIT NONE

INTEGER, intent(in) :: nnr
REAL(DP) :: rho(nnr,2), grho(3,nnr,2), tau(nnr,2), ex(nnr), ec(nnr)
REAL(DP) :: v1x(nnr,2), v2x(nnr,3), v3x(nnr,2), v1c(nnr,2), v2c(nnr,3), v3c(nnr,2)

!Local variables

INTEGER  :: ipol, k, is
REAL(DP) :: grho2(3,nnr)
!MCA: Libxc format
REAL(DP) :: rho_(2,nnr), tau_(2,nnr)
REAL(DP) :: v1x_(2,nnr), v2x_(3,nnr), v3x_(2,nnr), v1c_(2,nnr), v2c_(3,nnr), v3c_(2,nnr)

!_________________________________________________________________________

grho2 = 0.0

!MCA/HK: contracted gradient of density, same format as in libxc
do k=1,nnr

do ipol=1,3
grho2(1,k) = grho2(1,k) + grho(ipol,k,1)**2
grho2(2,k) = grho2(2,k) + grho(ipol,k,1) * grho(ipol,k,2)
grho2(3,k) = grho2(3,k) + grho(ipol,k,2)**2
end do

!MCA: transforming to libxc format (DIRTY HACK)
do is=1,2
rho_(is,k) = rho(k,is)
tau_(is,k) = tau(k,is)
enddo

end do

if (imeta == 5) then

!MCA/HK: using the arrays in libxc format
CALL  scancxc_array_spin (nnr, rho_, grho2, tau_, ex, ec, &
&                   v1x_, v2x_, v3x_,  &
&                   v1c_, v2c_, v3c_ )

do k=1,nnr

!MCA: from libxc to QE format (DIRTY HACK)
do is=1,2
v1x(k,is) = v1x_(is,k)
v2x(k,is) = v2x_(is,k) !MCA/HK: v2x(:,2) contains the cross terms
v3x(k,is) = v3x_(is,k)
v1c(k,is) = v1c_(is,k)
v2c(k,is) = v2c_(is,k) !MCA/HK: same as v2x
v3c(k,is) = v3c_(is,k)
enddo

v2c(k,3) = v2c_(3,k)
v2x(k,3) = v2x_(3,k)

end do

elseif (imeta == 6 ) then ! HK/MCA: SCAN0
CALL  scancxc_array (nnr, rho, grho, tau, ex, ec, v1x, v2x, v3x, v1c, v2c, v3c)
if (exx_started) then
ex  = (1.0_DP - exx_fraction) * ex
v1x = (1.0_DP - exx_fraction) * v1x
v2x = (1.0_DP - exx_fraction) * v2x
v3x = (1.0_DP - exx_fraction) * v3x
end if
else
CALL errore('v_xc_meta_array','(CP only) array mode only works for SCAN',1)
end if

RETURN

END SUBROUTINE tau_xc_array_spin
!
!
#if defined(__LIBXC)
  SUBROUTINE get_libxc_version
     !
     IMPLICIT NONE
     !
     INTERFACE
        SUBROUTINE xc_version( major, minor, micro ) bind(c)
           USE iso_c_binding
           INTEGER(c_int) :: major, minor, micro
        END SUBROUTINE xc_version
     END INTERFACE
     !
     CALL xc_version( libxc_major, libxc_minor, libxc_micro )
     !
  END SUBROUTINE get_libxc_version
#endif
!
!
END MODULE funct

