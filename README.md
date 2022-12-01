# Image_compression
Entropy based Image Partitioning.
Considering an energy_limited wireless device that periodically captures images and uploads it over a wirelesschannel. 
Energy is expended in the device for wireless transmission of bits(𝐸𝑡,μj/bits) and computation(𝐸𝑐,μj/bits).
We would like to optimize the total energy per bit.We have three options:-

I.   We upload the compressed image(i.e.We have to transmit a larger number of bits).

II.  We compress the entire image and then send (We will save energy by transmitting a shorted bitstream but spend energy doing compression).

III. We cancompress part of the image (based on entropy-based partitioning) and send partly compressed and party uncompressed(rawbits).


Steps:-

*** First we divide the image into blocks and see which ones to compress.

*** Design an optimal scheme using entropy-based image partitioning in order to minimize energy per bit.

*** Also carryout simulations using realistic numbers for 𝐸𝑡(Say,forIEEE802.11x) and 𝐸𝑐(Say ,for the ARM processor).
