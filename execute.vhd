library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.newcpupkg.all;
use work.newcpucomppkg.all;
-- synthesis translate_off
use work.txt_util.all;
-- synthesis translate_on
entity execute is
  port (
    clk:  in std_logic;
    rst:  in std_logic;
    mem_busy: in std_logic;
    busy: out std_logic;
    -- Input for previous stages
    fdui:  in fetchdata_output_type;
    -- Output for next stages
    euo:  out execute_output_type
  );
end entity execute;

architecture behave of execute is

  signal alu_a_a, alu_a_b: std_logic_vector(31 downto 0);
  signal alu_a_r: unsigned(31 downto 0);
  signal alu_b_a, alu_b_b: std_logic_vector(31 downto 0);
  signal alu_b_r: unsigned(31 downto 0);
  signal alu_ci, alu_co, alu_busy, alu_bo, alu_sign, alu_zero: std_logic;
  signal modify_flags: boolean := true;
  signal select_a_or_register: std_logic;
  signal alu_a_or_z_reg: std_logic_vector(31 downto 0);

  signal er: execute_regs_type;
  signal alu_a0_a_or_gpr: std_logic;
  signal alu_a1_a_or_gpr: std_logic;
  signal alu_b0_a_or_gpr: std_logic;
  signal target_pc: word_type;

begin

  euo.r <= er;
  euo.jump <= '0';
  euo.jumpaddr <= (others => DontCareValue);

  alu_b_b(31 downto 11) <= (others=>'0');
  alu_b_b(10 downto 0) <= fdui.r.drq.alu2_opcode(10 downto 0);

  myaluA: alu_A
    port map (
      clk   => clk,
      rst   => rst,
  
      a     => unsigned(alu_a_a),
      b     => unsigned(alu_a_b),
      o     => alu_a_r,
      op    => fdui.r.drq.alu1_op,
      ci    => er.flag_carry,
      busy  => alu_busy,
      co    => alu_co,
      zero  => alu_zero,
      bo    => alu_bo,
      sign  => alu_sign
    );

  myaluB: alu_B
    port map (
      clk   => clk,
      rst   => rst,
  
      a     => unsigned(alu_b_a),
      b     => unsigned(alu_b_b),
      o     => alu_b_r,
      op    => fdui.r.drq.alu2_op
      --busy  => alu_busy
    );

    alu_a0_a_or_gpr<='1' when fdui.r.drq.alu1_source=ALU1_SOURCE_AR else '0';
    alu_a1_a_or_gpr<='1' when fdui.r.drq.alu1_source=ALU1_SOURCE_RA else '0';
    alu_b0_a_or_gpr<='1' when fdui.r.drq.alu2_source=ALU2_SOURCE_A else '0';

    alua0_a_or_reg: mux32_2
      port map  (
        i0  => std_logic_vector(fdui.rr1),
        i1  => std_logic_vector(er.a),
        sel => alu_a0_a_or_gpr,
        o   => alu_a_a
      );

    alua1_a_or_reg: mux32_2
      port map  (
        i1  => std_logic_vector(er.a),
        i0  =>  std_logic_vector(fdui.rr1),
        sel => alu_a1_a_or_gpr,
        o   => alu_a_b
      );

    process(fdui.r.drq.alu2_source, er.a, fdui.rr2)
    begin
      case fdui.r.drq.alu2_source is
        when ALU2_SOURCE_A => alu_b_a <= std_logic_vector(er.a);
        when ALU2_SOURCE_R => alu_b_a <= std_logic_vector(fdui.rr2);
        when others => alu_b_a<=(others => DontCareValue);
      end case;
    end process;

--    alub0_a_or_reg: mux32_2
--      port map  (
--        i1  => std_logic_vector(er.a),
--        i0  => std_logic_vector(fdui.rr2),
--        sel => alu_b0_a_or_gpr,
--        o   => alu_b_a
--      );

    process(alu_b_r, fdui.r.drq.npc)
    begin
      target_pc <= fdui.r.drq.npc + alu_b_r;
    end process;

    process(sprsel, fdui.r.drq.npc, er.br, er.flags)
    begin
      case sprsel is
        when SPR_NPC =>
        when others =>
          spr <= (others => DontCareValue);
      end case;
    end process;

    process(clk,fdui,er,rst,alu_a_r,alu_b_r,modify_flags,
            alu_co, alu_sign,alu_zero,alu_bo)
      variable ew: execute_regs_type;
      variable busy_int: std_logic;
      constant reg_zero: unsigned(31 downto 0) := (others => '0');
    begin
      ew := er;

      -- For pre-increment and post-increment, we need to swap
      -- the target GPR.
      --if fdui.r.drq.swap_target_reg='1' then
      --  ew.reg2_addr := fdui.r.drq.dra1;
      --else
      --  ew.reg2_addr := fdui.r.drq.dra2;
      --end if;

      --ew.rb2_we :='0';
      ew.valid := fdui.r.drq.valid;

      if mem_busy='1' and fdui.r.drq.memory_access='1' then
        busy_int := '1';
      else
        busy_int := '0';
      end if;

      if fdui.r.drq.valid='1' then
        -- synthesis translate_off
        if rising_edge(clk) then
          report fdui.r.drq.strasm;
        end if;
        -- synthesis translate_on
        -- Writeback for register/memory depends
        -- on which intruction is being exec'ed
        ew.alur1 := alu_a_r(31 downto 0);
        ew.alur2 := alu_b_r(31 downto 0);

        ew.reg_source := fdui.r.drq.reg_source;

        ew.wb_is_data_address := fdui.r.drq.wb_is_data_address;

        case fdui.r.drq.a_source is
          when a_source_alu1 =>
            ew.a := alu_a_r;
          when a_source_alu2 =>
            ew.a := alu_b_r;
          when a_source_br =>
            ew.a := er.br;
          when a_source_spr =>
            ew.a := spr;
          when others =>
        end case;

        if modify_flags then
          ew.flag_carry := alu_co;
          ew.flag_sign  := alu_sign;
          ew.flag_borrow := alu_bo;
          ew.flag_zero := alu_zero;
        end if;

        ew.dreg := fdui.r.drq.dreg;
        ew.regwe := fdui.r.drq.regwe;

        if mem_busy='0' then
          ew.mask := fdui.r.drq.mask;
          ew.data_write := std_logic_vector(alu_a_r);
  
          if fdui.r.drq.prepost='1' then
            ew.data_address := std_logic_vector(alu_b_a);
          else
            ew.data_address := std_logic_vector(alu_b_r);
          end if;
  
          ew.data_access := fdui.r.drq.memory_access;
          ew.data_writeenable := fdui.r.drq.memory_write;
        end if;
      end if;

      busy <= busy_int;

      if rst='1' then
        ew.a := (others => '0');
      end if;

      if rising_edge(clk) then
        er <= ew;
      end if;

    end process;
    
  end behave;
