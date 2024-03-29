# Makefile for EPW

include ../../make.inc
include make.libs

#
# use recursive definitions in Makefile to modify the PATH for modules
#

MODFLAGS= $(BASEMOD_FLAGS) \
          $(MOD_FLAG)../../PW/src \
          $(MOD_FLAG)../../PHonon/PH \
          $(MOD_FLAG)../../LR_Modules \
          $(MOD_FLAG)../../wannier90-3.1.0/src/obj \
          $(MOD_FLAG)../../dft-d3

#
# The above is in alphabetical order except when order matter during compilation
#
##### io_scattering.o \

EPWOBJS = \
epwcom.o \
constants_epw.o \
elph2.o \
io_var.o \
low_lvl.o \
division.o \
rigid_epw.o \
io_epw.o \
io_transport.o \
io_selfen.o \
wigner.o \
wan2bloch.o \
cum_mod.o \
close_epw.o \
poolgathering.o \
printing.o \
kfold.o \
dynmat_asr.o \
io_eliashberg.o \
utilities.o \
eliashbergcom.o \
supercond.o \
supercond_iso.o \
supercond_aniso.o \
grid.o \
bfield.o \
rotate.o \
transport.o \
transport_iter.o \
pw2wan2epw.o \
wannierization.o \
indabs.o \
io_indabs.o\
bcast_epw_input.o \
bloch2wan.o \
dvqpsi.o \
eliashberg.o \
elphel2_shuffle.o \
elphon_shuffle.o \
elphon_shuffle_wrap.o \
selfen.o \
spectral_func.o \
ephwann_shuffle.o \
ephwann_shuffle_mem.o \
epw_init.o \
epw_readin.o \
epw_setup.o \
epw_summary.o \
loadumat.o \
stop_epw.o \
wannierEPW.o \
loadbm.o
EPWOBJS += ephblochkq.o wfc_elec.o test_tools.o

#default : epw


PHOBJS = ../../PHonon/PH/libph.a
PWOBJS = ../../PW/src/libpw.a
W90LIB = ../../wannier90-3.1.0/libwannier.a
LRMODS = ../../LR_Modules/liblrmod.a
PWOBJS = ../../PW/src/libpw.a
QEMODS = ../../Modules/libqemod.a ../../KS_Solvers/libks_solvers.a ../../XClib/xc_lib.a \
         ../../upflib/libupf.a ../../FFTXlib/libqefft.a ../../dft-d3/libdftd3qe.a
LIBOBJS =../../LAXlib/libqela.a ../../UtilXlib/libutil.a ../../clib/clib.a

TLDEPS= pw ph pp

all :   pw ph pp wannier libepw.a epw.x

libepw.a : $(EPWOBJS)
	$(AR) $(ARFLAGS) $@ $?
	$(RANLIB) $@

epw.x : epw.o libepw.a $(PHOBJS) $(LRMODS) $(PWOBJS) $(W90LIB) $(QEMODS) $(LIBOBJS)
	$(LD) $(LDFLAGS) -o $@ \
	epw.o  libepw.a	$(PHOBJS) $(LRMODS) $(W90LIB) $(PWOBJS) $(QEMODS) $(LIBOBJS) $(QELIBS)
	- ( cd ../bin ; ln -fs ../src/epw.x . )

pw :
	cd ../../ ; make pw

ph :
	cd ../../ ; make ph

pp :
	cd ../../ ; make pp

wannier :
	cd ../../ ; make w90 ; cd wannier90-3.1.0/ ; make lib

ld1 :
	cd ../../ ; make ld1

clean :
	- /bin/rm -f  *.o *~ *.d *.mod *.i libepw.a liblr.a

include make.depend
