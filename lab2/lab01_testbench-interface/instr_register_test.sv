/***********************************************************************
 * A SystemVerilog testbench for an instruction register.
 * The course labs will convert this to an object-oriented testbench
 * with constrained random test generation, functional coverage, and
 * a scoreboard for self-verification.
 **********************************************************************/
module instr_register_test
  import instr_register_pkg::*;  // user-defined types are defined in instr_register_pkg.sv


  (input  logic          clk,
   output logic          load_en,
   output logic          reset_n,
   output operand_t      operand_a,
   output operand_t      operand_b,
   output opcode_t       opcode,
   output address_t      write_pointer,
   output address_t      read_pointer,
   input  instruction_t  instruction_word
  );

  timeunit 1ns/1ns;
  parameter RD_NR = 50; // dupa 7, dupa 50, sa ne asiguram + de testat toate cele 9 cazuri intre write_pointer si read_pointer, la 50 sa ne asiguram ca merge overflow
  parameter WR_NR = 50;
  parameter WR_ORDER = 0; // 0 -> inc, 1 -> random, 2 -> dec
  parameter RD_ORDER = 0;
  parameter TEST_NAME = "test";
  instruction_t iw_reg [0:31];
  instruction_t iw_reg_test [0:31]; 

  int seed = 555;
  int pass = 0;
  int fail = 0;

  initial begin
    $display("\n\n***********************************************************");
    $display(    "***  THIS IS A SELF-CHECKING TESTBENCH (YET).  YOU DON'T***");
    $display(    "***  NEED TO VISUALLY VERIFY THAT THE OUTPUT VALUES     ***");
    $display(    "***  MATCH THE INPUT VALUES FOR EACH REGISTER LOCATION  ***");
    $display(    "***********************************************************");

    $display("\nReseting the instruction register...");
    write_pointer  = 5'h00;         // initialize write pointer
    read_pointer   = 5'h1F;         // initialize read pointer
    load_en        = 1'b0;          // initialize load control line
    reset_n       <= 1'b0;          // assert reset_n (active low)
    repeat (2) @(posedge clk) ;     // hold in reset for 2 clock cycles
    reset_n        = 1'b1;          // deassert reset_n (active low)

    $display("\nWriting values to register stack...");
    @(posedge clk) load_en = 1'b1;  // enable writing to register
    // repeat (3) begin - 11.03.2024 Cristea Florinela
    repeat (WR_NR) begin
      @(posedge clk) randomize_transaction;
      @(negedge clk) print_transaction;
      save_data;
    end
    @(posedge clk) load_en = 1'b0;  // turn-off writing to register

    // read back and display same three register locations
    $display("\nReading back the same register locations written...");
    // for (int i=0; i<=2; i++) begin - 11.03.2024 Cristea Florinela
    for (int i=0; i<RD_NR; i++) begin
      // later labs will replace this loop with iterating through a
      // scoreboard to determine which addresses were written and
      // the expected values to be read back
      //@(posedge clk) read_pointer = i;
      @(posedge clk) case (RD_ORDER)
        0: read_pointer = i;
        1: read_pointer = ($unsigned($random)%32);
        2: read_pointer = 31 - (i % 32);
     endcase 
      @(negedge clk) print_results;
      //iw_reg_test[read_pointer] = instruction_word;
      check_result;
    end

    final_report;

    //write_file;

    @(posedge clk) ;
    $display("\n***********************************************************");
    $display(  "***  THIS IS A SELF-CHECKING TESTBENCH (YET).  YOU DON'T***");
    $display(  "***  NEED TO VISUALLY VERIFY THAT THE OUTPUT VALUES     ***");
    $display(  "***  MATCH THE INPUT VALUES FOR EACH REGISTER LOCATION  ***");
    $display(  "***********************************************************\n");
    $finish;
  end

  function void randomize_transaction;
    // A later lab will replace this function with SystemVerilog
    // constrained random values
    //
    // The stactic temp variable is required in order to write to fixed
    // addresses of 0, 1 and 2.  This will be replaceed with randomizeed
    // write_pointer values in a later lab
    //
    static int temp = 0; // static e alocata o singura data (locatie de memorie)
    static int temp2 = 31;
    operand_a     <= $random(seed)%16;                 // between -15 and 15 random genereaza pe 32 de biti
    operand_b     <= $unsigned($random)%16;            // between 0 and 15 unsigned - converteste - in +
    opcode        <= opcode_t'($unsigned($random)%8);  // between 0 and 7, cast to opcode_t type
    // write_pointer <= temp++;
    case (WR_ORDER)
      0: write_pointer <= temp++;
      1: write_pointer <= ($unsigned($random)%32);
      2: write_pointer <= temp2--;
    endcase
  endfunction: randomize_transaction

  function void print_transaction;
    $display("Writing to register location %0d: ", write_pointer);
    $display("  opcode = %0d (%s)", opcode, opcode.name);
    $display("  operand_a = %0d",   operand_a);
    $display("  operand_b = %0d\n", operand_b);
  endfunction: print_transaction

  function void print_results;
    $display("Read from register location %0d: ", read_pointer);
    $display("  opcode = %0d (%s)", instruction_word.opc, instruction_word.opc.name);
    $display("  operand_a = %0d",   instruction_word.op_a);
    $display("  operand_b = %0d\n", instruction_word.op_b);
    $display("  result = %0d\n", instruction_word.result);
  endfunction: print_results

 function void check_result;
    custom_result_t result;

    if (iw_reg_test[read_pointer].opc == ZERO)
        result = {64{1'b0}};
    else if (iw_reg_test[read_pointer].opc == PASSA)
        result = iw_reg_test[read_pointer].op_a;
    else if (iw_reg_test[read_pointer].opc == PASSB)
        result = iw_reg_test[read_pointer].op_b;
    else if (iw_reg_test[read_pointer].opc == ADD)
        result = iw_reg_test[read_pointer].op_a + iw_reg_test[read_pointer].op_b;
    else if (iw_reg_test[read_pointer].opc == SUB)
        result = iw_reg_test[read_pointer].op_a - iw_reg_test[read_pointer].op_b;
    else if (iw_reg_test[read_pointer].opc == MULT)
        result = iw_reg_test[read_pointer].op_a * iw_reg_test[read_pointer].op_b;
    else if (iw_reg_test[read_pointer].opc == DIV) begin
        if (iw_reg_test[read_pointer].op_b === {32{1'b0}})
            result = 'b0;
        else
            result = iw_reg_test[read_pointer].op_a / iw_reg_test[read_pointer].op_b;
    end
    else if (iw_reg_test[read_pointer].opc == MOD) // tratat si cazul cu 0, la fel ca la div
        result = iw_reg_test[read_pointer].op_a % iw_reg_test[read_pointer].op_b;

    $display("\nCheck Result:");
    $display("  read_pointer = %0d", read_pointer);
    $display("  opcode = %0d (%s)", iw_reg_test[read_pointer].opc, iw_reg_test[read_pointer].opc.name);
    $display("  operand_a = %0d",   iw_reg_test[read_pointer].op_a);
    $display("  operand_b = %0d", iw_reg_test[read_pointer].op_b);

    $display("\nCalculated Test Result: %0d\n", result);

    if(iw_reg_test[read_pointer].opc === instruction_word.opc) 
      $display("Opcode are matching!\n");
    else
      $display("Opcode are not matching!\n");

    if(iw_reg_test[read_pointer].op_a === instruction_word.op_a) 
        $display("Operand_a are matching!\n");
    else
      $display("Operand_a are not matching!\n");

    if(iw_reg_test[read_pointer].op_b === instruction_word.op_b) 
          $display("Operand_b are matching!\n");
    else
      $display("Operand_b are not matching!\n");
   
    if (result === instruction_word.result) 
        $display("Results are matching!\n");
    else 
        $display("Results are not matching!\n");

    if (iw_reg_test[read_pointer].opc === instruction_word.opc && iw_reg_test[read_pointer].op_a === instruction_word.op_a && iw_reg_test[read_pointer].op_b === instruction_word.op_b && result === instruction_word.result) begin
      $display("TEST PASS\n");
      pass = pass + 1; 
    end
    else begin
      $display("TEST FAIL\n");
      fail = fail + 1; 
    end
endfunction: check_result

function void save_data;
  iw_reg_test[write_pointer] = {opcode, operand_a, operand_b, 'b0};
endfunction: save_data


function void final_report;
    real pass_percentage;
    real fail_percentage;
  
    pass_percentage = (pass * 100.0) / WR_NR;
    fail_percentage = (fail * 100.0) / WR_NR;
  
    $display("Total number of tests: %0d", WR_NR);
  
    $display("Number of failed tests: %0d", fail);
  
    $display("Number of passed tests: %0d", pass);

    $display("Pass percentage: %0.2f%%", pass_percentage);
  
    $display("Fail percentage: %0.2f%%", fail_percentage);

endfunction: final_report





endmodule: instr_register_test