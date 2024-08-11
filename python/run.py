from vunit import VUnit
import pathlib

#from modeltester import recreate_image

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

tb_piximatrix = vu.add_library("tb_piximatrix")
files = get_vhdl_files('./hdl/tb', recursive=True)
for file in files:
    tb_piximatrix.add_source_file(file)

def encode(tb_cfg):
    return ", ".join(["%s:%s" % (key, str(tb_cfg[key])) for key in tb_cfg])

tb_cfg = dict(input_path="python/lena.txt", output_path="python/lena_post.txt")
tb_LedMatrixInterface = tb_piximatrix.test_bench('tb_LedMatrixInterface')
tb_LedMatrixInterface.add_config(name='lena_test', generics=dict(encoded_tb_cfg=encode(tb_cfg)))

# def post_test(results):
#     golden    = recreate_image("python/lena.txt", 64, 64)
#     simulated = recreate_image("python/lena_post.txt", 64, 64)
#     if not np.allclose(golden, simulated):
#         raise ValueError
#     print("All post tests passed.")

# Run vunit function
vu.add_compile_option('ghdl.a_flags', ['-frelaxed'])
vu.set_sim_option('ghdl.elab_flags', ['-frelaxed'])
vu.main()
