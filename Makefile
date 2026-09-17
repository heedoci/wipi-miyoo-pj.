.PHONY: smoke syntax package

smoke:
	./test/smoke_test.sh

syntax:
	bash -n scripts/*.sh onion/Emu/WIPI/launch.sh test/*.sh
	python3 -m py_compile scripts/patch_core.py

package:
	./scripts/assemble_sd.sh dist
