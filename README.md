# FPGA implementation of hsdaoh - High Speed Data Acquisition over HDMI

This repository contains the FPGA implementation and example designs for the Tang Nano/Primer series of FPGA boards. For more information see the [main repository](https://github.com/steve-m/hsdaoh).

The example design generates a 16 bit counter, that then can be verified on the host. With a small modification to the clk_data process in the top-file of your respective FPGA board you can stream your own payload data.

## Building the desgin
Currently, the bitfiles must be generated with the GOWIN IDE (V1.9.9 Beta-4 Education). See [here](https://wiki.sipeed.com/hardware/en/tang/Tang-Nano-Doc/install-the-ide.html) for more information on how to set up the IDE.

In the future, it might be possible to use the Open Source toolchain ([Yosys](https://github.com/YosysHQ/yosys) + [nextpnr-himbaechel](https://github.com/YosysHQ/nextpnr) + [apicula](https://github.com/YosysHQ/apicula)). This is currently blocked by the lack of the CLKDIV primitive
in the Open Source tools.

## Loading the bitfile

The bitfile can be either loaded with the GOWIN Programmer, or with [openFPGALoader](https://github.com/trabucayre/openFPGALoader).

Here is an example commandline for loading the bitfile on a Tang Nano 20K:

    openFPGALoader -b tangnano20k hsdaoh_nano20k_test.fs 

## Testing the design

After loading the bitfile, connect the FPGA board to a MS2130 HDMI grabber and confirm that the video output is working. You then can use hsdaoh_test to verify the counter values.

## Credits

The hsdaoh FPGA design was developed by Steve Markgraf, and is heavily based on the [HDMI IP core](https://github.com/hdl-util/hdmi) by Sameer Puri and also uses the [asynchronous FIFO](https://github.com/dpretet/async_fifo) by Damien Pretet.
