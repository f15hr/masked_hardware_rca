# A simple masked ripple carry adder.

Implemented with a masked XOR and AND. This hardware definition has no guarantees of security. Use at your own risk.

## Requirements

A synthesis or simulation tool. My recommendation is [Verilator](https://www.veripool.org/verilator/).

### Build Example

```verilator -binary ./adder.sv```

### Usage

For adding `[value A]` + `[value B]` + `[carry in]`

```./adder.sv +a=[value A] +b=[value B] +cin=[carry in]```

### Example Output

```$ ./obj_dir/Vadder +a=999999 +b=1234```

```
a = 999999
b = 1234
cin = 0
sum = 1001233
cout = 0
Verilog addition result: 1001233
[PASS]
- S i m u l a t i o n   R e p o r t: Verilator 5.024 2024-04-05
- Verilator: end at 10ps; walltime 0.002 s; speed 0.000 s/s
- Verilator: cpu 0.000 s on 1 threads; alloced 57 MB
```
