import sys
import argparse
import os

def log(msg):
    global n
    if (verbose):
        print(f"{n}: {msg}")
        n += 1

def parse_args():
    parser = argparse.ArgumentParser(
        description="Merge SystemVerilog testbench and stimuli files."
    )

    parser.add_argument(
        "-t", "--tb",
        required=True,
        help="Path to testbench SystemVerilog file"
    )

    parser.add_argument(
        "-s", "--stimuli",
        required=True,
        help="Path to stimuli SystemVerilog file"
    )

    parser.add_argument(
        "-o", "--output",
        required=True,
        help="Path to output file"
    )

    parser.add_argument(
        "--placeholder",
        default="/* INSERT */",
        help="Text in the testbench file to replace with stimuli content"
    )

    parser.add_argument(
        "-v", "--verbose",
        action="store_true",
        help="Enable verbose output"
    )

    return parser.parse_args()

def insert_sv_to_sv(tb, stimuli, output, placeholder):
    # Check testbench file exists
    if not os.path.isfile(tb):
        print(f"ERROR: Testbench file not found: {tb}")
        sys.exit(1)

    # Check stimuli file exists
    if not os.path.isfile(stimuli):
        print(f"ERROR: Stimuli file not found: {stimuli}")
        sys.exit(1)

    # Read testbench
    try:
        log("Reading Testbench")
        with open(tb, "r") as f:
            tb_contents = f.read()
    except Exception as e:
        print(f"ERROR: Could not read testbench file '{tb}': {e}")
        sys.exit(1)

    # Read stimuli
    try:
        log("Reading Stimuli")
        with open(stimuli, "r") as f:
            stimuli_contents = f.read()
    except Exception as e:
        print(f"ERROR: Could not read stimuli file '{stimuli}': {e}")
        sys.exit(1)

    # Check placeholder exists
    if placeholder not in tb_contents:
        print(f"ERROR: Placeholder '{placeholder}' not found in testbench file.")
        sys.exit(1)

    # Perform replacement
    log("Merging content")
    merged = tb_contents.replace(placeholder, stimuli_contents)

    # Write output
    try:
        log("Writing output")
        with open(output, "w") as f:
            f.write(merged)
    except Exception as e:
        print(f"ERROR: Could not write output file '{output}': {e}")
        sys.exit(1)

    log(f"Successfully created: {output}")

def main():
    # Parse arguemnts
    args = parse_args()
    global verbose
    verbose = args.verbose
    global n
    n = 0

    insert_sv_to_sv(args.tb, args.stimuli, args.output, args.placeholder)

if __name__ == '__main__':
    main()
