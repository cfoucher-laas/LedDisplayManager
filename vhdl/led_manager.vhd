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

library IEEE;

use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

library led_manager_lib;
use led_manager_lib.led_manager_package.all;


entity led_manager is
    Port(clk    : in std_logic;
         resetn : in std_logic;
         -- Connections to display
         CS   : out std_logic;
         WR   : out std_logic;
         data : out std_logic;
         -- Registers
         control_reg : in  std_logic_vector(31 downto 0);
         data_reg    : in  std_logic_vector(31 downto 0);
         status_reg  : out std_logic_vector(31 downto 0)
        );
end entity;



architecture archi of led_manager is

  ---------------------------------------
  -- Terminology used in this component:
  
  -- The DISPLAY is made of 4 PANELS,
  -- A panel contains 64 LEDS grouped by 4 into CELLS.
  -- Each CELL has an independent memory address.
  
  -- On a panel, LEDS are indexed by (x,y), where:
  -- - y is the vertical component,
  -- - x is the horizontal component.
  -- x and y are both 3-bit words.
  
  -- The panel is indexed by a 2-bit word.
  
  -------------
  -- DATA REG:
  
  -- The individual rank of a led on a panel is the 6-bit word "yyyxxx".
  -- The panel is "pp".
  
  -- The absolute index of a LED on the display is pp00yyyxxx, so that
  -- the least significant byte is the rank on a panel, and the upper byte is the panel index.
  
  -- The new state (on/off) of the LED is the bit 16 of the word.
  -- The bit 24 indicates that the writing data reg value is valid.
   
  ----------------
  -- CONTROL REG:
  
  -- Bit 0 => "Refresh": When asserted to 1, display is refreshed,
  -- Bit 1 => "Reinitialize": When asserted to 1, display initialization commands are sent. This DOES NOT clear the display.
  -- Bit 2 => "Clear": When asserted to 1, display is cleared.
  
  
  ---------------
  -- STATUS REG:

  -- Bit 0 => Indicates that the display has correctly been initialized,
  -- Bit 1 => Indicated that the display is ready to accept a command on control reg (note that "reinitialize" can be triggered at any moment).


  ----------------------------------------------------------------------------

  -- Command writter signals
  
  signal write_command, command_written, command_is_config : std_logic;
  
  signal address       : std_logic_vector(6 downto 0);
  signal command       : std_logic_vector(2 downto 0);
  signal value         : std_logic_vector(3 downto 0);
  signal command_value : std_logic_vector(8 downto 0);
  
  -- FSM definition
  
  type state_t is (initial, config1, config2, config3, config4, wait_init_done, idle, refresh_mem, wait_mem_refreshed, select_panel);
  signal state, next_state : state_t;

  -- Memory of LED states
  
  -- Memory representation for easy access
  type   mem_panel_t    is array(0 to 15) of std_logic_vector(3 downto 0); -- Type representing the memory of 1 panel (16 4-bit words)
  type   mem_display_t  is array(0 to 3)  of mem_panel_t; -- Type representing the memory of the whole display
  signal mem_value : mem_display_t; -- The signal holding the representation of the display internal memory
  
  -- (x,y) representation of the LEDs states
  type   mem_value_bit_display_t is array(0 to 3) of std_logic_vector(63 downto 0); -- The state of each LED individually in a panel => range 0 to 63
  signal mem_value_bit : mem_value_bit_display_t; -- The signal holding the state of all LEDs on the display
  
  signal mem_value_index : std_logic_vector(3 downto 0);  -- Makes the link between memory address in a display and mem_value_bit as we use a horizontal indexing where panel use a vertical one for memory areas.  
  
  -- Optimization signals: remember which cells have been modified
  -- since lastest update to avoid refreshing unchanged cells.
  
  type   updated_cells_display_t is array(0 to 3) of std_logic_vector(0 to 15); -- Signal used to remember if a memory reguion have been updated since previous write
  signal updated_cells : updated_cells_display_t;
  constant no_updated_cells : std_logic_vector(0 to 15) := (others => '0');

  -- Signals used to address the internal LED representation and to communicate between processes
  
  signal current_cell  : natural range 0 to 15;
  signal current_panel : natural range 0 to 3;
  
  signal count_cell,  reset_cell  : std_logic;
  signal count_panel, reset_panel : std_logic;
  
  signal panel_updated : std_logic;

  -- Reset management
  
  signal actual_reset : std_logic;
  
  -- Clear management
  
  signal clear_requested : std_logic;
  
  
  -- Name registers individal ranges for accessibility
  
  -- Status reg
  signal initialized : std_logic;
  signal ready       : std_logic;
  
  -- Control reg
  signal cmd_update_panel : std_logic;
  signal cmd_reset        : std_logic;
  signal cmd_clear        : std_logic;
  
  -- Data reg
  signal data_is_valid : std_logic;
  signal selected_led_display   : integer range 0 to 3;
  signal selected_led_position  : integer range 0 to 63;
  signal selected_led_x_rank    : std_logic_vector(2 downto 0);
  signal selected_led_y_rank    : std_logic_vector(2 downto 0);
  signal selected_led_new_state : std_logic;

begin

  -- Status reg:
  -- Bit 0 => indicates if the initialization procedure have been carried out,
  -- Bit 1 => indicates that the component is ready to recieve a command.
  status_reg(31 downto 2) <= (others => '0');
  status_reg(1)           <= ready;
  status_reg(0)           <= initialized;
  
  initialized <= '0' when state = initial        else
                 '0' when state = config1        else
                 '0' when state = config2        else
                 '0' when state = config3        else
                 '0' when state = config4        else
                 '0' when state = wait_init_done else
                 '1';

  -- Data reg is 4*8 bits : [valid][state][panel][position]
  -- Valid => if bit 0 is set to 1, the command is valid, (auto-managed by AXI wrapper, no need to set it to 1 when writing in the register)
  -- State => bit 0 contains new LED state,
  -- Panel => bits 1..0 indicate to which panel this command refers,
  -- Position => value between 0 and 63 = position of the target led on the panel. (Equiv: "2..0" = X; "5..3" = Y) 
  data_is_valid <= data_reg(24);
  
  selected_led_new_state <= data_reg(16);
  selected_led_display   <= to_integer(unsigned(data_reg(9 downto 8)));
  selected_led_position  <= to_integer(unsigned(data_reg(7 downto 0)));
  selected_led_x_rank    <= data_reg(2 downto 0);
  selected_led_y_rank    <= data_reg(5 downto 3);
  
  -- Control reg:
  -- Bit 2 => Clears the display,
  -- Bit 1 => Proceed to the panel initialization (may not reinitialize the display itself),
  -- Bit 0 => Update panel with values that changed since last update.
  cmd_clear        <= control_reg(2);
  cmd_reset        <= control_reg(1);
  cmd_update_panel <= control_reg(0);
  
  -- Merge asynchronous and synchronous resets.
  actual_reset <= resetn and (not cmd_reset);


  process(clk, actual_reset)
  begin
    if actual_reset='0' then
      state <= initial;
    elsif rising_edge(clk) then
      state <= next_state;
    end if;
  end process;

  -- This FSM is in charge of initializing the panel and
  -- writing the LEDs state to the panel.
  process(state, command_written, mem_value, current_cell, cmd_update_panel, current_panel, updated_cells, clear_requested)
  begin
    next_state <= state;
    
    count_cell  <= '0';
    reset_cell  <= '0';
    count_panel <= '0';
    reset_panel <= '0';
    
    write_command     <= '0';
    command_is_config <= '0';

    command_value <= (others => '-');
    command       <= (others => '-');
    value         <= (others => '-');
    address       <= (others => '-');
    
    panel_updated <= '0';
    
    ready <= '0';

    case state is
    
      -- LED panel initialization
      
      when initial =>
        next_state <= config1;
        command_value <= "000000010";
        command <= "100";
        command_is_config <= '1';
        write_command <= '1';
      when config1 =>
        if command_written = '1' then
          next_state <= config2;
          command_value <= "000000110";
          command <= "100";
          command_is_config <= '1';
          write_command <= '1';
        end if;
      when config2 =>
        if command_written = '1' then
          next_state <= config3;
          command_value <= "000110000";
          command <= "100";
          command_is_config <= '1';
          write_command <= '1';
        end if;
      when config3 =>
        if command_written = '1' then
          next_state <= config4;
          command_value <= "001000000";
          command <= "100";
          command_is_config <= '1';
          write_command <= '1';
        end if;
      when config4 =>
        if command_written = '1' then
          next_state <= wait_init_done;
          command_value <= "101011110";
          command <= "100";
          command_is_config <= '1';
          write_command <= '1';
        end if;
      when wait_init_done =>
        if command_written = '1' then
          next_state <= idle;
        end if;
        
      -- Wait for command
      
      when idle =>
        ready <= '1';
        reset_cell <= '1';
        reset_panel <= '1';
        if (cmd_update_panel = '1') or (clear_requested = '1') then
          next_state <= refresh_mem;        
        end if;
        
      -- Refreseh panel
      
      when refresh_mem =>
        address <= std_logic_vector(to_unsigned(current_panel, 3)) & std_logic_vector(to_unsigned(current_cell, 4));
        command <= "101";
        value <= mem_value(current_panel)(current_cell);

        if updated_cells(current_panel)(current_cell) = '1' then -- Only call command if cell have been updated...
          write_command <= '1';
          next_state <= wait_mem_refreshed;
        elsif current_cell < 15 then -- ... else count if panel is not over...
          count_cell <= '1';
        else -- ... else go to next panel.
          next_state <= select_panel;
        end if;
      when wait_mem_refreshed =>
        if command_written = '1' then
          if current_cell < 15 then
            count_cell <= '1';
            next_state <= refresh_mem;
          else
            next_state <= select_panel;
          end if;
        end if;
      when select_panel =>
        reset_cell <= '1';
        if current_panel < 3 then
          count_panel <= '1';
          if updated_cells(current_panel+1) /= no_updated_cells then
            next_state <= refresh_mem;
          end if;
        else
          next_state <= idle;
          panel_updated <= '1';
        end if;
     
    end case;
  end process;

  -- Cell counter
  cnt_cell:process(clk, actual_reset)
  begin

    if actual_reset = '0' then
      current_cell <= 0;
    elsif rising_edge(clk) then
      if count_cell = '1' then
        current_cell <= current_cell + 1;
      elsif reset_cell = '1' then
        current_cell <= 0;
      end if;
    end if;
  end process;
  
  -- Display counter
  cnt_display:process(clk, actual_reset)
  begin
    if actual_reset = '0' then
      current_panel <= 0;
    elsif rising_edge(clk) then
      if count_panel = '1' then
        current_panel <= current_panel + 1;
      elsif reset_panel = '1' then
        current_panel <= 0;
      end if;
    end if;
  end process;
  
  
  -- On a display (mem range from 0 to 15, LED range 0 to 63):
  
  -- LED individual number is X + 8Y
  -- => X is led_position(2 downto 0)
  -- => Y is led_position(5 downto 3)
  
  -- Memory area is:
  -- { 2X   if Y < 4
  -- { 2X+1 if Y >= 4
  mem_value_index(3 downto 1) <= selected_led_x_rank;    -- 2X by shifting left
  mem_value_index(0)          <= selected_led_y_rank(2); -- +1 if Y >= 4
  
  mem_update:process(clk, actual_reset)
  begin
    if actual_reset = '0' then

      for i in 0 to 3 loop
        mem_value_bit(i) <= (others => '0');
        updated_cells(i) <= (others => '1'); -- Make sure all cells are reinitialized on first update  
      end loop;

    elsif rising_edge(clk) then
      clear_requested <= '0';
      
      if cmd_clear = '1' then
        clear_requested <= '1';
        for i in 0 to 3 loop
          mem_value_bit(i) <= (others => '0');
          updated_cells(i) <= (others => '1');
        end loop;
      end if;

      if state = refresh_mem then
        updated_cells(current_panel)(current_cell) <= '0';
      end if;

      if data_is_valid = '1' then
        mem_value_bit(selected_led_display)(selected_led_position) <= selected_led_new_state;
        if (mem_value_bit(selected_led_display)(selected_led_position) /= selected_led_new_state) then
          updated_cells(selected_led_display)(to_integer(unsigned(mem_value_index))) <= '1';
        end if;
      end if;
      
    end if;
  end process;



  -- Make the connection between the individual LED addressing we use for storage
  -- and the cell addressed internal memory of the panel.
  -- Plus we use the panel horizontally, where the internal memory is addressed
  -- assuming the panel is vertical.
  mapping:for i in 0 to 3 generate
    mem_value(i)(0)  <= mem_value_bit(i)(0)  & mem_value_bit(i)(8)  & mem_value_bit(i)(16) & mem_value_bit(i)(24);
    mem_value(i)(1)  <= mem_value_bit(i)(32) & mem_value_bit(i)(40) & mem_value_bit(i)(48) & mem_value_bit(i)(56);

    mem_value(i)(2)  <= mem_value_bit(i)(1)  & mem_value_bit(i)(9)  & mem_value_bit(i)(17) & mem_value_bit(i)(25);
    mem_value(i)(3)  <= mem_value_bit(i)(33) & mem_value_bit(i)(41) & mem_value_bit(i)(49) & mem_value_bit(i)(57);

    mem_value(i)(4)  <= mem_value_bit(i)(2)  & mem_value_bit(i)(10) & mem_value_bit(i)(18) & mem_value_bit(i)(26);
    mem_value(i)(5)  <= mem_value_bit(i)(34) & mem_value_bit(i)(42) & mem_value_bit(i)(50) & mem_value_bit(i)(58);

    mem_value(i)(6)  <= mem_value_bit(i)(3)  & mem_value_bit(i)(11) & mem_value_bit(i)(19) & mem_value_bit(i)(27);
    mem_value(i)(7)  <= mem_value_bit(i)(35) & mem_value_bit(i)(43) & mem_value_bit(i)(51) & mem_value_bit(i)(59);

    mem_value(i)(8)  <= mem_value_bit(i)(4)  & mem_value_bit(i)(12) & mem_value_bit(i)(20) & mem_value_bit(i)(28);
    mem_value(i)(9)  <= mem_value_bit(i)(36) & mem_value_bit(i)(44) & mem_value_bit(i)(52) & mem_value_bit(i)(60);

    mem_value(i)(10) <= mem_value_bit(i)(5)  & mem_value_bit(i)(13) & mem_value_bit(i)(21) & mem_value_bit(i)(29);
    mem_value(i)(11) <= mem_value_bit(i)(37) & mem_value_bit(i)(45) & mem_value_bit(i)(53) & mem_value_bit(i)(61);

    mem_value(i)(12) <= mem_value_bit(i)(6)  & mem_value_bit(i)(14) & mem_value_bit(i)(22) & mem_value_bit(i)(30);
    mem_value(i)(13) <= mem_value_bit(i)(38) & mem_value_bit(i)(46) & mem_value_bit(i)(54) & mem_value_bit(i)(62);

    mem_value(i)(14) <= mem_value_bit(i)(7)  & mem_value_bit(i)(15) & mem_value_bit(i)(23) & mem_value_bit(i)(31);
    mem_value(i)(15) <= mem_value_bit(i)(39) & mem_value_bit(i)(47) & mem_value_bit(i)(55) & mem_value_bit(i)(63);
  end generate;
  
  -- The command writer is in charge of
  -- the panel communication protocol. 
  cw:led_manager_command_writer
  Port map(clk => clk,
           resetn => actual_reset,
           -- Commands
           do_write         => write_command,
           address          => address,
           command          => command,
           value            => value,
           write_is_command => command_is_config,
           command_value    => command_value,
           write_done => command_written,
           -- Output signals
           CS   => CS,
           WR   => WR,
           data => data);

end architecture;
