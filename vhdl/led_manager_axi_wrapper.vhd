--
-- Copyright © 2017 LAAS/CNRS
-- Author: Clément Foucher
--
-- Distributed under the GNU GPL v2. For full terms see the file LICENSE.txt.
--
--
-- This file is part of Led Display Manager (LDM)
--
-- LDM is free hardware: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, version 2 of the License.
--
-- LDM is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with LDM. If not, see <http://www.gnu.org/licenses/>.
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library led_manager_lib;
use led_manager_lib.led_manager_package.all;


entity led_manager_axi_wrapper is
  generic (C_S_AXI_DATA_WIDTH : integer := 32;
           C_S_AXI_ADDR_WIDTH : integer := 16
          );
  port (-- AXI signals
        S_AXI_ACLK    : in std_logic;
        S_AXI_ARESETN : in std_logic;
        S_AXI_AWADDR  : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_AWPROT  : in std_logic_vector(2 downto 0);
        S_AXI_AWVALID : in std_logic;
        S_AXI_AWREADY : out std_logic;
        S_AXI_WDATA   : in std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_WSTRB   : in std_logic_vector((C_S_AXI_DATA_WIDTH/8)-1 downto 0);
        S_AXI_WVALID  : in std_logic;
        S_AXI_WREADY  : out std_logic;
        S_AXI_BRESP   : out std_logic_vector(1 downto 0);
        S_AXI_BVALID  : out std_logic;
        S_AXI_BREADY  : in std_logic;
        S_AXI_ARADDR  : in std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
        S_AXI_ARPROT  : in std_logic_vector(2 downto 0);
        S_AXI_ARVALID : in std_logic;
        S_AXI_ARREADY : out std_logic;
        S_AXI_RDATA   : out std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
        S_AXI_RRESP   : out std_logic_vector(1 downto 0);
        S_AXI_RVALID  : out std_logic;
        S_AXI_RREADY  : in std_logic;
        -- Connection to LED display
        cs   : out std_logic;
        wr   : out std_logic;
        data : out std_logic
       );
end entity;

architecture arch_imp of led_manager_axi_wrapper is

  constant BUS_DATA_WIDTH : integer := C_S_AXI_DATA_WIDTH;

  -- AXI4LITE signals
  signal axi_awaddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
  signal axi_awready : std_logic;
  signal axi_wready  : std_logic;
  signal axi_bresp   : std_logic_vector(1 downto 0);
  signal axi_bvalid  : std_logic;
  signal axi_araddr  : std_logic_vector(C_S_AXI_ADDR_WIDTH-1 downto 0);
  signal axi_arready : std_logic;
  signal axi_rdata   : std_logic_vector(C_S_AXI_DATA_WIDTH-1 downto 0);
  signal axi_rresp   : std_logic_vector(1 downto 0);
  signal axi_rvalid  : std_logic;

  constant ADDR_LSB          : integer := (C_S_AXI_DATA_WIDTH/32)+ 1;
  constant OPT_MEM_ADDR_BITS : integer := 7;

  signal slv_reg_rden : std_logic;
  signal slv_reg_wren : std_logic;
  signal byte_index   : integer;
  signal aw_en        : std_logic;
  signal reg_data_out : std_logic_vector(BUS_DATA_WIDTH-1 downto 0);

  -- General registers
  signal control_reg : std_logic_vector(BUS_DATA_WIDTH-1 downto 0); -- Reg 0 (w)
  signal status_reg  : std_logic_vector(BUS_DATA_WIDTH-1 downto 0); -- Reg 0 (r)
  signal data_reg    : std_logic_vector(BUS_DATA_WIDTH-1 downto 0); -- Reg 1 (w)

begin

  -- I/O Connections assignments
  S_AXI_AWREADY <= axi_awready;
  S_AXI_WREADY  <= axi_wready;
  S_AXI_BRESP   <= axi_bresp;
  S_AXI_BVALID  <= axi_bvalid;
  S_AXI_ARREADY <= axi_arready;
  S_AXI_RDATA   <= axi_rdata;
  S_AXI_RRESP   <= axi_rresp;
  S_AXI_RVALID  <= axi_rvalid;

  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_awready <= '0';
        aw_en <= '1';
      else
        if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
          axi_awready <= '1';
          elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
              aw_en <= '1';
          	axi_awready <= '0';
        else
          axi_awready <= '0';
        end if;
      end if;
    end if;
  end process;

  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_awaddr <= (others => '0');
      else
        if (axi_awready = '0' and S_AXI_AWVALID = '1' and S_AXI_WVALID = '1' and aw_en = '1') then
          axi_awaddr <= S_AXI_AWADDR;
        end if;
      end if;
    end if;
  end process;

  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_wready <= '0';
      else
        if (axi_wready = '0' and S_AXI_WVALID = '1' and S_AXI_AWVALID = '1' and aw_en = '1') then
            axi_wready <= '1';
        else
          axi_wready <= '0';
        end if;
      end if;
    end if;
  end process;

  slv_reg_wren <= axi_wready and S_AXI_WVALID and axi_awready and S_AXI_AWVALID ;

  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_bvalid  <= '0';
        axi_bresp   <= "00";
      else
        if (axi_awready = '1' and S_AXI_AWVALID = '1' and axi_wready = '1' and S_AXI_WVALID = '1' and axi_bvalid = '0'  ) then
          axi_bvalid <= '1';
          axi_bresp  <= "00";
        elsif (S_AXI_BREADY = '1' and axi_bvalid = '1') then
          axi_bvalid <= '0';
        end if;
      end if;
    end if;
  end process;

  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_arready <= '0';
        axi_araddr  <= (others => '1');
      else
        if (axi_arready = '0' and S_AXI_ARVALID = '1') then
          -- indicates that the slave has acceped the valid read address
          axi_arready <= '1';
          -- Read Address latching
          axi_araddr  <= S_AXI_ARADDR;
        else
          axi_arready <= '0';
        end if;
      end if;
    end if;
  end process;

  process (S_AXI_ACLK)
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
        axi_rvalid <= '0';
        axi_rresp  <= "00";
      else
        if (axi_arready = '1' and S_AXI_ARVALID = '1' and axi_rvalid = '0') then
          axi_rvalid <= '1';
          axi_rresp  <= "00";
        elsif (axi_rvalid = '1' and S_AXI_RREADY = '1') then
          axi_rvalid <= '0';
        end if;
      end if;
    end if;
  end process;

  slv_reg_rden <= axi_arready and S_AXI_ARVALID and (not axi_rvalid) ;

  process( S_AXI_ACLK ) is
  begin
    if (rising_edge (S_AXI_ACLK)) then
      if ( S_AXI_ARESETN = '0' ) then
        axi_rdata  <= (others => '0');
      else
        if (slv_reg_rden = '1') then
            axi_rdata <= reg_data_out;
        end if;
      end if;
    end if;
  end process;

  process (S_AXI_ACLK)
  variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
  begin
    if rising_edge(S_AXI_ACLK) then
      if S_AXI_ARESETN = '0' then
          control_reg <= (others => '0');
          data_reg    <= (others => '0');
      else
        loc_addr := axi_awaddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
        -- Only handle pulses on the registers value: no data memory
        control_reg <= (others => '0');
        data_reg    <= (others => '0');
          
        if (slv_reg_wren = '1') then
          case loc_addr is
            when b"00000000" => -- reg 0
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if ( S_AXI_WSTRB(byte_index) = '1' ) then
                  control_reg(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
              end loop;
            when b"00000001" => -- reg 1
              for byte_index in 0 to (C_S_AXI_DATA_WIDTH/8-1) loop
                if ( S_AXI_WSTRB(byte_index) = '1' ) then
                  data_reg(byte_index*8+7 downto byte_index*8) <= S_AXI_WDATA(byte_index*8+7 downto byte_index*8);
                end if;
                data_reg(24) <= '1'; -- This bit is overwritten to indicate the write is valid (in case data is about setting the bit 0 of panel 0 to value 0)
              end loop;
            when others =>
                null;
          end case;
        end if;
      end if;
    end if;
  end process;

  process (axi_araddr, S_AXI_ARESETN, slv_reg_rden, status_reg)
  variable loc_addr :std_logic_vector(OPT_MEM_ADDR_BITS downto 0);
  begin
      loc_addr := axi_araddr(ADDR_LSB + OPT_MEM_ADDR_BITS downto ADDR_LSB);
      case loc_addr is
        when b"00000000" =>
          reg_data_out <= status_reg;
        when others =>
          reg_data_out  <= (others => '0');
      end case;
  end process;

  -- LM instanciation
  lm:led_manager
      Port map(clk    => S_AXI_ACLK,
               resetn => S_AXI_ARESETN,
               -- Connections to display
               CS   => cs,
               WR   => wr,
               data => data,
               -- Registers
               control_reg => control_reg,
               data_reg    => data_reg,
               status_reg  => status_reg);

end architecture;
