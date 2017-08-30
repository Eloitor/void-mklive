GITVER := $(shell git rev-parse --short HEAD)
VERSION = 0.22
SHIN    += $(shell find -type f -name '*.sh.in')
SCRIPTS += $(SHIN:.sh.in=.sh)
DATE=$(shell date "+%Y%m%d")

T_PLATFORMS=rpi{,2,3}{,-musl} beaglebone{,-musl} cubieboard2{,-musl} odroid-c2{,-musl} usbarmory{,-musl} GCP{,-musl}
T_ARCHS=i686 x86_64{,-musl} armv{6,7}l{,-musl} aarch64{,-musl}

T_SBC_IMGS=rpi{,2,3}{,-musl} beaglebone{,-musl} cubieboard2{,-musl} odroid-c2{,-musl} usbarmory{,-musl}
T_CLOUD_IMGS=GCP{,-musl}

T_PXE_ARCHS=x86_64{,-musl}

ARCHS=$(shell echo $(T_ARCHS))
PLATFORMS=$(shell echo $(T_PLATFORMS))
SBC_IMGS=$(shell echo $(T_SBC_IMGS))
CLOUD_IMGS=$(shell echo $(T_CLOUD_IMGS))
PXE_ARCHS=$(shell echo $(T_PXE_ARCHS))

ALL_ROOTFS=$(foreach arch,$(ARCHS),void-$(arch)-ROOTFS-$(DATE).tar.xz)
ALL_PLATFORMFS=$(foreach platform,$(PLATFORMS),void-$(platform)-PLATFORMFS-$(DATE).tar.xz)
ALL_SBC_IMAGES=$(foreach platform,$(SBC_IMGS),void-$(platform)-$(DATE).img.xz)
ALL_CLOUD_IMAGES=$(foreach cloud,$(CLOUD_IMGS),void-$(cloud)-$(DATE).tar.gz)
ALL_PXE_ARCHS=$(foreach arch,$(PXE_ARCHS),void-$(arch)-NETBOOT-$(DATE).tar.gz)

SUDO := sudo

XBPS_REPOSITORY := -r https://lug.utdallas.edu/mirror/void/current -r https://lug.utdallas.edu/mirror/void/current/musl -r https://lug.utdallas.edu/mirror/void/current/aarch64
COMPRESSOR_THREADS=2

%.sh: %.sh.in
	 sed -e "s|@@MKLIVE_VERSION@@|$(VERSION) $(GITVER)|g" $^ > $@
	 chmod +x $@

all: $(SCRIPTS)

clean:
	rm -v *.sh

distdir-$(DATE):
	mkdir -p distdir-$(DATE)

dist: distdir-$(DATE)
	mv void*$(DATE)* distdir-$(DATE)/

rootfs-all: $(ALL_ROOTFS)

rootfs-all-print:
	@echo $(ALL_ROOTFS) | sed "s: :\n:g"

void-%-ROOTFS-$(DATE).tar.xz: $(SCRIPTS)
	$(SUDO) ./mkrootfs.sh $(XBPS_REPOSITORY) -x $(COMPRESSOR_THREADS) $*
	mkdir -p stamps
	touch stamps/platformfs-$*-$(DATE)-stamp

platformfs-all: rootfs-all $(ALL_PLATFORMFS)

platformfs-all-print:
	@echo $(ALL_PLATFORMFS) | sed "s: :\n:g"

void-%-PLATFORMFS-$(DATE).tar.xz: $(SCRIPTS) stamps/platformfs-%-$(DATE)-stamp
	$(SUDO) ./mkplatformfs.sh $(XBPS_REPOSITORY) -x $(COMPRESSOR_THREADS) $* void-$(shell ./lib.sh platform2arch $*)-ROOTFS-$(DATE).tar.xz

stamps/platformfs-%-$(DATE)-stamp:
# This rule exists because you can't do the shell expansion in the
# dependent rule resolution stage
	$(MAKE) void-$(shell ./lib.sh platform2arch $*)-ROOTFS-$(DATE).tar.xz

images-all: platformfs-all images-all-sbc images-all-cloud

images-all-sbc: $(ALL_SBC_IMAGES)

images-all-cloud: $(ALL_CLOUD_IMAGES)

images-all-print:
	@echo $(ALL_SBC_IMAGES) $(ALL_CLOUD_IMAGES) | sed "s: :\n:g"

void-%-$(DATE).img.xz: void-%-PLATFORMFS-$(DATE).tar.xz
	$(SUDO) ./mkimage.sh -x $(COMPRESSOR_THREADS) void-$*-PLATFORMFS-$(DATE).tar.xz

# Some of the images MUST be compressed with gzip rather than xz, this
# rule services those images.
void-%-$(DATE).tar.gz: void-%-PLATFORMFS-$(DATE).tar.xz
	$(SUDO) ./mkimage.sh -x $(COMPRESSOR_THREADS) void-$*-PLATFORMFS-$(DATE).tar.xz

pxe-all: $(ALL_PXE_ARCHS)

pxe-all-print:
	@echo $(ALL_PXE_ARCHS) | sed "s: :\n:g"

void-%-NETBOOT-$(DATE).tar.gz: $(SCRIPTS) void-%-ROOTFS-$(DATE).tar.xz
	$(SUDO) ./mknet.sh void-$*-ROOTFS-$(DATE).tar.xz

.PHONY: clean dist rootfs-all-print platformfs-all-print pxe-all-print
