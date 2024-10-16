----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Lamperti / Fiano
-- 
-- Create Date: 09.03.2022 14:54:17
-- Design Name: 
-- Module Name: project_reti_logiche - Behavioral
-- Project Name: 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
      Port (
      i_clk: in std_logic;
      i_rst: in std_logic;
      i_start: in std_logic;
      i_data: in std_logic_vector (7 downto 0);
      o_address: out std_logic_vector (15 downto 0);
      o_done: out std_logic;
      o_en: out std_logic;
      o_we: out std_logic;
      o_data: out std_logic_vector (7 downto 0)  
       );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
type Stato is (idle, richiesta_mem, read_first, read_mem, wait_mem, wait_mem1, serializzatore, convolutore, parallelizzatore, richiesta_scrittura_mem1, richiesta_scrittura_mem2, write_mem1, write_mem2, valuto, done);
signal CURRENT_STATO: Stato;

signal byte_in: std_logic_vector (7 downto 0) := "00000000";
signal doppio_byte_out: std_logic_vector (15 downto 0) := "0000000000000000";

signal t: integer := 7;
signal i: integer := 15;

type Stato_Convolutore is (s0, s1, s2, s3);
signal CURRENT_S: Stato_Convolutore;

begin
process (i_clk, i_rst)
        variable num_cicli, x: integer := 0;
        --variable t: integer := 7;
        variable next_read: std_logic_vector ( 15 downto 0 ) := "0000000000000001";
        variable next_write: std_logic_vector ( 15 downto 0 ) := "0000001111101000";  --1000
     --   variable i: integer := 15; 
      --  variable byte_in: std_logic_vector (7 downto 0) := "00000000";  
        variable bit_in: std_logic;  
        variable out_1, out_2: std_logic;   
begin 
    if (i_rst = '1') then
        CURRENT_STATO <= idle;
        CURRENT_S <= s0;
        o_en <= '0';
        o_we <= '0';
        o_address <= "0000000000000000";
        o_done <= '0';
        num_cicli := 0;
        x := 0;
        t <= 7;
        i <= 15;
        next_read := "0000000000000001";
        next_write := "0000001111101000";
    elsif (rising_edge (i_clk)) then              
        case CURRENT_STATO is    
            when idle =>
                if (i_start = '1') then
                    o_address <= "0000000000000000";
                    x := 0;
                    t <= 7;
                    CURRENT_STATO <= richiesta_mem;
                end if;
         
            when richiesta_mem =>
                o_en <= '1';
                if (x = 0) then
                    o_address <= "0000000000000000";
                    CURRENT_STATO <= wait_mem1;
                else 
                    o_address <= next_read;
                    CURRENT_STATO <= wait_mem;
                end if;
                
            when wait_mem1 =>
                CURRENT_STATO <= read_first;
                
            when wait_mem =>
                CURRENT_STATO <= read_mem;
             
            when read_first =>
                num_cicli := conv_integer (i_data);
                x := x + 1;
                CURRENT_STATO <= richiesta_mem;
                            
            when read_mem =>
                byte_in <= i_data;
                next_read := next_read + 1;
                CURRENT_STATO <= serializzatore;             
                 
            when serializzatore =>
                o_en <= '0';
                bit_in := byte_in (t);
                CURRENT_STATO <= convolutore;
                                  
            when convolutore => 
                case CURRENT_S is
                    when s0 => 
                        if bit_in = '0' then
                            out_1 := '0';
                            out_2 := '0';
                            CURRENT_S <= s0;
                        else 
                            out_1 := '1';
                            out_2 := '1'; 
                            CURRENT_S <= s2;
                        end if;
                    when s1 => 
                        if bit_in = '0' then
                            out_1 := '1';
                            out_2 := '1';
                            CURRENT_S <= s0;
                        else 
                            out_1 := '0';
                            out_2 := '0'; 
                            CURRENT_S <= s2;
                        end if;  
                    when s2 =>
                        if bit_in = '0' then
                            out_1 := '0';
                            out_2 := '1';
                            CURRENT_S <= s1;
                        else 
                            out_1 := '1';
                            out_2 := '0'; 
                            CURRENT_S <= s3;
                        end if;
                    when s3 => 
                        if bit_in = '0' then
                            out_1 := '1';
                            out_2 := '0';
                            CURRENT_S <= s1;         
                        else 
                            out_1 := '0';
                            out_2 := '1';
                            CURRENT_S <= s3; 
                        end if;
                    end case;
                CURRENT_STATO <= parallelizzatore;
                                
            when parallelizzatore =>
                if ( i = 15 or i = 13 or i = 11 or i = 9 or i = 7 or i = 5 or i = 3 or i = 1 ) then
                    doppio_byte_out (i) <= out_1;
                    CURRENT_STATO <= parallelizzatore;
                    i <= i - 1;
                elsif ( i = 14 or i = 12 or i = 10 or i = 8 or i = 6 or i = 4 or i = 2 or i = 0 ) then 
                    doppio_byte_out (i) <= out_2;
                    if ( i = 0 ) then
                       CURRENT_STATO <= richiesta_scrittura_mem1;
                    else
                        i <= i - 1;
                        
                        CURRENT_STATO <= serializzatore;
                    end if;
                        if ( t = 0 ) then
                            t <= 7;
                        else 
                            t <= t - 1;
                        end if;
                end if;                 
                     
            when richiesta_scrittura_mem1 =>
                i <= 15;
                o_en <= '1';
                o_we <= '1';
                o_address <= next_write;
                CURRENT_STATO <= write_mem1;
                
            when write_mem1 =>
                o_data <= doppio_byte_out (15 downto 8);
                next_write := next_write + 1;
                CURRENT_STATO <= richiesta_scrittura_mem2;
                
            when richiesta_scrittura_mem2 =>
                o_address <= next_write;
                CURRENT_STATO <= write_mem2;
                
            when write_mem2 =>
                o_data <= doppio_byte_out (7 downto 0);
                next_write := next_write + 1;
                CURRENT_STATO <= valuto;
                
            when valuto =>
                o_en <= '0';
                o_we <= '0';
                x := x + 1;
                if ( num_cicli < x ) then
                    o_done <= '1';
                    CURRENT_STATO <= done;
                else
                    CURRENT_STATO <= richiesta_mem;
                end if;
                          
            when done =>
                if  ( i_start = '0') then
                    o_done <= '0';
                    CURRENT_STATO <= idle;
                elsif ( i_start = '1' ) then
                    CURRENT_STATO <= done;
                end if;
                
        end case;
    end if;          
end process;
end Behavioral;
