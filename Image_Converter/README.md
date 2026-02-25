Designed and implemented an FPGA-based image processing system on Xilinx Artix-7. 
The system receives an image via UART, converts it to grayscale, applies convolution-based edge 
enhancement, and transmits the processed image back via UART. 
Implemented hardware blocks using Vivado Block Design and AXI4-Stream communication 
between modules.

uploaded only the .srcs folder with inside all the .vhd and block design and file .xpr
first create the vivado project, create btistream to upload on the board and then run the .exe in the run folder.
every time that the run end, to do another execution you need to reset the board with the middle button or it will give error.
i added some result in the run folder.
