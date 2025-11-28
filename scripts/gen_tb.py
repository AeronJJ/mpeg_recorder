import os
import sys
import re
from dataclasses import dataclass

@dataclass
class Port_Object:
    name: str
    direction: str
    width: str
    net: str

    def definition(self):
        if self.width != '':
            wdth = '[' + self.width + '] '
        else:
            wdth = ''
        if self.direction == 'input':
            return f'reg {wdth}{self.name}_i'
        elif self.direction == 'output':
            return f'wire {wdth}{self.name}_o'
        else:
            return -1 # TODO: Fix for inout

    def inst(self):
        if self.direction != 'inout':
            return f'.{self.name}({self.name}_{'i' if self.direction == 'input' else 'o'})'
        else:
            return -1 # TODO: Fix

    def __post_init__(self):
        allowed_directions = {'input', 'output', 'inout'}
        if self.direction not in allowed_directions:
            raise ValueError(f'Invalid direction: {self.direction}. Must be one of {allowed_directions}')

        allowed_nets = {'wire', 'reg', 'logic'}
        if self.net not in allowed_nets:
            raise ValueError(f'Invalid net: {self.net}. Must be one of {allowed_nets}')

def get_ports(file):
    # Open systemverilog file
    module = []
    next_line = 'hi'
    log(f"Opening {file}")
    try:
        with open(file, 'r') as f:
            while 'input' not in next_line and 'output' not in next_line and next_line:
                next_line = f.readline()
            
            if not next_line:
                raise RuntimeError(f'Ports cannot be found in HDL file')
        
            while ')' not in next_line and next_line:
                if next_line.strip(): # Check line is not blank
                    module.append(next_line)
                next_line = f.readline()
            
            if not next_line:
                raise RuntimeError(f'Closing bracket for ports cannot be found in HDL file')
    except Exception as e:
        raise RuntimeError(f"Failed to read file: {e}")
        
    ports = []
    for port in module:
        log(f"Found port: {port}")
        ports.append(parse_ports(port))
    log(f"Ports found: {ports}")

    # TODO: sort by input/output
    return ports
    
def parse_ports(string):
    # TODO: check whether multiple ports exist on same line
    string = string.replace('\t', ' ') # Remove tabs

    # Find direction of port
    direction = ''
    allowed_directions = {'input', 'output', 'inout'}
    for dir in allowed_directions:
        if dir in string.lower():
            direction = dir
    # if direction == '':
        # return -1

    # Find net of port
    net = ''
    allowed_nets = {'wire', 'reg', 'logic'}
    for ne in allowed_nets:
        if ne in string.lower():
            net = ne

    # Find width of port
    width = ''
    if '[' in string:
        width = string.split('[', 1)[1].split(']')[0]

    # Find name of port
    name = string.rstrip('\n').replace(',', '').split(' ')[-1]

    return Port_Object(name=name, direction=direction, width=width, net=net)

# Print params
def print_params(ports):
    return ''

# Print tb wire definitions
def print_definitions(ports):
    nets = ''
    for port in ports:
        nets += port.definition() + ';\n\t'
    return nets
    
# Print tb dut instantiation
def print_instantiation(module_name, ports):
    msg = ''
    msg += module_name + ' dut_' + module_name + ' (\n\t'
    for port in ports:
        msg += port.inst() + ',\n\t'
    msg = msg.rstrip(',\n\t') + '\n\t);'
    return msg

# ports = get_ports('lut/hdl/lut.sv')
# print(print_definitions(ports))
# print(print_instantiation('lut', ports))

def log(msg):
    if (verbose):
        print(msg)

# Get args from command line and generate sim folder if not existing
def main():
    global verbose
    verbose = False
    name = ''
    for cmd in sys.argv:
        if cmd == '-h':
            print("Usage: python gen_tb.py name [-v] [-h]")
            print("or mpeg_gen_tb name [-v] [-h]")
            print("Must be used within $PROJ_ROOT/src/*name*")
            return -1
        else if cmd == "-v":
            verbose = True
        else if name == '':
            name = cmd
        else:
            print("Unknown usage")
            print("Usage: python gen_tb.py name [-v] [-h]")
            return -1
        
    # name = sys.argv[1]
    log(f"Design name = {name}")
    
    ports = get_ports(f'hdl/{name}.sv')
    path = os.path.join('sim', f'{name}_tb.sv')
    if not os.path.exists(path):
        raise RuntimeError(f"Failed to find template file, Pleas copy tb template folder to {path}")
    else:
        with open(path, "r+", encoding="utf-8") as f:
            text = f.read()
            new_text = re.sub(re.escape('**PARAM_LIST**'), print_params(ports), text)
            new_text = re.sub(re.escape('**NET_LIST**'), print_definitions(ports), new_text)
            new_text = re.sub(re.escape('**DUT_INST**'), print_instantiation(name, ports), new_text)
            f.seek(0)
            f.write(new_text)
            f.truncate()

if __name__ == '__main__':
    main()
