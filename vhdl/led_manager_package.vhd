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


package led_manager_package is

  component led_manager_command_writer is
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
  end component;
  
  component led_manager is
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
  end component;


end package;
