DTC = dtc
SRC = socfpga.dts
OUT = socfpga.dtb

all: $(OUT)

$(OUT): $(SRC)
	$(DTC) -O dtb -o $(OUT) $(SRC)

clean:
	rm -f $(OUT)
