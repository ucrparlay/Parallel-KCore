# GBBS root directory (relative to this makefile location)
ROOTDIR = ../../../

include $(ROOTDIR)makefile.variables

ALL= KCore

include $(ROOTDIR)benchmarks/makefile.benchmarks

# Additional dependencies specific to KCore
KCore: KCore.cc KCore.h

# Clean target for this directory
clean-local:
	rm -f KCore *.o *.log *.csv

# Phony targets
.PHONY: clean-local

