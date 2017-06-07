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

--
-- This component is able to write data to the display.
-- Data can either be commands (12 bits) or memory write (14 bits).
--
-- Assert within the same cycle all required signals and set the do_write signal to '1' to begin a write.
-- The write_done signal is asserted to '1' when the write is over.
--
-- For a memory write, the address, command and value signals must be asserted.
-- For a command write, the command and command_value signals must be asserted, and the write_is_command signal must be set to '1'.
--


entity led_manager_command_writer is
    Port(clk    : in std_logic;
         resetn : in std_logic;
         -- Connections to display
         CS   : out std_logic;
         WR   : out std_logic;
         data : out std_logic;
         -- Commands
         do_write         : in  std_logic;
         write_is_command : in  std_logic;
         address          : in  std_logic_vector(6 downto 0);
         command          : in  std_logic_vector(2 downto 0);
         value            : in  std_logic_vector(3 downto 0);
         command_value    : in  std_logic_vector(8 downto 0);
         write_done       : out std_logic
        );
end entity;


architecture Behavioral of led_manager_command_writer is

  -- Counter maintains command bits for a while because display is slower than FPGA.
  -- Value 400 is suitable for a 100 MHz design (slows outputs down to 250 kHz)
  constant counter_max_value : natural := 400;

  signal current_pos : natural range 0 to 13; -- 0-2 => command ; 3-9 => address ; 10-13 => value
  signal counter     : natural range 0 to counter_max_value;
  
  signal total_value : std_logic_vector(13 downto 0);
  
  signal CS_i   : std_logic;
  signal WR_i   : std_logic;
  signal Data_i : std_logic;

  signal write_rising_edge : std_logic;
  signal do_write_history  : std_logic;

  signal write_size : natural range 0 to 14;

  type state_t is (idle, prepare, writing, finishing);
  signal state, next_state : state_t;
  
begin

  process(clk, resetn)
  begin
    if resetn = '0' then
      do_write_history <= '0';
      write_rising_edge <= '0';
    elsif rising_edge(clk) then
      write_rising_edge <= '0';
      if do_write = '1' and do_write_history = '0' then
        write_rising_edge <= '1';
        if write_is_command = '1' then
          write_size <= 12;
          total_value <= "00"&command&command_value;
        else
          total_value <= command&address&value;
          write_size <= 14;
        end if;
      end if;
      do_write_history <= do_write;
    end if;
  end process;
  
  
  process(clk, resetn)
  begin
    if resetn = '0' then
      state <= idle;
    elsif rising_edge(clk) then
      state <= next_state;
    end if;
  end process;

  process(state, write_rising_edge, wr_i, current_pos, counter, cs_i, write_size)
  begin
    next_state <= state;
    write_done <= '0';
    
    if state = idle then
      if write_rising_edge = '1' then
        next_state <= prepare;
      end if;
    elsif state = prepare then
      if wr_i = '0' then
        next_state <= writing;
      end if;
    elsif state = writing then
      if current_pos = write_size-1 and counter = counter_max_value-1 then
        next_state <= finishing;
      end if;
    elsif state = finishing then
      if cs_i = '1' and counter = counter_max_value-1 then
        next_state <= idle;
        write_done <= '1';
      end if;
    end if;
  end process;

  process(clk, resetn)
  
  begin
    if resetn = '0' then

      current_pos <= 0;
      counter <= 0;
      
      cs_i   <= '1';
      wr_i   <= '1';
      data_i <= '1';
      
    elsif rising_edge(clk) then   
      if state = prepare then
        if cs_i = '1' then
          -- Prepare CS
          cs_i <= '0';
          counter <= 0;
          current_pos <= 0;
        elsif counter < counter_max_value then
          counter <= counter + 1;
        else
          -- Here we really begin
          wr_i <= '0';
          counter <= 0;
        end if;
      elsif state = writing then
        data_i <= total_value(write_size-1-current_pos);
        
        if counter < counter_max_value then
          counter <= counter + 1;
        else
          counter <= 0;
          if wr_i = '0' then
            wr_i <= '1';
          else
            wr_i <= '0';
            counter <= 0;
            current_pos <= current_pos + 1;
          end if;
        end if;
      elsif state = finishing then
        if counter < counter_max_value then
          counter <= counter + 1;
        else
          counter <= 0;
          if wr_i = '0' then
            wr_i <= '1';
          else
            cs_i <= '1';
          end if;
        end if;
      end if;
    end if;
  end process;

  cs   <= 'Z' when cs_i   = '1' else '0';
  wr   <= 'Z' when wr_i   = '1' else '0';
  data <= 'Z' when data_i = '1' else '0';

end Behavioral;
