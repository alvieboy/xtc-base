------------------------------------------------------
-- FSM for a SDRAM controller
--
-- Version 0.1 - Ready to simulate
--
-- Authors: Mike Field (hamster@snap.net.nz)
--          Alvaro Lopes (alvieboy@alvie.com)
--
-- Feel free to use it however you would like, but
-- just drop us an email to say thanks.
-------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

library unisim;
use unisim.vcomponents.all;

entity sdram_controller is
  generic (
    HIGH_BIT: integer := 22;
    MHZ: integer := 96;
    REFRESH_CYCLES: integer := 4096;
    ADDRESS_BITS: integer := 12
  );
  PORT (
      clock_100:  in std_logic;
      clock_100_delayed_3ns: in std_logic;
      rst: in std_logic;

   -- Signals to/from the SDRAM chip
   DRAM_ADDR   : OUT   STD_LOGIC_VECTOR (ADDRESS_BITS-1 downto 0);
   DRAM_BA      : OUT   STD_LOGIC_VECTOR (1 downto 0);
   DRAM_CAS_N   : OUT   STD_LOGIC;
   DRAM_CKE      : OUT   STD_LOGIC;
   DRAM_CLK      : OUT   STD_LOGIC;
   DRAM_CS_N   : OUT   STD_LOGIC;
   DRAM_DQ      : INOUT STD_LOGIC_VECTOR(15 downto 0);
   DRAM_DQM      : OUT   STD_LOGIC_VECTOR(1 downto 0);
   DRAM_RAS_N   : OUT   STD_LOGIC;
   DRAM_WE_N    : OUT   STD_LOGIC;

   pending: out std_logic;

   --- Inputs from rest of the system
   address      : IN     STD_LOGIC_VECTOR (HIGH_BIT downto 2);
   req_read      : IN     STD_LOGIC;
   req_write   : IN     STD_LOGIC;
   data_out      : OUT     STD_LOGIC_VECTOR (31 downto 0);
   data_out_valid : OUT     STD_LOGIC;
   data_in      : IN     STD_LOGIC_VECTOR (31 downto 0);
   data_mask    : IN     STD_LOGIC_VECTOR (3 downto 0);
   tag_in       : in std_logic_vector(31 downto 0);
   tag_out       : out std_logic_vector(31 downto 0)
   );
end entity;
   
   
architecture rtl of sdram_controller is

   type reg is record
      address       : std_logic_vector(11 downto 0);
      bank          : std_logic_vector( 1 downto 0);
      init_counter  : std_logic_vector(14 downto 0);
      rf_counter    : integer;
      rf_pending    : std_logic;
      rd_pending    : std_logic;
      wr_pending    : std_logic;
      act_row       : std_logic_vector(11 downto 0);
      data_out_low  : std_logic_vector(15 downto 0);
      req_addr_q    : std_logic_vector(22 downto 2);
      req_data_write: std_logic_vector(31 downto 0);
      req_mask      : std_logic_vector(3 downto 0);
      data_out_valid: std_logic;
      dq_masks      : std_logic_vector(1 downto 0);
      tristate      : std_logic;
      tag_in        : std_logic_vector(31 downto 0);
      tag_out       : std_logic_vector(31 downto 0);
      tagq          : std_logic_vector(31 downto 0);
      tagqq         : std_logic_vector(31 downto 0);
      data_write    : std_logic_vector(15 downto 0);

   end record;

   signal r : reg;
   signal n : reg;

   signal rstate       : std_logic_vector(8 downto 0);
   signal nstate       : std_logic_vector(8 downto 0);
   --signal data_write  : std_logic_vector(15 downto 0);
   --signal ndata_write  : std_logic_vector(15 downto 0);

   
   -- Vectors for each SDRAM 'command'
   --- CS_N, RAS_N, CAS_N, WE_N 
   constant cmd_nop   : std_logic_vector(3 downto 0) := "0111";
   constant cmd_read  : std_logic_vector(3 downto 0) := "0101";   -- Must be sure A10 is low.
   constant cmd_write : std_logic_vector(3 downto 0) := "0100";
   constant cmd_act   : std_logic_vector(3 downto 0) := "0011";
   constant cmd_pre   : std_logic_vector(3 downto 0) := "0010";  -- Must set A10 to '1'.
   constant cmd_ref   : std_logic_vector(3 downto 0) := "0001";
   constant cmd_mrs   : std_logic_vector(3 downto 0) := "0000"; -- Mode register set

   -- State assignments
   constant s_init_nop_id: std_logic_vector(4 downto 0) := "00000";

   constant s_init_nop  : std_logic_vector(8 downto 0) := s_init_nop_id & cmd_nop;
   constant s_init_pre  : std_logic_vector(8 downto 0) := s_init_nop_id  & cmd_pre;
   constant s_init_ref  : std_logic_vector(8 downto 0) := s_init_nop_id  & cmd_ref;
   constant s_init_mrs  : std_logic_vector(8 downto 0) := s_init_nop_id  & cmd_mrs;

   constant s_idle_id: std_logic_vector(4 downto 0) := "00001";
   constant s_idle  : std_logic_vector(8 downto 0) := s_idle_id & cmd_nop;

   constant s_rf0_id: std_logic_vector(4 downto 0) := "00010";
   constant s_rf0   : std_logic_vector(8 downto 0) := s_rf0_id & cmd_ref;

   constant s_rf1_id: std_logic_vector(4 downto 0) := "00011";
   constant s_rf1   : std_logic_vector(8 downto 0) := "00011" & cmd_nop;

   constant s_rf2_id: std_logic_vector(4 downto 0) := "00100";
   constant s_rf2   : std_logic_vector(8 downto 0) := "00100" & cmd_nop;

   constant s_rf3_id: std_logic_vector(4 downto 0) := "00101";
   constant s_rf3   : std_logic_vector(8 downto 0) := "00101" & cmd_nop;

   constant s_rf4_id: std_logic_vector(4 downto 0) := "00110";
   constant s_rf4   : std_logic_vector(8 downto 0) := "00110" & cmd_nop;

   constant s_rf5_id: std_logic_vector(4 downto 0) := "00111";
   constant s_rf5   : std_logic_vector(8 downto 0) := "00111" & cmd_nop;


   constant s_ra0_id: std_logic_vector(4 downto 0) := "01000";
   constant s_ra0   : std_logic_vector(8 downto 0) := "01000" & cmd_act;

   constant s_ra1_id: std_logic_vector(4 downto 0) := "01001";
   constant s_ra1   : std_logic_vector(8 downto 0) := "01001" & cmd_nop;

   constant s_ra2_id: std_logic_vector(4 downto 0) := "01010";
   constant s_ra2   : std_logic_vector(8 downto 0) := "01010" & cmd_nop;


   constant s_dr0_id: std_logic_vector(4 downto 0) := "01011";
   constant s_dr0   : std_logic_vector(8 downto 0) := "01011" & cmd_pre;

   constant s_dr1_id: std_logic_vector(4 downto 0) := "01100";
   constant s_dr1   : std_logic_vector(8 downto 0) := "01100" & cmd_nop;

   constant s_wr0_id: std_logic_vector(4 downto 0) := "01101";
   constant s_wr0   : std_logic_vector(8 downto 0) := "01101" & cmd_write;

   constant s_wr1_id: std_logic_vector(4 downto 0) := "01110";
   constant s_wr1   : std_logic_vector(8 downto 0) := "01110" & cmd_nop;

   constant s_wr2_id: std_logic_vector(4 downto 0) := "01111";
   constant s_wr2   : std_logic_vector(8 downto 0) := "01111" & cmd_nop;

   constant s_wr3_id: std_logic_vector(4 downto 0) := "10000";
   constant s_wr3   : std_logic_vector(8 downto 0) := "10000" & cmd_write;


   constant s_rd0_id: std_logic_vector(4 downto 0) := "10001";
   constant s_rd0   : std_logic_vector(8 downto 0) := "10001" & cmd_read;

   constant s_rd1_id: std_logic_vector(4 downto 0) := "10010";
   constant s_rd1   : std_logic_vector(8 downto 0) := "10010" & cmd_read;

   constant s_rd2_id: std_logic_vector(4 downto 0) := "10011";
   constant s_rd2   : std_logic_vector(8 downto 0) := "10011" & cmd_nop;

   constant s_rd3_id: std_logic_vector(4 downto 0) := "10100";
   constant s_rd3   : std_logic_vector(8 downto 0) := "10100" & cmd_read;

   constant s_rd4_id: std_logic_vector(4 downto 0) := "10101";
   constant s_rd4   : std_logic_vector(8 downto 0) := "10101" & cmd_read;

   constant s_rd5_id: std_logic_vector(4 downto 0) := "10110";
   constant s_rd5   : std_logic_vector(8 downto 0) := "10110" & cmd_read;

   constant s_rd6_id: std_logic_vector(4 downto 0) := "10111";
   constant s_rd6   : std_logic_vector(8 downto 0) := "10111" & cmd_nop;

   constant s_rd7_id: std_logic_vector(4 downto 0) := "11000";
   constant s_rd7   : std_logic_vector(8 downto 0) := "11000" & cmd_nop;

   constant s_rd8_id: std_logic_vector(4 downto 0) := "11001";
   constant s_rd8   : std_logic_vector(8 downto 0) := "11001" & cmd_nop;

   constant s_rd9_id: std_logic_vector(4 downto 0) := "11011";
   constant s_rd9   : std_logic_vector(8 downto 0) := "11011" & cmd_nop;


   constant s_drdr0_id: std_logic_vector(4 downto 0) := "11101";
   constant s_drdr0 : std_logic_vector(8 downto 0) := "11101" & cmd_pre;

   constant s_drdr1_id: std_logic_vector(4 downto 0) := "11110";
   constant s_drdr1 : std_logic_vector(8 downto 0) := "11110" & cmd_nop;

   constant s_drdr2_id: std_logic_vector(4 downto 0) := "11111";
   constant s_drdr2 : std_logic_vector(8 downto 0) := "11111" & cmd_nop;

    constant CL: integer range 2 to 3 := 2;

  -- DEBUG only
    type statetype is (IDLE,RF0,RF1,RF2,RF3,RF4,RF5,
    RA0,RA1,RA2,DR0,DR1,WR0,WR1,WR2,WR3,
    RD0,RD1,RD2,RD3,RD4,RD5,RD6,RD7,RD8,RD9,DRDR0,DRDR1,DRDR2);

    signal dbgstate: statetype;
  -- END DEBUG only


   signal addr_row : std_logic_vector(11 downto 0); -- 12
   signal addr_bank: std_logic_vector(1 downto 0);  -- 2
   signal addr_col : std_logic_vector(7 downto 0);  -- 8  = 22 bits.

   constant COLUMN_HIGH: integer := HIGH_BIT - addr_row'LENGTH - addr_bank'LENGTH - 1; -- last 1 means 16 bit width


  signal captured : std_logic_vector(15 downto 0);

  constant tOPD: time := 2.1 ns;
  constant tHZ: time := 8 ns;

  signal dram_dq_dly : std_logic_vector(15 downto 0);

  -- Debug only
   signal debug_cmd: std_logic_vector(3 downto 0);

   signal not_clock_100_delayed_3ns: std_logic;

  constant RELOAD: integer := (((64000000/REFRESH_CYCLES)*MHZ)/1000) - 10;

  attribute IOB: string;

  signal i_DRAM_CS_N: std_logic;
  attribute IOB of i_DRAM_CS_N: signal is "true";

  signal i_DRAM_RAS_N: std_logic;
  attribute IOB of i_DRAM_RAS_N: signal is "true";

  signal i_DRAM_CAS_N: std_logic;
  attribute IOB of i_DRAM_CAS_N: signal is "true";

  signal i_DRAM_WE_N: std_logic;
  attribute IOB of i_DRAM_WE_N: signal is "true";

  signal i_DRAM_ADDR: std_logic_vector(ADDRESS_BITS-1 downto 0);
  attribute IOB of i_DRAM_ADDR: signal is "true";

  signal i_DRAM_BA: std_logic_vector(1 downto 0);
  attribute IOB of i_DRAM_BA: signal is "true";

  signal i_DRAM_DQM: std_logic_vector(1 downto 0);
  attribute IOB of i_DRAM_DQM: signal is "true";

  --attribute IOB of r.data_write: signal is "true";
  attribute IOB of captured: signal is "true";

  signal i_DRAM_CLK: std_logic;

  attribute fsm_encoding: string;
  attribute fsm_encoding of nstate: signal is "user";
  attribute fsm_encoding of rstate: signal is "user";

begin
  -- Each of the x16s 16,777,216-bit banks is organized as
  -- 4,096 rows by 256 columns by 16 bits.
  -- 12 bits rows, 8 bit columns, 2 bit banks, two words. 22 bits + 1
  --
  --                                22211111111110000000000
  --                                21098765432109876543210
  --                                -----------------------
  --                                rrrrrrrrrrrrbbcccccccix
  --
   debug_cmd <= rstate(3 downto 0);

   -- Addressing is in 32 bit words - twice that of the DRAM width,
   -- so each burst of four access two system words.
   --addr_row  <= address(23 downto 11);
   --addr_bank <= address(10 downto 9);
   process(r.req_addr_q)
   begin
    addr_bank <= --r.req_addr_q(HIGH_BIT downto (HIGH_BIT-addr_bank'LENGTH)+1);
             -- (24-2) downto (24-2 - 2 - 13 - 1)
             --  22 downto 6
                 r.req_addr_q(10 downto 9);
    addr_row  <= ----r.req_addr_q(HIGH_BIT-addr_bank'LENGTH  downto COLUMN_HIGH+2);
                 --r.req_addr_q(ADDRESS_BITS-1+9 downto 9);
                r.req_addr_q(22 downto 11);
    --addr_col  <= (others => '0');

    addr_col  <= --r.req_addr_q(COLUMN_HIGH+1 downto  2) & "0";
                 r.req_addr_q(8 downto 2) & "0";
   end process;

  not_clock_100_delayed_3ns <= not clock_100_delayed_3ns;

  clock: ODDR2
    generic map (
      DDR_ALIGNMENT => "NONE",  
      INIT          => '0',
      SRTYPE        => "ASYNC") 
    port map (
      D0 => '1',
      D1 => '0',
      Q => i_DRAM_CLK,
      C0 => clock_100_delayed_3ns,
      C1 => not_clock_100_delayed_3ns,
      CE => '1',
      R => '0',
      S => '0'
    );

   DRAM_CKE       <= '1';

   DRAM_CLK <= transport i_DRAM_CLK after tOPD;

   i_DRAM_CS_N    <= transport rstate(3)  after tOPD;
   DRAM_CS_N      <= i_DRAM_CS_N;

   i_DRAM_RAS_N   <= transport rstate(2)  after tOPD;
   DRAM_RAS_N     <= i_DRAM_RAS_N;

   i_DRAM_CAS_N   <= transport rstate(1)  after tOPD;
   DRAM_CAS_N     <= i_DRAM_CAS_N;

   i_DRAM_WE_N    <= transport rstate(0)  after tOPD;
   DRAM_WE_N      <= i_DRAM_WE_N;

   i_DRAM_ADDR    <= transport r.address  after tOPD;
   DRAM_ADDR      <= i_DRAM_ADDR;

   i_DRAM_BA      <= transport r.bank  after tOPD;
   DRAM_BA        <= i_DRAM_BA;

   i_DRAM_DQM     <= transport r.dq_masks  after tOPD;
   DRAM_DQM       <= i_DRAM_DQM;

   DATA_OUT       <= r.data_out_low & captured;--r.data_out_low & captured;
   data_out_valid <= r.data_out_valid;

   DRAM_DQ    <= (others => 'Z') after tHZ when r.tristate='1' else r.data_write;

   pending <= '1' when r.wr_pending='1' or r.rd_pending='1' else '0';

   tag_out <= r.tag_out;

   process (r, rstate, address, req_read, req_write,
        addr_row, addr_bank, addr_col, data_in, captured, tag_in, data_mask)

    procedure shifttags is
    begin
       -- Shift tags.
      n.tagq     <= r.tag_in;
      n.tagqq    <=r.tagq;
      if CL=2 then
        n.tag_out  <= r.tagq;
      else
        n.tag_out  <= r.tagqq;
      end if;
    end procedure;

   begin
      -- copy the existing values
      n <= r;
      nstate <= rstate;

      if req_read = '1' then
         if r.rd_pending='0' and r.wr_pending='0' then
           n.rd_pending <= '1';
           n.req_addr_q <= address(22 downto 2);
           n.req_data_write <= (others => 'X');
           n.req_mask <= (others => 'X');
           n.tag_in <= tag_in;
         end if;
      end if;
      
      if req_write = '1' then
         if r.wr_pending='0' and r.rd_pending='0' then
           n.wr_pending <= '1';
           n.req_addr_q <= address(22 downto 2);
           n.req_data_write <= data_in;
           n.req_mask <= data_mask;
           n.tag_in <= tag_in;
         end if;
      end if;
      
      n.dq_masks     <= "11";
      
      -- first off, do we need to perform a refresh cycle ASAP?
      if r.rf_counter = RELOAD then -- 781 = 64,000,000ns / 8192 / 10ns
         n.rf_counter <= 0;
         n.rf_pending <= '1';
      else
         -- only start looking for refreshes outside of the initialisation state.
         if not(rstate(8 downto 4) = s_init_nop(8 downto 4)) then
            n.rf_counter <= r.rf_counter + 1;
         end if;
      end if;
      
      -- Set the data bus into HIZ, high and low bytes masked
      --DRAM_DQ    <= (others => 'Z');
      n.tristate <= '0';

      n.init_counter <= r.init_counter-1;

      --ndata_write <= (others => DontCareValue);

      n.data_out_valid <= '0'; -- alvie- here, no ?

      -- Process the FSM
      case rstate(8 downto 4) is
         when s_init_nop_id => --s_init_nop(8 downto 4) =>
            nstate     <= s_init_nop;
            dbgstate<= IDLE;
            n.address <= (others => 'X');
            n.bank    <= (others => '0');
            --n.act_ba  <= (others => '0');
            n.rf_counter   <= 0;
            -- n.data_out_valid <= '1'; -- alvie- not here
            
            -- T-130, precharge all banks.
            if r.init_counter = "000000010000010" then
               nstate     <= s_init_pre;
               n.address(10)   <= '1';
            end if;

            -- T-127, T-111, T-95, T-79, T-63, T-47, T-31, T-15, the 8 refreshes
            
            if r.init_counter(14 downto 7) = 0 and r.init_counter(3 downto 0) = 15 then
               nstate     <= s_init_ref;
            end if;
            
            -- T-3, the load mode register 
            if r.init_counter = 3 then
               nstate     <= s_init_mrs;
                           -- Mode register is as follows:
                           -- resvd   wr_b   OpMd   CAS=2   Seq   bust=1
               n.address   <= "00" & "0" & "00" & "010" & "0" & "000";
                           -- resvd
               n.bank      <= "00";
            end if;

            -- T-1 The switch to the FSM (first command will be a NOP
            if r.init_counter = 1 then
               nstate          <= s_idle;
            end if;

         ------------------------------
         -- The Idle section
         ------------------------------
         when s_idle_id =>
            nstate <= s_idle;
            dbgstate<= IDLE;
            -- do we have to activate a row?
            if r.rd_pending = '1' or r.wr_pending = '1' then
               nstate        <= s_ra0;
            end if;

            n.address     <= addr_row;
            n.act_row    <=  addr_row;
            n.bank       <=  addr_bank;

            -- refreshes take priority over everything
            if r.rf_pending = '1' then
               nstate        <= s_rf0;
            end if;

            n.rf_pending <= '0';
         ------------------------------
         -- Row activation
         -- s_ra2 is also the "idle with active row" state and provides
         -- a resting point between operations on the same row
         ------------------------------
         when s_ra0_id =>
            nstate        <= s_ra1;
            dbgstate<= RA0;
         when s_ra1_id =>
            dbgstate<= RA1;
            nstate        <= s_ra2;


         when s_ra2_id=>
            dbgstate<= RA2;
            -- we can stay in this state until we have something to do
            nstate       <= s_ra2;
            n.tristate<='0';
            n.address <= (others => 'X');
            if r.rf_pending = '1' then
                nstate     <= s_dr0;
                n.address(10) <= '1';
            else

            -- If there is a read pending, deactivate the row
            if r.rd_pending = '1' or r.wr_pending = '1' then
               nstate     <= s_dr0;
               n.address(10) <= '1';
            end if;
            
            -- unless we have a read to perform on the same row? do that instead
            if r.rd_pending = '1' and r.act_row = addr_row and addr_bank=r.bank then
               nstate     <= s_rd0;
               n.address <= (others => '0');
               n.address(addr_col'HIGH downto 0) <= addr_col;
               n.bank    <= addr_bank;
               --n.act_ba    <= addr_bank;
               n.dq_masks <= "00";
               n.rd_pending <= '0';
               n.data_write <= (others => 'X');

               -- Shift tags.
               shifttags;

            end if;
            
            -- unless we have a write on the same row? writes take priroty over reads
            if r.wr_pending = '1' and r.act_row = addr_row and addr_bank=r.bank then
               nstate     <= s_wr0;
               n.address <= (others => '0');
               n.address(addr_col'HIGH downto 0) <= addr_col;
               n.data_write <= r.req_data_write(31 downto 16);
               n.bank    <= addr_bank;
               --n.act_ba    <= addr_bank;
               n.dq_masks<= not r.req_mask(3 downto 2);
               n.wr_pending <= '0';

               -- Shift tags.
               shifttags;
            end if;
            
            
            end if;
            --   nstate     <= s_dr0;
            --   n.address(10) <= '1';
            --   n.rd_pending <= r.rd_pending;
            --   n.wr_pending <= r.wr_pending;
               --n.tristate <= '0';
            --end if;
            
         ------------------------------------------------------
         -- Deactivate the current row and return to idle state
         ------------------------------------------------------
         when s_dr0_id =>
            dbgstate<= DR0;
            n.address <= (others => 'X');
            nstate <= s_dr1;
         when s_dr1_id =>
            dbgstate<= DR1;
            n.address <= (others => 'X');
            nstate <= s_idle;

         ------------------------------
         -- The Refresh section
         ------------------------------
         when s_rf0_id =>
            dbgstate<= RF0;
            n.address <= (others => 'X');
            nstate <= s_rf1;
         when s_rf1_id =>
            dbgstate<= RF1;
            n.address <= (others => 'X');
            nstate <= s_rf2;
         when s_rf2_id =>
            dbgstate<= RF2;
            n.address <= (others => 'X');
            nstate <= s_rf3;
         when s_rf3_id =>
            nstate <= s_rf4;
            n.address <= (others => 'X');
            dbgstate<= RF3;
         when s_rf4_id =>
            nstate <= s_rf5;
            n.address <= (others => 'X');
            dbgstate<= RF4;
         when s_rf5_id =>
            nstate <= s_idle;
            dbgstate<= RF5;
            n.address <= (others => 'X');
         ------------------------------
         -- The Write section
         ------------------------------
         when s_wr0_id =>
            nstate    <= s_wr3;
            n.bank    <= addr_bank;
            n.address(0) <= '1';
            n.data_write <= r.req_data_write(15 downto 0);--data_in(31 downto 16);
            --DRAM_DQ <= rdata_write;
            n.dq_masks <= not r.req_mask(1 downto 0);
            n.tristate <= '0';
            shifttags;
            dbgstate<= WR0;

         when s_wr1_id => null;
            dbgstate<= WR1;
         when s_wr2_id =>
            dbgstate<= WR2;
               nstate       <= s_dr0;
               n.address(10) <= '1';


         when s_wr3_id =>
            dbgstate<= WR3;
            -- Default to the idle+row active state
            nstate     <= s_ra2;
            --DRAM_DQ <= rdata_write;
            n.data_out_valid<='1'; -- alvie- ack write
            shifttags;
            --n.tag_out <= r.tagq;
            n.tristate <= '0';
            n.dq_masks<= "11";
            
            -- If there is a read or write then deactivate the row
            if r.rd_pending = '1' or r.wr_pending = '1' then
               nstate         <= s_wr2;
               --n.address(10) <= '1';
            end if;

            n.address <= (others => 'X');

            -- But if there is a read pending in the same row, do that
            if r.rd_pending = '1' and r.act_row = addr_row and r.bank = addr_bank then
               nstate     <= s_rd0;
               n.address <= (others => '0');
               n.address(addr_col'HIGH downto 0) <= addr_col;
               n.bank    <= addr_bank;
               n.dq_masks <= "00";
               n.rd_pending <= '0';
            end if;

            -- unless there is a write pending in the same row, do that
            if r.wr_pending = '1' and r.act_row = addr_row and r.bank = addr_bank then
               nstate     <= s_wr0;
               n.address <= (others => '0');
               n.address(addr_col'HIGH downto 0) <= addr_col;
               n.bank    <= addr_bank;
               n.data_write <= r.req_data_write(31 downto 16);
               n.dq_masks<= not r.req_mask(3 downto 2);
               n.wr_pending <= '0';
            end if;
            shifttags;

            -- But always try and refresh if one is pending!
            if r.rf_pending = '1' then
               nstate       <= s_wr2; --dr0;
               n.wr_pending <= r.wr_pending;
               n.rd_pending <= r.rd_pending;
               --n.address(10) <= '1';
            end if;
         
         ------------------------------
         -- The Read section
         ------------------------------
         when s_rd0_id =>       -- 10001
          dbgstate<= RD0;
            nstate <= s_rd1;
            n.tristate<='1';
            n.dq_masks <= "00";
            n.address(0)<='1';

         when s_rd1_id =>      -- 10010
            dbgstate<= RD1;
            if CL=3 then
              nstate <= s_rd2;
            else
              nstate <= s_rd6;
            end if;
            n.dq_masks <= "00";
            n.tristate<='1';

            n.address <= (others => 'X');

            if r.rd_pending = '1' and r.act_row = addr_row and r.bank=addr_bank then

              nstate <= s_rd3;  -- Another request came, and we can pipeline -
              n.address <= (others => '0');
              n.address(addr_col'HIGH downto 0) <= addr_col;
              n.bank    <= addr_bank;
              n.dq_masks<= "00";
              n.rd_pending <= '0';
              n.data_write <= (others => 'X');
              --n.tagq <= r.tag_in;
              --n.tagqq<=r.tagq;
              --n.tag_out <= r.tag_in;

            end if;

            -- Shift tags.
            shifttags;

            -- Update output tag immediatly
            --n.tag_out <= r.tagq;

         when s_rd2_id =>       -- 10011
            dbgstate<= RD2;
            nstate <= s_rd7;
            n.dq_masks <= "00";
            n.tristate<='1';


         when s_rd3_id =>       -- 10100
            dbgstate<= RD3;
            nstate <= s_rd4;
            n.dq_masks <= "00";
            n.address(0) <= '1';
            n.tristate<='1';
            if CL=2 then
              n.data_out_low <= captured;
              n.data_out_valid <= '1';
            end if;


            -- Data is still not ready...

         when s_rd4_id =>     -- 10101
            dbgstate<= RD4;
            nstate <= s_rd5;
            n.dq_masks <= "00";
            n.tristate<='1';
            n.address <= (others => 'X');

            if r.rd_pending = '1' and r.act_row = addr_row and r.bank=addr_bank then
              nstate <= s_rd5;  -- Another request came, and we can pipeline -
              
              n.address <= (others => '0');
              n.address(addr_col'HIGH downto 0) <= addr_col;
              n.bank    <= addr_bank;
              n.dq_masks<= "00";
              n.rd_pending <= '0';
              n.data_write <= (others => 'X');
              --n.tagq <= r.tag_in;
              --n.tagqq<=r.tagq;
              --n.tag_out <= r.tag_in;

            else
              if CL=3 then
                nstate <= s_rd6; -- NOTE: not correct
              else
                nstate <= s_rd6;
              end if;
            end if;
            -- Shift tags.
            shifttags;

            --if r.rf_pending = '1' then
            --   nstate <= s_drdr0;
            --   n.address(10) <= '1';
            --   n.rd_pending <= r.rd_pending; -- Keep request
            --end if;

            if CL=3 then
              n.data_out_low <= captured;
              n.data_out_valid <= '1';
            end if;

            --n.tag_out <= r.tagqq;


         when s_rd5_id =>
            dbgstate<=RD5;
               -- If a refresh is pending then always deactivate the row
            --if r.rf_pending = '1' then
            --   nstate <= s_drdr0;
            --   n.address(10) <= '1';
            --end if;

            n.address(0) <= '1';
            nstate <= s_rd4;  -- Another request came, and we can pipeline -
            n.dq_masks <= "00";
            n.tristate<='1';

            if CL=2 then
              n.data_out_low <= captured;
              n.data_out_valid <= '1';
            end if;

         when s_rd6_id =>
            dbgstate<= RD6;
            nstate <= s_rd7;
            n.dq_masks<= "00";
            n.tristate<='1';
            n.address <= (others => 'X');

            if CL=2 then
              n.data_out_low <= captured;
              n.data_out_valid <= '1';
              nstate <= s_ra2;
              --shifttags;
            end if;


         when s_rd7_id =>
            dbgstate<= RD7;
            nstate <= s_ra2;
            if CL=3 then
              n.data_out_low <= captured;
              n.data_out_valid <= '1';
            end if;
            n.address <= (others => 'X');

            shifttags;
            --n.tag_out <= r.tagq;
            --n.tag_out <= r.tag_in;

            n.tristate<='1';

         when s_rd8_id => dbgstate<=RD8;

         when s_rd9_id => dbgstate<= RD9;

         -- The Deactivate row during read section
         ------------------------------
         when s_drdr0_id =>
            dbgstate<= DRDR0;
            n.address <= (others => 'X');
            nstate <= s_drdr1;
         when s_drdr1_id =>
            dbgstate<= DRDR1;
            n.address <= (others => 'X');
            nstate <= s_drdr2;
            n.data_out_low <= captured;
            n.data_out_valid <= '1';
            shifttags;
            --n.tag_out <= r.tag_in;

         when s_drdr2_id =>
            dbgstate<= DRDR2;
            nstate <= s_idle;

            if r.rf_pending = '1' then
               nstate <= s_rf0;
            end if;

            n.address <= (others => 'X');
            
            if r.rd_pending = '1' or r.wr_pending = '1' then
               nstate       <= s_ra0;
               n.address    <= addr_row;
               n.act_row    <= addr_row;
               n.bank       <= addr_bank;
            end if;

         when others =>
            nstate <= s_init_nop;
      end case;
   end process;
   
   --- The clock driven logic
   process (clock_100, n)
   begin
      if clock_100'event and clock_100 = '1' then
        if rst='1' then
          rstate <= (others => '0');
          r.address <= (others => '0');
          r.bank <= (others => '0');
          r.init_counter <= "100000000000000";
          -- synopsys translate_off
          r.init_counter <= "000000100000000";
          -- synopsys translate_on
          r.rf_counter <= 0;
          r.rf_pending <= '0';
          r.rd_pending <= '0';
          r.wr_pending <= '0';
          r.act_row <= (others => '0');
          r.data_out_low <= (others => '0');
          r.data_out_valid <= '0';
          r.dq_masks <= "11";
          r.tristate<='1';
          r.tag_in <= (others =>'0');
          r.tag_out <= (others =>'0');
        else
         r <= n;
         rstate <= nstate;
         --rdata_write <= ndata_write;
         end if;
      end if;
   end process;

  dram_dq_dly <= transport dram_dq after 1.9 ns;

--   process (clock_100_delayed_3ns, dram_dq_dly)
--   begin
--     if clock_100_delayed_3ns'event and clock_100_delayed_3ns = '1' then
--         captured <= dram_dq_dly;
--     end if;
--   end process;

   process (clock_100)
   begin
      if falling_edge(clock_100) then
         captured <= dram_dq_dly;
      end if;
   end process;

end rtl;
