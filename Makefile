YOSYS ?= yosys
NEXTPNR ?= nextpnr-himbaechel

.DEFAULT_GOAL := all

all: \
	hsdaoh-tangnano20k.fs

unpacked:\
	hsdaoh-tangnano20k-unpacked.v \

clean:
	rm -f *.json *.fs *-unpacked.v

.PHONY: unpacked clean

# ============================================================
# Tangnano20k
%-tangnano20k.fs: %-tangnano20k.json
	gowin_pack -d GW2A-18C -o $@ $<

%-tangnano20k.json: %-tangnano20k-synth.json tangnano20k.cst
	$(NEXTPNR) --json $< --write $@ --device GW2AR-LV18QN88C8/I7 --vopt family=GW2A-18C --vopt cst=tangnano20k.cst

%-tangnano20k-synth.json: %.v
	$(YOSYS) -p "read_verilog $^; synth_gowin -json $@"

hsdaoh-tangnano20k-synth.json: hsdaoh_nano20k_test/top.v common/hsdaoh/hsdaoh_core.v common/hdmi/auxiliary_video_information_info_frame.v common/hdmi/hdmi.v common/hdmi/packet_assembler.v common/hdmi/packet_picker.v common/hdmi/serializer.v common/hdmi/tmds_channel.v common/async_fifo/async_fifo.v common/async_fifo/fifomem.v common/async_fifo/rptr_empty.v common/async_fifo/sync_r2w.v common/async_fifo/sync_w2r.v common/async_fifo/wptr_full.v
	$(YOSYS) -D INV_BTN=1 -p "read_verilog $^; synth_gowin -json $@"


# ============================================================
#  Upack

%-tangnano20k-unpacked.v: %-tangnano20k.fs
	gowin_unpack -d GW2A-18C -o $@ $^
