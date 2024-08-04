from vunit import VUnit
import pathlib

def get_vhdl_files(dir, recursive=False):
    directory = pathlib.Path(dir)
    if recursive:
        allVhdlFiles = list(directory.rglob('*.vhd'))
    else:
        allVhdlFiles = list(directory.glob('*.vhd'))
    return allVhdlFiles

# Create VUnit instance by parsing command line arguments
vu = VUnit.from_argv(['--gtkwave-fmt', 'ghw'])

# Optionally add VUnit's builtin HDL utilities for checking, logging, communication...
# See http://vunit.github.io/hdl_libraries.html.
vu.add_vhdl_builtins()
vu.add_osvvm()
# or
# vu.add_verilog_builtins()

universal = vu.add_library("universal")
files = get_vhdl_files('./libraries/universal/hdl', recursive=True)
for file in files:
    universal.add_source_file(file)

# Create library 'lib'
piximatrix = vu.add_library("piximatrix")
files = get_vhdl_files('./hdl/rtl', recursive=True)
for file in files:
    piximatrix.add_source_file(file)

tb = vu.add_library("tb")
files = get_vhdl_files('./hdl/tb', recursive=True)
for file in files:
    tb.add_source_file(file)

def encode(tb_cfg):
    return ", ".join(["%s:%s" % (key, str(tb_cfg[key])) for key in tb_cfg])

# Run vunit function
vu.add_compile_option('ghdl.a_flags', ['-frelaxed'])
vu.set_sim_option('ghdl.elab_flags', ['-frelaxed'])
vu.main()