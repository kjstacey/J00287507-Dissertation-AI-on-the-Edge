from pathlib import Path

# ============================================================
# SETTINGS
# ============================================================

input_dir = Path(
    "C:/Users/KristaStacey/Documents/mlproject/Mnist_CameraSpeedCloud/"
    "Mnist_Camera.sim/sim_1/behav/xsim"
)

output_dir = Path(
    "C:/Users/KristaStacey/Documents/mlproject/Mnist_CameraSpeedCloud/"
    "Mnist_Camera.srcs/sources_1/new"
)

start_index = 0
test_count = 100
pixels_per_image = 784

# ============================================================
# OUTPUT FILES
# ============================================================

coe_file = output_dir / f"mnist_test_pixels_{start_index:04d}.coe"
vhdl_file = output_dir / "mnist_test_rom_pkg.vhd"

# ============================================================
# READ TEST DATA
# ============================================================

all_pixels = []
labels = []

for image_index in range(start_index, start_index + test_count):

    input_file = input_dir / f"test_data_{image_index:04d}.txt"

    if not input_file.exists():
        raise FileNotFoundError(
            f"Could not find {input_file}"
        )

    lines = [
        line.strip()
        for line in input_file.read_text().splitlines()
        if line.strip()
    ]

    if len(lines) != 785:
        raise ValueError(
            f"{input_file.name}: expected 785 lines, "
            f"found {len(lines)}"
        )

    # First 784 lines are pixels
    pixels = lines[:pixels_per_image]

    # Final line is expected label
    expected_label = int(lines[784], 2)

    if expected_label < 0 or expected_label > 9:
        raise ValueError(
            f"{input_file.name}: invalid label "
            f"{expected_label}"
        )

    labels.append(expected_label)

    for binary_value in pixels:

        value = int(binary_value, 2)

        if value < 0 or value > 255:
            raise ValueError(
                f"{input_file.name}: pixel value "
                f"{value} is outside 0-255"
            )

        all_pixels.append(value)

# ============================================================
# VERIFY COUNTS
# ============================================================

expected_pixel_count = test_count * pixels_per_image

if len(all_pixels) != expected_pixel_count:
    raise ValueError(
        f"Expected {expected_pixel_count} pixels, "
        f"but collected {len(all_pixels)}"
    )

if len(labels) != test_count:
    raise ValueError(
        f"Expected {test_count} labels, "
        f"but collected {len(labels)}"
    )

# ============================================================
# WRITE COE FILE
# ============================================================

with coe_file.open("w") as f:

    f.write("memory_initialization_radix=16;\n")
    f.write("memory_initialization_vector=\n")

    for i, value in enumerate(all_pixels):

        if i < len(all_pixels) - 1:
            f.write(f"{value:02X},\n")
        else:
            f.write(f"{value:02X};\n")

# ============================================================
# WRITE VHDL LABEL PACKAGE
# ============================================================

with vhdl_file.open("w") as f:

    f.write("library IEEE;\n")
    f.write("use IEEE.STD_LOGIC_1164.ALL;\n")
    f.write("use IEEE.NUMERIC_STD.ALL;\n\n")

    f.write("package mnist_test_rom_pkg is\n\n")

    f.write(
        f"    constant MNIST_TEST_COUNT : integer := "
        f"{test_count};\n"
    )

    f.write(
        "    constant MNIST_PIXELS_PER_IMAGE : "
        "integer := 784;\n\n"
    )

    f.write(
        "    type mnist_label_type is array\n"
    )

    f.write(
        "        (0 to MNIST_TEST_COUNT - 1)\n"
    )

    f.write(
        "        of std_logic_vector(3 downto 0);\n\n"
    )

    f.write(
        "    constant MNIST_LABEL_ROM : "
        "mnist_label_type := (\n"
    )

    for i, label in enumerate(labels):

        if i < len(labels) - 1:
            f.write(
                f'        {i:3d} => x"{label:X}",\n'
            )
        else:
            f.write(
                f'        {i:3d} => x"{label:X}"\n'
            )

    f.write("    );\n\n")
    f.write("end package mnist_test_rom_pkg;\n")

# ============================================================
# SUMMARY
# ============================================================

print()
print("Generation complete.")
print("-----------------------------------")
print(f"Start image:   {start_index}")
print(
    f"End image:     "
    f"{start_index + test_count - 1}"
)
print(f"Image count:   {test_count}")
print(f"Pixel count:   {len(all_pixels)}")
print()
print(f"COE file:")
print(coe_file)
print()
print(f"VHDL package:")
print(vhdl_file)
print()
print("Labels:")
print(labels)