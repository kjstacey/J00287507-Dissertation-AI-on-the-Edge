import json

def generate_header(input_file, output_file):
    with open(input_file, 'r') as f:
        data = json.load(f)

    with open(output_file, 'w') as f:
        f.write("#ifndef PARAMS_H\n#define PARAMS_H\n\n")
        
        # Process Weights
        for i, layer_weights in enumerate(data['weights']):
            # Flatten nested lists into a single list of floats
            flat_weights = [w for sublist in layer_weights for w in (sublist if isinstance(sublist, list) else [sublist])]
            f.write(f"const float weights_layer{i+1}[{len(flat_weights)}] = {{\n")
            f.write(", ".join(map(str, flat_weights)))
            f.write("\n};\n\n")

        # Process Biases
        for i, layer_biases in enumerate(data['biases']):
            # Biases in your file are nested like [[val], [val]], flatten them
            flat_biases = [b[0] if isinstance(b, list) else b for b in layer_biases]
            f.write(f"const float bias_layer{i+1}[{len(flat_biases)}] = {{\n")
            f.write(", ".join(map(str, flat_biases)))
            f.write("\n};\n\n")

        f.write("#endif\n")

if __name__ == "__main__":
    generate_header('WeigntsAndBiases.txt', 'params.h')
    print("Successfully generated params.h")