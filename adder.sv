/*
*
* adder.sv, a ripple carry adder implemented with masked XOR and AND.
*
*    Copyright (C) 2024  Liam Fisher
*
*    This program is free software: you can redistribute it and/or modify
*    it under the terms of the GNU General Public License as published by
*    the Free Software Foundation, either version 3 of the License, or
*    (at your option) any later version.
*
*    This program is distributed in the hope that it will be useful,
*    but WITHOUT ANY WARRANTY; without even the implied warranty of
*    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*    GNU General Public License for more details.
*
*    You should have received a copy of the GNU General Public License
*    along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

/* random_gen
*
* @param SHARE_LEN (default = 1): Length of random values.
* 
* @output out, random number of length SHARE_LEN between 0 and 2^SHARE_LEN - 1
*/
module random_gen
#(
	parameter SHARE_LEN = 1
)
(
	output logic [SHARE_LEN-1:0] out
);

	assign out = (SHARE_LEN)'($urandom_range(0, (2^SHARE_LEN)-1));

endmodule: random_gen


/* generate_shares
*
* @param NSHARES (default = 3): Number of random shares to generate.
* @param SHARE_LEN (default = 1): Length of each share.
*
* @input in, input value of length SHARE_LEN.
*
* @output shares, NSHARES random shares of length SHARE_LEN.
*/
module generate_shares
#(
	parameter NSHARES = 3,
		  SHARE_LEN = 1
)
(
	input logic [SHARE_LEN-1:0] in,
	output logic [SHARE_LEN-1:0] shares[NSHARES-1:0]
);

	logic [SHARE_LEN-1:0] rand_val[NSHARES-1:0];
	genvar i;
	generate
		for (i = 0; i < NSHARES-1; i++) begin : random_num_generation
			random_gen #(SHARE_LEN) gen1 (rand_val[i]);

		end
	endgenerate

	always_comb begin
		logic [SHARE_LEN-1:0] final_share = in;
		for(int i = 0; i < NSHARES-1; i++) begin
			shares[i] = rand_val[i];
			final_share ^= shares[i];
		end
		shares[NSHARES-1] = final_share;
	end
endmodule: generate_shares

/* masked_xor
*
* @param NSHARES (default = 3): Number of random shares to XOR.
* @param SHARE_LEN (default = 1): Length of each share.
*
* @input a, b, logic vectors of SHARE_LEN length to be XOR'd
*
* @output z, logic vector of SHARE_LEN legnth, equal to a XOR b.
*/
module masked_xor
#(
	parameter NSHARES = 3,
		  SHARE_LEN = 1
)
(
        input logic [SHARE_LEN-1:0] a, b,
        output logic [SHARE_LEN-1:0] z
);

	logic [SHARE_LEN-1:0] ashares[NSHARES-1:0], bshares[NSHARES-1:0];

	generate_shares #(NSHARES, SHARE_LEN) gena(a, ashares);
	generate_shares #(NSHARES, SHARE_LEN) genb(b, bshares);
	
	always_comb begin
        	z = 0;
		for(int i = 0; i < NSHARES; i++) begin
			z ^= ashares[i] ^ bshares[i];
		end
	end

endmodule: masked_xor

/* masked_and
*
* @param NSHARES (default = 3): Number of random shares to AND.
* @param SHARE_LEN (default = 1): Length of each share.
*
* @input a, b, logic vectors of SHARE_LEN length to be AND'd
*
* @output z, logic vector of SHARE_LEN legnth, equal to a AND b.
*/
module masked_and
#(
	parameter NSHARES = 3,
		  SHARE_LEN = 1
)

(
        input logic [SHARE_LEN-1:0] a, b,
        output logic [SHARE_LEN-1:0] z

);
	logic [SHARE_LEN-1:0] ashares[NSHARES-1:0], bshares[NSHARES-1:0];

	generate_shares #(NSHARES, SHARE_LEN) gena(a, ashares);
	generate_shares #(NSHARES, SHARE_LEN) genb(b, bshares);

        always_comb begin
		z = 0;

		for(int i = 0; i < NSHARES; i++) begin
			for(int j = 0; j < NSHARES; j++) begin
				z ^= ashares[i] & bshares[j];
			end
		end

	end

endmodule: masked_and

/* masked_full_adder
* Masked full adder designed to function as ripple carry.
*
* @param NSHARES (default = 3): Number of random shares to ADD.
*
* @input a, b, logic wires to be added.
* @input cin, carry in to be added to a and b.
*
* @output sum, logic wire, equal to a XOR b XOR c the sum of a, b, and cin.
* @output cout, logic wire, equal to a AND b XOR a AND c XOR b AND c. The
* carry of a plus b.
*/
module masked_full_adder 
#(
	parameter NSHARES = 3
)
(
	input logic a, b,
	input logic cin,
	output logic sum,
	output logic cout
);

	logic aXORb, axbXORc, carry;

	masked_xor #(NSHARES) xor1(.a(a), .b(b), .z(aXORb));
	masked_xor #(NSHARES) xor2(.a(aXORb), .b(cin), .z(axbXORc));

	assign sum = axbXORc;

	logic aANDb, aANDc, bANDc, abXac, abXacXbc;

	masked_and #(NSHARES) and1(.a(a), .b(b), .z(aANDb));
	masked_and #(NSHARES) and2(.a(a), .b(cin), .z(aANDc));
	masked_and #(NSHARES) and3(.a(b), .b(cin), .z(bANDc));
	masked_xor #(NSHARES) xor3(.a(aANDb), .b(aANDc), .z(abXac));
	masked_xor #(NSHARES) xor4(.a(abXac), .b(bANDc), .z(abXacXbc));

	assign cout = abXacXbc;

endmodule: masked_full_adder

/* masked_rca
* Masked ripple carry adder build of rca masked full adder.
* 
* @param WIDTH (default = 64) Length of input numbers to be added.
* @param NSHARES (default = 3) Number of random shares to ADD.
*
* @input a, b, logic vectors of WIDTH to be added.
* @input cin, carry in to be added to a and b.
*
* @output sum, logic vector of WIDTH, equal to a plus b plus cin.
* @output cout, logic wire. The carry of a plus b.
*/
module masked_rca 
#(
	parameter WIDTH = 64,
		  NSHARES = 3
)
(
	input logic [WIDTH-1:0] a, b,
	input logic cin,
	output logic [WIDTH-1:0] sum,
	output logic cout
);

	logic [WIDTH:0] c;
	assign c[0] = cin;
	
	genvar i;
	generate
		for (i = 0; i < (WIDTH); i++) begin : full_adder_loop
			masked_full_adder #(NSHARES) mfa
			(
				.a(a[i]),
				.b(b[i]),
				.cin(c[i]),
				.sum(sum[i]),
				.cout(c[i+1])
			);
		end
	endgenerate

	assign cout = c[WIDTH];

endmodule: masked_rca

/* top
*
* @input +a=, +b=, +cin=, Values a and b of length "WIDTH" to add,
* plus cin for the carry.
*/
module top;
	parameter WIDTH = 64;
	parameter NSHARES = 3;

	logic [WIDTH-1:0] a, b;
	logic cin;
	logic [WIDTH-1:0] sum;
	logic cout;

	masked_rca #(
		.WIDTH(WIDTH),
		.NSHARES(NSHARES)
	) masked_rca (
	        .a(a),
	        .b(b),
	        .cin(cin),
	        .sum(sum),
        	.cout(cout)
    	);

	initial begin

		$value$plusargs("a=%d", a);
		$value$plusargs("b=%d", b);
		$value$plusargs("cin=%d", cin);

		#10; // wait for adder

		$display("a = %0d\nb = %0d\ncin = %0d\nsum = %0d\ncout = %0d", a, b, cin, sum, cout);
		$display("Verilog addition result: %0d", (a+b+{{(WIDTH-1){1'b0}}, cin}));
		if (a+b+{{(WIDTH-1){1'b0}}, cin} == sum) begin
			$display("[PASS]");
		end else begin
			$display("[FAIL]");
		end
	end

endmodule


