# P2000C ByteBridge (BB) Serial File Transfer

## Purpose
This repository allows files to be transmitted from a modern machine to the
P2000C using its serial interface port. On the transmitter device, a Python
script is executed which informs the P2000C on the file size, its name and
a CRC16 checksum. After the P2000C is able to successfully relay this data
back to the transmitter device, file transfer is conducted. If the CRC16
checksum is reproduced on the P2000C, the file will be written to the floppy
drive.

## Usage

Open the file `upload.py` and specify the `srcfile` and `dstfile` variables. For
example, to upload the local `bb.com` compilation to the P2000C and store it
on the B drive, we use

```python
upload('../src/bb.com', 'b:bb.com')
```

On the P2000C, run `BB.COM` and wait until the message

```
Ready to receive file. Start the transfer.
```

is seen. **Do not execute the Python script before this message is seen.**
Premature execution of the Python script potentially results in the P2000C
locking up, requiring the machine to reboot.

Once the above message is seen on the P2000C, execute the script.

## Compilation instructions

`BB.COM` can be compiled using [NASM](https://www.nasm.us/). For convenience,
a `Makefile` is provided to assist in the compilation.

```bash
cd src
make
```