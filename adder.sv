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


/* generate_shares
*
* parameters:
*	NSHARES (default = 3): Number of random shares to generate.
*	SHARE_LEN (default = 1): Length of each share.
*
* input:
* 	in, input value of length SHARE_LEN.
* output:
* 	shares, NSHARES random shares of length SHARE_LEN.
*
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

	always_comb begin
		
		logic [SHARE_LEN-1:0] final_share = in;

		for (int i = 0; i < NSHARES-1; i++) begin
			shares[i] = (SHARE_LEN)'($urandom_range(0,(2^SHARE_LEN)-1));
			final_share ^= shares[i];
		end
		
		shares[NSHARES-1] = final_share;

	end

endmodule: generate_shares

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


